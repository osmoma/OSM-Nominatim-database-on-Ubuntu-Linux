#!/bin/bash
SELF_PATH=$(dirname $(realpath $0))

# Include variables
source "$SELF_PATH/00-nominatim-vars.sh"

# Include utility functions
source "$SELF_PATH/00-utility.sh"

# Prepare Nominatim $PROJECT_DIR/.env
source "$SELF_PATH/00-prep-nominatim-env.sh"

# Check if root or sudo user
check_if_root_super;

# Make sure the $PROJECT_DIR/.env is set
nominatim_prepare_env;

function nominatim_update_data() {
	# 	https://nominatim.org/release-docs/latest/admin/Update/#setting-up-the-update-process

	# Update Nominatim database.
	# Find all "sequence.state" files and update database for the actual region/country.
	#
	# $1 = Use this download/mirror site (if this is empty, then get site from "url.txt")
	#      "05-install-new-data.sh" saved download/mirror site in url.txt file.
	#
	# Sample calls:
	# nominatim_update_data; 
	# nominatim_update_data "https://download.openstreetmap.fr/extracts" 
	#
	# Expecting this directory structure:
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
	#       ├── planet-latest.osm.pbf     <-- Not needed after initial import (you may delete these to save space)
	#       ├── europe-latest.osm.pbf     <-- -//-
	#       └── europe/
	#             ├── andorra-latest.osm.pbf  <-- -//-
	#             └── monaco-latest.osm.pbf   ...
	#             └── finland-latest.osm.pbf

	# $PROJECT_DIR is set?
	if [ ! -d "$PROJECT_DIR" ]; then 
		echo_error "\$PROJECT_DIR is not set. Define PROJECT_DIR in \"00-nominatim-vars.sh\" and try again."
		echo_error "Also, you should import (new/initial) data with \"xx-import-new-data.sh\" before updating."
		echo_error "Cannot continue."
		exit 1			
	fi
	
	cd ${PROJECT_DIR}

	# Delete all (old) diff/update files 
	# Commented out: find ${PROJECT_DIR} -name "*.osc.gz" -type f -delete

	# Optional download/update site
	GIVEN_UPDATE_URL="$1"
	GIVEN_UPDATE_URL=$(trim_str "$GIVEN_UPDATE_URL")
	# ---------------------------------------------------------
	
	# Number of threads (ca. ~CPUs)	
	NUM_THREADs=$(calculate_threads)

	# Take 80% of available memory (in bytes)
	MEM_AVAIL=$(calculate_memory 80%)
	# To MB
	MEM_AVAIL=$(( MEM_AVAIL/1000 ))
	# ------------------------------------
	
	# Update command
	# nominatim add-data ...
	# (assuming that "nominatim" program is in the $PATH of nominatim user)
	UPDATE_CMD="nominatim add-data -j ${NUM_THREADs} --osm2pgsql-cache ${MEM_AVAIL} --project-dir ${PROJECT_DIR}"
	
	# Count number of updates
	UPDATE_COUNT=0

	# Get list of all sequence.state files in $PROJECT_DIR and its sub directories 
	SEQUENCE_FILES=$(find "$PROJECT_DIR" -type f -name "sequence.state") 

	# Loop through region/country list. Items are separated by spaces (or ,)
	for SEQUENCE_FILE in $SEQUENCE_FILES; do
		#Eg. SEQUENCE_FILE=/srv/nominatim/data/europe/monaco/sequence.state
		#    SEQUENCE_FILE=/srv/nominatim/data/europe/sequence.state

		echo 
		echo_step "Reading ${SEQUENCE_FILE}."

		#Eg. F1=europe/monaco/sequence.state
		#    F1=europe/sequence.state	
		F1=${SEQUENCE_FILE##${PROJECT_DIR}/}

		#Eg. COUNTRY=europe/monaco
		#    COUNTRY=europe
		COUNTRY=${F1%%sequence.state}
		# Remove "/" at front and rear
		COUNTRY=$(echo "$COUNTRY" | sed -e 's|^/||' -e 's|/$||')

		# Eg. PART1=europe
		#     PART_1=""
		PART_1=$(dirname "$COUNTRY")
		if test "$PART_1" == "."; then
			PART_1=""
		fi		

		# Eg. PART_2=monaco
		#     PART_2=europe
		PART_2=$(basename "$COUNTRY")

		echo_step "The region/country is \"$COUNTRY\"."
		echo "PART_1=$PART_1"
		echo "PART_2=$PART_2"

		# --------------------------------------
		# Update url was given in $1?
		unset UPDATE_URL
		if [ -z "$1" ]; then
			# Use the saved URL.
			# New-import saved $UPDATE_URL location in "url.txt" file. Read it.
			UPDATE_URL=$(cat "${PROJECT_DIR}/${COUNTRY}/url.txt" 2>/dev/null)
			UPDATE_URL=$(echo $UPDATE_URL | xargs)
			
			echo_step "Reading update URL from \"${PROJECT_DIR}/${COUNTRY}/url.txt\""
			echo_step "The URL is \"$UPDATE_URL\"."
			
		else
			echo_step "Using the given update URL \"$1\" (in parameter \$1)"
		fi 	

		if [ -z "$UPDATE_URL" ]; then
			UPDATE_URL=$1
		fi
		
		# $UPDATE_URL is now set?
		if [ -z "$UPDATE_URL" ]; then
			echo_error "Update URL is not given or set for \"$COUNTRY\"." 
			echo_error "There is no \"${PROJECT_DIR}/${COUNTRY}/url.txt\" file or it is empty."
			echo_error "You may give an alternative update URL as \$1 parameter when calling this function."
			echo_error "The URL/site must have a diffs-file for the region/country."
			echo
			echo
			# Skip to next
			continue
		fi

		# Make a complete URL
		# Eg. https://download.geofabrik.de/europe-updates
		#     https://download.geofabrik.de/europe/andorra-updates
		#     https://download.geofabrik.de/europe/monaco-updates 
		UPDATE_URL="${UPDATE_URL}/${COUNTRY}-updates"

		# Diffs file
		# Eg. /srv/nominatim/data/europe/europe.osc.gz
		#     /srv/nominatim/data/europe/andorra/andorra.osc.gz
		#     /srv/nominatim/data/europe/spain/spain.osc.gz
		OSC_GZ_FILE="${PROJECT_DIR}/${COUNTRY}/${PART_2}.osc.gz"

		echo_step "Downloading changes/updates for $COUNTRY --> $OSC_GZ_FILE (server $UPDATE_URL)." >&1

		rm -f ${OSC_GZ_FILE} 2>/dev/null
		pyosmium-get-changes -o ${OSC_GZ_FILE} -f ${SEQUENCE_FILE} --server $UPDATE_URL --size 500 -vvv

		# Add to UPDATE_CMD
		UPDATE_CMD="${UPDATE_CMD} --diff ${OSC_GZ_FILE} "
		
		# Count number of updates
		UPDATE_COUNT=$((UPDATE_COUNT + 1))
	done # for ...

	# Files should be owned by $USERNAME:www-data (nominatim:www-data)
	chown -R ${USERNAME}:www-data ${PROJECT_DIR}

	# --------------------------------------------
	# Run updates
	# --------------------------------------------	
	if [ "$UPDATE_COUNT" -gt 0 ]; then
		#LOG_FILE="update-data-$(date +"%F").log"

		echo_step "*********************************************" >&1
		echo_step "Updating existing data:" >&1
		echo_step "$UPDATE_CMD" >&1
		echo_step "*********************************************" >&1

		su - ${USERNAME} << CMD_EOF
			# Perform updates, log to LOG_FILE
			$UPDATE_CMD
CMD_EOF
	fi

	# Reindex 
	echo "REALP="
	realpath "$0"
	
	source "$SELF_PATH/xx-reindex-nominatim-db.sh"
}

nominatim_update_data | tee log1.txt	;

