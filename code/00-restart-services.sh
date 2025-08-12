#!/bin/bash
MY_PATH=$(dirname $(realpath $0))

# Include variables
source "$MY_PATH/00-nominatim-vars.sh"

# Include utility functions
source "$MY_PATH/00-utility.sh"

# Check if root or sudo user
check_if_root_super;

systemctl disable --now nominatim.socket 
systemctl disable --now nominatim.service nominatim.socket 

systemctl daemon-reload
systemctl restart nominatim.socket
systemctl enable nominatim.socket
systemctl restart nominatim.service
systemctl enable nominatim.service

systemctl restart postgresql

a2disconf nominatim; a2enconf nominatim
systemctl restart apache2

echo "Done."


