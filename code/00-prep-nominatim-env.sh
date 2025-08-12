#!/bin/bash
MY_PATH=$(dirname $(realpath $0))

# Include variables
source "$MY_PATH/00-nominatim-vars.sh"

# Include utility functions
source "$MY_PATH/00-utility.sh"

# Check if root or sudo user
check_if_root_super;

function nominatim_prepare_env() {
 # Update $PROJECT_DIR/.env file. 

 mkdir "${PROJECT_DIR}" 2>/dev/null

 # Get saved user password
 USER_PASSWD=$(get_saved_passwd "$USERNAME password")

 # The ".env" file must be in the $PROJECT_DIR.
 #See: https://nominatim.org/release-docs/latest/customize/Settings/
 cat >${PROJECT_DIR}/.env <<CMD_EOF
  # Base URL of the replication service
  # Edit: We will use diffs for each country, not fixed country URL
  # Edit: NOMINATIM_REPLICATION_URL="???"

  # How often upstream publishes diffs (in seconds)
  # 1 week = 604800 seconds
  NOMINATIM_REPLICATION_UPDATE_INTERVAL=604800   

  # How long to sleep if no update found yet (in seconds)
  NOMINATIM_REPLICATION_RECHECK_INTERVAL=604800 

  # Save co-ordinates/polygons in a flatnode file (instead of database).
  # Faster lookup.
  NOMINATIM_FLATNODE_FILE=$NOMINATIM_FLATNODE_FILE

  NOMINATIM_DATABASE_DSN="pgsql:dbname=nominatim;user=${USERNAME};password=${USER_PASSWD}"

  #www-data is default
  #NOMINATIM_DATABASE_WEBUSER=www-data

  # Active logging?
  #NOMINATIM_LOG_DB=true
  NOMINATIM_LOG_FILE=$USERHOME/nominatim-data.log
CMD_EOF

 chown $USERNAME:$USERNAME ${PROJECT_DIR}/.env
 chmod 775 ${PROJECT_DIR}/.env

 # Add "$USERHOME/nominatim-venv/bin" to nominatim user's $PATH (in .bashrc file).
 # Notice: $HOME/.bashrc is executed when nominatim user does a normal shell login (and $HOME/.profile is NOT run in this case)
 # Eg.
 # sudo -u nominatim bash 
  
 if ! grep -q "$USERHOME/nominatim-venv/bin" $USERHOME/.bashrc 2>/dev/null; then 
   echo "export PATH=$PATH:$USERHOME/nominatim-venv/bin" >> $USERHOME/.bashrc
 fi 
  
 # Add "$USERHOME/nominatim-venv/bin" to nominatim user's $PATH (in .profile file).
 # Notice: $HOME/.profile is executed when nominatim user activates an interactive shell and becomes nominatim user.
 #         (and $HOME/.bashrc is NOT run in this case)
 # Eg.
 # su - nominatim<<END
 #  ...
 #END
  
 if ! grep -q "$USERHOME/nominatim-venv/bin" $USERHOME/.profile 2>/dev/null; then 
   echo "export PATH=$PATH:$USERHOME/nominatim-venv/bin" >> $USERHOME/.profile  
 fi 

 echo
 echo_step "PATH $USERHOME/nominatim-venv/bin was added to $USERHOME/.profile file." 
 echo_step "PATH $USERHOME/nominatim-venv/bin was added to $USERHOME/.bashrc file."      

 echo
 echo_step "${PROJECT_DIR}/.env file has been updated." 
}

nominatim_prepare_env;

