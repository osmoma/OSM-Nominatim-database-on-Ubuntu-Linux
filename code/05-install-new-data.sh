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
	# Import new data to the db or update db if country/region has sequence.state file.
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
	#	│     └── sequence.state       <-- for planet-latest.osm.pbf
	# ├── europe/
	#	│     └── sequence.state       <-- for europe-latest.osm.pbf
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

	# Take 80% of available memory (in bytes)
	MEM_AVAIL=$(calculate_memory 80%)
	# To MB
	MEM_AVAIL=$(( MEM_AVAIL/1000 ))
	# ------------------------------------
	
	# Import and update commands
	# nominatim import ...
	# (assuming that "nominatim" program is in $PATH of nominatim user)
	IMPORT_CMD="nominatim import -j ${NUM_THREADs} --osm2pgsql-cache ${MEM_AVAIL} --project-dir ${PROJECT_DIR}"
	
	# Count number of new imports
	IMPORT_COUNT=0

	# Loop through region/country list. Items are separated by spaces (or ,)
	IFS=$' ,'
	for COUNTRY in $COUNTRIES; do
		COUNTRY=$(trim_str "$COUNTRY")

		# $COUNTRY
		# Eg. "europe/andorra", or "africa", "europe", "planet", etc.
		echo 
		echo_step "Processing region/country $COUNTRY." >&1

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
	
		# Eg. "/srv/nominatim/data/tmp/europe/"   (eg. "europe/andorra", ...)
		# or "/srv/nominatim/data/tmp/"  (eg. "europe", "africa", "planet", ...)
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

		# Add downloaded --osm-file (xxx.pbf) to the IMPORT_CMD 
		IMPORT_CMD="${IMPORT_CMD} --osm-file ${LOCAL_DIR}/${LOCAL_FILE} " 
		
		# Write the URL ($DL_SITE) to "url.txt" so updates can use it later 
		echo "$DL_SITE" > "${PROJECT_DIR}/${COUNTRY}/url.txt"
		# -----------------------------------------------------

		# Count number of new imports
		IMPORT_COUNT=$((IMPORT_COUNT + 1))

	done


	# Files are owned by nominatim:www-data
	chown -R ${USERNAME}:www-data ${PROJECT_DIR}

	# --------------------------------------------	
	# Import new data & create nominatim database?
	# --------------------------------------------	
	if [ "$IMPORT_COUNT" -gt 0 ]; then
		echo
		echo_step "Importing new data:" >&1
		echo_step "$IMPORT_CMD" >&1
		echo
		
		su - ${USERNAME} <<CMD_EOF
			$IMPORT_CMD
CMD_EOF
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
		fi
	fi

	cd ${PROJECT_DIR}

	chown -R ${USERNAME}:www-data ${PROJECT_DIR}
	chmod -R g+rwx "$PROJECT_DIR"

	# Reindex
	source "$MY_PATH/xx-reindex-nominatim-db.sh"
	
	echo 
	# Inform about flatnode file
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

	echo 
	echo "Run 'nominatim serve' to start a small local webserver. (as nominatim user)"
	echo "Run 'nominatim status' to check state of database. (as nominatim user)"
}

# Notice:
# Ask if user has update COUNTRY_LIST and DOWNLOAD_SITE variables in "00-nominatim-vars.sh"
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

# Choose a download site that also has daily/weekly diffs (frequent updates, check the site!).
# ...for example https://download.openstreetmap.fr/extracts does not contain europe/andorra data (ATM) !
#
# Samples:
#nominatim_import_new_data "europe/monaco" "https://download.openstreetmap.fr/extracts";
#nominatim_import_new_data "europe/monaco europe/andorra europe/portugal" "https://download.geofabrik.de"

#COUNTRY_LIST="europe/portugal europe/monaco"
#DOWNLOAD_SITE="https://download.geofabrik.de"

# Import new data. Create Nominatim OSM database.
nominatim_import_new_data "$COUNTRY_LIST" "$DOWNLOAD_SITE"




