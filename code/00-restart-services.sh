#!/bin/bash
MY_PATH=$(dirname $(realpath $0))

# Include variables
source "$MY_PATH/00-nominatim-vars.sh"

# Include utility functions
source "$MY_PATH/00-utility.sh"

# Check if root or sudo user
check_if_root_super;

systemctl daemon-reload
systemctl enable nominatim.socket
systemctl start nominatim.socket
systemctl enable nominatim.service

systemctl restart postgresql
a2disconf nominatim; a2enconf nominatim
systemctl restart apache2

echo "Done."


