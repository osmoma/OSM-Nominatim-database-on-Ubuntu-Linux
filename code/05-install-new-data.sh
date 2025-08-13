#!/bin/bash
MY_PATH=$(dirname $(realpath $0))

# Include variables
source "$MY_PATH/00-nominatim-vars.sh"

# Include utility functions
source "$MY_PATH/00-utility.sh"

# Prepare Nominatim $PROJECT_DIR/.env
source "$MY_PATH/00-prep-nominatim-env.sh"

# Check if root or sudo user
check_if_root_super;

function download_from_mirror() {
  # $1: Output directory/ or output directory/filename  (assuming the directory exists).
  # $2: Download URL
  # Example call:
  # download_from_mirror "/srv/nominatim/work/europe/monaco" "https://download.geofabrik.de/europe/monaco/monaco-latest.osm.pbf"  
  # download_from_mirror "/srv/nominatim/work/europe/monaco/test.pbf" "https://download.geofabrik.de/europe/monaco/monaco-latest.osm.pbf"

  LOCAL_PATH="$1"
  REMOTE_PATH="$2"

  # Is a directory? (must exist)
  if test -d "$LOCAL_PATH"; then 
    DL_OPTION="--directory-prefix"
  else 
    # Assume $LOCAL_PATH is a file
    DL_OPTION="--output-document"
  fi

  wget --waitretry=4 -t 2 "$DL_OPTION" "$LOCAL_PATH" "$REMOTE_PATH" 
  RESULT="$?"

  echo "$RESULT"
}

