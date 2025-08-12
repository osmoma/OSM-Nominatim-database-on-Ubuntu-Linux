#!/bin/bash
MY_PATH=$(dirname $(realpath $0))

# Include variables
source "$MY_PATH/00-nominatim-vars.sh"

# Include utility functions
source "$MY_PATH/00-utility.sh"

# Check if root or sudo user
check_if_root_super;

cd ${PROJECT_DIR}

echo
echo_step "*********************************************" >&1
echo_step "Re-indexing the database." >&1
echo_step "*********************************************" >&1           

# Number of threads (ca. ~CPUs) 
NUM_THREADs=$(calculate_threads)

INDEX_CMD="nominatim index -j ${NUM_THREADs}"
echo_step ${INDEX_CMD} >&1

su - ${USERNAME} <<CMD_EOF
 ${INDEX_CMD}    
CMD_EOF

echo
echo_step "*********************************************" >&1
echo_step "Checking the Nominatim database." >&1
echo_step "*********************************************" >&1           

CHECK_DB_CMD="nominatim admin --check-database"
echo_step ${CHECK_DB_CMD} >&1

su - ${USERNAME} <<CMD_EOF
 ${CHECK_DB_CMD}
CMD_EOF

echo_step "Done."
echo

