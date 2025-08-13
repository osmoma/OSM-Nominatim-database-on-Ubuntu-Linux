#!/bin/bash
MY_PATH=$(dirname $(realpath $0))

# Include variables
source "$MY_PATH/00-nominatim-vars.sh"

# Include utility functions
source "$MY_PATH/00-utility.sh"

function install_nominatim_user() {
  # Check if root or sudo user
  check_if_root_super;

  echo_step "****************************************************" >&1
  echo_step "Creating user \"$USERNAME\" with home directory \"$USERHOME\""
  echo_step "****************************************************" >&1
  # Ref: https://nominatim.org/release-docs/latest/admin/Install-on-Ubuntu-24/

  # Password was set? or create a new one
  if [ -z "$USERNAME" -o -z "$USERHOME" ]; then
    echo_error "USERNAME or USERHOME variable is not set. Cannot continue." >&2
    exit 1
  fi

  # Create user nominatim
  useradd -c "OpenStreetMap Nominatim" -m -d "${USERHOME}" -s /bin/bash "${USERNAME}" 2>/dev/null

  # Password was set by the user? 
  if [ -z "$USER_PASSWD" ]; then
     # No. Get old password from /root/auth.txt
     USER_PASSWD=$(get_saved_passwd "$USERNAME password")
  fi

  # Password was set? or create a new one
  if [ -z "$USER_PASSWD" ]; then
     USER_PASSWD=$(pwgen -A -N 1)
  fi

  # Write passwd to /root/auth.txt
  ret=$(get_saved_passwd "$USERNAME password")
  if [ -z "$ret" ]; then 
     NOW=$(date '+%B %d, %Y at %H:%M:%S')
     echo "${USERNAME} password: ${USER_PASSWD}      (created:${NOW})" >> /root/auth.txt
  fi

  # Change the passwd
  echo "${USERNAME}:${USER_PASSWD}" | chpasswd

  chmod a+x "$USERHOME"
  usermod -a -G sudo "${USERNAME}" # Is this necessary? 

  groupadd "www-data" 2>/dev/null 
  usermod -a -G "www-data" $USERNAME
  # --------------------------------------

  # Add $USERHOME/work  (maybe used by nominatim.socket)
  mkdir "$USERHOME/work"
  chown "$USERNAME":"www-data" "$USERHOME/work" 
  chmod 775 "$USERHOME/work"

  # Python3 venv
  rm -fr $USERHOME/nominatim-venv 2>/dev/null
  rm -fr $USERHOME/Nominatim 2>/dev/null

  # Run as nominatim user
  su - ${USERNAME} <<CMD_EOF
   cd "$USERHOME"
   git clone https://github.com/osm-search/Nominatim.git

   mkdir -p Nominatim/data 2>/dev/null
   wget -O Nominatim/data/country_osm_grid.sql.gz https://nominatim.org/data/country_grid.sql.gz

   virtualenv $USERHOME/nominatim-venv

   $USERHOME/nominatim-venv/bin/pip install psycopg[binary]

   cd $USERHOME/Nominatim
   $USERHOME/nominatim-venv/bin/pip install packaging/nominatim-db

   # -------------------------------
   # Setting up the Python frontend (local web access)
   $USERHOME/nominatim-venv/bin/pip install falcon uvicorn gunicorn
         
   $USERHOME/nominatim-venv/bin/pip install packaging/nominatim-api
   
   # Install osmium for import and updates
   # ##$USERHOME/nominatim-venv/bin/pip install osmium     
CMD_EOF

 # Add $USERHOME/nominatim-venv/bin/ to PATH, activate the virtual environment
 # Ref: https://nominatim.org/release-docs/latest/admin/Install-on-Ubuntu-24/
 su - $USERNAME <<CMD_EOF
  . $USERHOME/nominatim-venv/bin/activate
CMD_EOF

 # Check the PATH in $USERHOME/.bashrc
 if ! grep -q "$USERHOME/nominatim-venv/bin" $USERHOME/.bashrc 2>/dev/null; then 
   echo "export PATH=$PATH:$USERHOME/nominatim-venv/bin" >> $USERHOME/.bashrc  
 fi 

 # Check the PATH in $USERHOME/.profile
 if ! grep -q "$USERHOME/nominatim-venv/bin" $USERHOME/.profile 2>/dev/null; then 
   echo "export PATH=$PATH:$USERHOME/nominatim-venv/bin" >> $USERHOME/.profile  
 fi 

tee /etc/systemd/system/nominatim.socket <<SOCKET_SYSTEMD_EOF
[Unit]
Description=Gunicorn socket for Nominatim

[Socket]
ListenStream=/run/nominatim.sock
SocketUser=$USERNAME
#SocketMode=777

[Install]
WantedBy=multi-user.target
SOCKET_SYSTEMD_EOF

tee /etc/systemd/system/nominatim.service <<NOMINATIM_SYSTEMD_EOF
[Unit]
Description=Nominatim running as a gunicorn application
After=network.target
Requires=nominatim.socket

[Service]
Type=simple
User=www-data
Group=www-data

WorkingDirectory=${USERHOME}/work

#Evt. directory for nominatim.socket (below /run/)
#RuntimeDirectory=nominatim
#RuntimeDirectoryMode=666

ExecStart=$USERHOME/nominatim-venv/bin/gunicorn -b unix:/run/nominatim.sock -w 4 -k uvicorn.workers.UvicornWorker "nominatim_api.server.falcon.server:run_wsgi()"
#ExecReload=/bin/kill -s HUP \$MAINPID
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s TERM $MAINPID

PrivateTmp=true
TimeoutStopSec=5
KillMode=mixed

[Install]
WantedBy=multi-user.target
NOMINATIM_SYSTEMD_EOF

  # Creating postgres accounts for the user
  su - postgres << CMD_EOF
   createuser -sdRe $USERNAME   
   createuser -SDRe www-data
   psql -c "ALTER USER ${USERNAME} WITH PASSWORD '${USER_PASSWD}'"
CMD_EOF
         
 # Disable old one (if config was changed)
 sudo systemctl disable --now nominatim.socket 
 sudo systemctl disable --now nominatim.service nominatim.socket 

 # Start new one
 sudo systemctl daemon-reload
 sudo systemctl start nominatim.service nominatim.socket
 sudo systemctl enable nominatim.service
 sudo systemctl enable nominatim.socket
 
 echo
 echo
 echo_step "${RED_TEXT}Please notice!"
 echo "Created user:$USERNAME"
 echo "User password: $USER_PASSWD"
 echo "User home:$USERHOME"      
 echo "This directory will contain downloaded data (to be processed) and update info." 
 echo_step "Passwords have been written to /root/auth.txt file. Ok?  (check that file)"
}

install_nominatim_user;

# Update $USERHOME/.bashrc and $USERHOME/.profile files. 
# Update $PROJECT_DIR/.env file.
source "$MY_PATH/00-prep-nominatim-env.sh"