function nominatim_import_new_data() {
   # Ref: https://nominatim.org/release-docs/latest/admin/Advanced-Installations/
   # Import new data to the db.
   # $1 = List of regions/countries separated by space.
   # $2 = Preferred OSM download site/mirror (use global default if empty).
   # Sample calls:
   # nominatim_add_or_update_data "europe/andorra europe/monaco africa"
   # nominatim_add_or_update_data "europe/andorra europe/monaco africa" "https://download.openstreetmap.fr/extracts"
   #
   # The directory structure will be:
   #
   # tree -f
   #$PROJECT_DIR/
   # ├── planet/
   #       │     └── sequence.state       <-- for planet-latest.osm.pbf
   # ├── europe/
   #       │     └── sequence.state       <-- for europe-latest.osm.pbf
   # │     ├── andorra/    
   # │     │     └── sequence.state <-- for andorra-latest.osm.pbf
   # │     └── monaco/     
   # │     │     └── sequence.state <-- for monaco-latest.osm.pbf
   # │     └── finland/     
   # │           └── sequence.state <-- for finland-latest.osm.pbf
   # └── tmp/
   #       ├── planet-latest.osm.pbf  <-- You can delete *.osm.pbf files after successful import (save space)
   #       ├── europe-latest.osm.pbf
   #       └── europe/
   #             ├── andorra-latest.osm.pbf
   #             └── monaco-latest.osm.pbf
   #             └── finland-latest.osm.pbf

   # Make sure the $USERHOME/.env is ok
   nominatim_prepare_env;

   mkdir -p $PROJECT_DIR 2>/dev/null

   PROJECT_DIR_TMP="${PROJECT_DIR}/tmp"
   mkdir -p $PROJECT_DIR_TMP 2>/dev/null

   # Wikipedia/wikimedia data (improves search results). 
   # See "00-nominatim-vars.sh"
   WIKIPEDIA_DIR="${PROJECT_DIR}/wikipedia"
   mkdir -p $WIKIPEDIA_DIR 2>/dev/null

   chown -R ${USERNAME}:www-data ${PROJECT_DIR}
   chmod -R g+rwx "$PROJECT_DIR"

   cd ${PROJECT_DIR}

   # $1, region/country list given?        
   if test -z "$1"; then 
     echo_error "Region/country list (in parameter \$1) is not set."
     echo_error "Call this function with region/country list (in\$1) and download URL (in\$2)."
     exit 1
   fi              
 
   COUNTRIES="$1"

   # $2, download URL given?
   DL_SITE="$2"
   if test -z "$2"; then
     # Default DOWNLOAD_SITE is set in "00-nominatim-vars.sh"
     DL_SITE="$DOWNLOAD_SITE"
   fi
        
   DL_SITE=$(trim_str "$DL_SITE")

   # DL_SITE is set?       
   if test -z "$DL_SITE"; then 
     echo_error "Call this function with region/country list (in\$1) and download URL (in\$2)."
     echo_error "Or set DOWNLOAD_SITE in 00-nominatim-vars.sh."
     exit 1
   fi              

   # ---------------------------------------------------------

   LATEST_NAME="-latest.osm.pbf"

   # Number of threads (ca. ~CPUs) 
   NUM_THREADs=$(calculate_threads)

   # Take 85% of available memory (in bytes)
   MEM_AVAIL=$(calculate_memory 85%)
   # To MB
   MEM_AVAIL=$(( MEM_AVAIL/1000 ))
   # ------------------------------------
   
   unset NOMINATIM_DB_EXIST
   NOMINATIM_DB_EXIST=$(psql --dbname=nominatim -U postgres -XtA -c "SELECT 1 FROM place LIMIT 1;" 2>/dev/null)
   
   if [ ! -z "$NOMINATIM_DB_EXIST" ]; then
     echo 
     echo_step "Postgres database NOMINATIM already exist." 
  
     # List of already imported region/countries
     DB_HAS_COUNTRIES=$(psql --dbname=nominatim -U postgres -c "SELECT DISTINCT A.country_code as Country_code, B.name -> 'name' as Name FROM location_area_country as A, country_name as B WHERE A.country_code=B.country_code order by A.country_code;")

     if [ ! -z "$DB_HAS_COUNTRIES" ]; then
       echo "Database has these regions/countries:"
       echo "$DB_HAS_COUNTRIES"
     fi
    
     echo_step "Adding new region/countries to the database (nominatim add-data...)."
     ask_yes_no "Is this OK? Reply Yes/No:"
    
     # Will execute nominatim add-data for each file...
     IMPORT_CMD="nominatim add-data -j ${NUM_THREADs} --osm2pgsql-cache ${MEM_AVAIL} --project-dir ${PROJECT_DIR}"
     IMPORT_PARM="--file"
   else
     echo 
     echo_step "Postgres database NOMINATIM DOES NOT exist." 
     echo_step "Creating a new database, importing new data (nominatim import...)."
     ask_yes_no "Is this OK? Reply Yes/No:"
    
     # Will execute nominatim import for each file...
     IMPORT_CMD="nominatim import -j ${NUM_THREADs} --osm2pgsql-cache ${MEM_AVAIL} --project-dir ${PROJECT_DIR}"
     IMPORT_PARM="--osm-file"
   fi

   # Count imported files
   IMPORT_COUNT=0

   # If need to re-index database after OSM-data and wikidata imports? (0=false, 1=true)
   DO_REINDEX_DB=0
   
   # --------------------------LOOP START --------------------------------
   # Loop through region/country list. Items are separated by spaces (or ,)
   IFS=$' ,'
   for COUNTRY in $COUNTRIES; do
     COUNTRY=$(trim_str "$COUNTRY")

     # $COUNTRY
     # Eg. "europe/andorra", or "africa", "europe", "planet", etc.
     echo 
     echo_step "Processing region/country: $COUNTRY." >&1

     # Eg. "planet", "europe", "asia" or ""
     PART_1=$(dirname "$COUNTRY")
     if test "$PART_1" == "."; then
       PART_1=""
     fi              

     # Eg. "monaco", "andorra", "finland", ...
     PART_2=$(basename "$COUNTRY")

     SEQUENCE_FILE="${PROJECT_DIR}/${COUNTRY}/sequence.state"
     
     # -----------------------------------------
     # IMPORT NEW COUNTRY/REGION                             
     # -----------------------------------------

     # Eg. "/srv/nominatim/data/tmp/europe/"   (for eg. "europe/andorra", "europe/norway", ...)
     # or "/srv/nominatim/data/tmp/"  (for eg. "europe", "africa", "planet", ...)
     LOCAL_DIR="$PROJECT_DIR_TMP/$PART_1"

     # Eg. "andorra-latest.osm.pbf"
     # or "europe-latest.osm.pbf"
     #    "planet-latest.osm.pbf"
     LOCAL_FILE="${PART_2}${LATEST_NAME}"

     # Eg.
     # "https://download.geofabrik.de/europe/andorra-latest.osm.pbf"
     # "https://download.geofabrik.de/europe-latest.osm.pbf"
     DL_URL="$DL_SITE/${PART_1}/${LOCAL_FILE}"
    
     # Download OSM pbf file
     mkdir -p "$LOCAL_DIR"
                 
     #TESTING BEG. 
     #USE EXISTING .PBF FILES (avoid download, save time during testing)?                    
     #if ! test -f "${LOCAL_DIR}/${LOCAL_FILE}"; then
      echo
      echo_step "Now downloading $DL_URL --> ${LOCAL_DIR}/${LOCAL_FILE}"
      
      # Remove existing file
      rm "${LOCAL_DIR}/${LOCAL_FILE}" 2>/dev/null

      RES=$(download_from_mirror "$LOCAL_DIR" "$DL_URL")   

       # if test "$RES" != "0"; then  (this OK, but testing -f ...)
       if ! test -f "${LOCAL_DIR}/${LOCAL_FILE}"; then                                                                         
         echo_error "-----------------------------------------" >&2
         echo_error "Cannot download OSM PBF for country $COUNTRY." >&2 
         echo_error "Download of ${DL_URL} failed." >&2
         echo_error "Local directory is ${LOCAL_DIR}." >&2
         echo_error "Tried these OSM sites: $DL_SITE" >&2
         echo_error "-----------------------------------------" >&2
         continue;
      fi
     ##fi #TESTING END

     # Create or clean the directory 
     mkdir -p ${PROJECT_DIR}/${COUNTRY} 2>/dev/null
     rm -fr ${PROJECT_DIR}/${COUNTRY}/* 2>/dev/null

     # Create an empty sequence.state file (used by later updates)
     touch "${SEQUENCE_FILE}" 

     # Get changes
     pyosmium-get-changes -O "${LOCAL_DIR}/${LOCAL_FILE}" -f "${PROJECT_DIR}/${COUNTRY}/sequence.state" --size 500 -vvv

     # Add either --osm-file xxx.pbf or --file xxx.pbf  
     IMPORT_CMD="${IMPORT_CMD} ${IMPORT_PARM} ${LOCAL_DIR}/${LOCAL_FILE} " 
                    
     # Write the URL ($DL_SITE) to "url.txt" so updates can use it later 
     echo "$DL_SITE" > "${PROJECT_DIR}/${COUNTRY}/url.txt"
     # -----------------------------------------------------

     # Count number of new imports
     IMPORT_COUNT=$((IMPORT_COUNT + 1))
     
  done  # for COUNTRY in $COUNTRIES...
  # --------------------------LOOP END --------------------------------     

  # Files are owned by nominatim:www-data
  chown -R ${USERNAME}:www-data ${PROJECT_DIR}

  # ----------------------------------------------------------------------------  
  # Import new data.
  # If this is first import then create Nominatim database & tables.
  # ----------------------------------------------------------------------------  
  if [ "$IMPORT_COUNT" -gt 0 ]; then
    echo
    echo_step "Importing new data:" >&1
    echo_step "$IMPORT_CMD" >&1
    echo
    echo_step "This may take some time. Be patient, let it run..."
    echo 

    # Import/add-data                 
    su - ${USERNAME} <<CMD_EOF
     $IMPORT_CMD
CMD_EOF

    # Must re-index database (below)
    DO_REINDEX_DB=1
  fi

  echo_step "*********************************************" >&1
  echo_step "Add wikimedia/wikidata to the database? This data improves quality of search and results." >&1
  echo_step "*********************************************" >&1           
  # Ref: https://nominatim.org/release-docs/latest/admin/Import/
  #      https://nominatim.org/release-docs/latest/customize/Settings/#nominatim_wikipedia_data_path

  # Import only once. Check if "wikimedia-importance.csv.gz" exists.
  if ! test -f "${WIKIPEDIA_DIR}/wikimedia-importance.csv.gz"; then
        
    # IMPORT_WIKIPEDIA_RANKINGS == Yes/No?  
    IMPORT_WIKIPEDIA_RANKINGS=$(echo "$IMPORT_WIKIPEDIA_RANKINGS" | xargs)  # Remove spaces
    if [[ "$IMPORT_WIKIPEDIA_RANKINGS" =~ ^[yY] ]]; then 
      cd $WIKIPEDIA_DIR
                           
      wget https://nominatim.org/data/wikimedia-importance.csv.gz
      wget -O secondary_importance.sql.gz https://nominatim.org/data/wikimedia-secondary-importance.sql.gz
      chown ${USERNAME}:www-data ${WIKIPEDIA_DIR}/* 
                           
      WIKIPEDIA_CMD="nominatim refresh --wiki-data --secondary-importance --importance"
      
      echo_step "$WIKIPEDIA_CMD" >&1  
      
      su - ${USERNAME} << CMD_EOF
        # nominatim refresh --wiki-data --secondary-importance --importance
        cd "$WIKIPEDIA_DIR"
        $WIKIPEDIA_CMD 
CMD_EOF

    # Must re-index database (below)
    DO_REINDEX_DB=1

    fi
  fi

  # ----------------------------------------------------
  # Re-index Nominatim database?
  if [ "$DO_REINDEX_DB" -gt 0 ]; then
    INDEX_CMD="nominatim index -j ${NUM_THREADs}"

    echo 
    echo_step "Reindexing database... stay tuned!"
    
    su - ${USERNAME} <<CMD_EOF
      ${INDEX_CMD}
CMD_EOF

  fi
  # ----------------------------------------------------

  cd ${PROJECT_DIR}

  chown -R ${USERNAME}:www-data ${PROJECT_DIR}
  chmod -R g+rwx "$PROJECT_DIR"
      
  echo 
  # Inform about the flatnode file
  if [ -f "$NOMINATIM_FLATNODE_FILE" -a ${#NOMINATIM_FLATNODE_FILE} -gt 0 ]; then  
    echo "Important notice."
    echo "NOMINATIM_FLATNODE_FILE has been set and GPS co-ordinates and polygons are stored in this file."
    echo "Do not alter or remove that file during normal operation."
    echo 
    FSIZE=$(stat -c "%s" "$NOMINATIM_FLATNODE_FILE")
    echo "The file is \"$NOMINATIM_FLATNODE_FILE\" and its size is $FSIZE bytes after data import." 
  fi

  # -----------------------------------------------
  # Show the data as tree listing
  # -----------------------------------------------
  echo_step "****************************************************" >&1
  echo_step "Open Street Map/Nominatim data in $PROJECT_DIR is:" >&1
  echo_step "****************************************************" >&1

  #tree -f
  tree

  echo_step "****************************************************" >&1
  echo_step "You can delete all files in $PROJECT_DIR_TMP directory to free some disk space." 
  echo_step "****************************************************" >&1
}

function print_info() {
  echo
  echo_step "${RED_TEXT}Important, importante:"
  echo "------------------------------------------------------------"
  echo "Now, become user \"nominatim\", and run:"
  echo "sudo -i -u nominatim"
  echo "or:"
  echo "su nominatim      # password is in /root/auth.txt"
  echo "cd \$HOME"
  echo 
  echo "Check the Nominatim/Postgres database, run:"
  echo "nominatim admin --check-database"
  echo 
  #echo "Run 'nominatim serve' to start a small local webserver. (as nominatim user, passwords are in /root/auth.txt)."
  #echo "Paste the URL in your browser."
  echo "Check state of the database. (as nominatim user). It should reply \"OK\". Run:"
  echo "nominatim status"
  echo 
  echo "Test and search (depending on data you imported):"
  echo "nominatim search --query Lisbon"
  echo "nominatim search --query monte"
  echo "nominatim reverse --lat 51 --lon 45"
}

# --------------------------------------------------
# Notice:
# Ask if user has updated COUNTRY_LIST and DOWNLOAD_SITE variables in "00-nominatim-vars.sh"
echo 
echo "----------------------------------------------"
echo "You should modify COUNTRY_LIST and DOWNLOAD_SITE variables in the \"00-nominatim-vars.sh\" file."
echo "You may also set the variables here by editing this script."
echo 
echo "Current values are:"
echo "COUNTRY_LIST=$COUNTRY_LIST"
echo "DOWNLOAD_SITE=$DOWNLOAD_SITE"

do_peep 3 
ask_yes_no "Are these values OK? Reply Yes/No (Y/N):"

# Choose a download site that also has daily/weekly diffs (frequent updates, check the site for this!).
# ...and for example https://download.openstreetmap.fr/extracts does not contain europe/andorra data (ATM).
#
# The https://download.geofabrik.de (in Germany) seems to be a good one.
#
# Samples:
#nominatim_import_new_data "europe/monaco" "https://download.openstreetmap.fr/extracts";
#nominatim_import_new_data "europe/monaco europe/andorra europe/portugal" "https://download.geofabrik.de"

#COUNTRY_LIST="europe/portugal europe/monaco"
#DOWNLOAD_SITE="https://download.geofabrik.de"

# Let us go:
# Import new data. Create Postgres database for Nominatim OSM data.
nominatim_import_new_data "$COUNTRY_LIST" "$DOWNLOAD_SITE"

# Print some info
print_info


