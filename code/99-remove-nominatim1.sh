#!/bin/bash
MY_PATH=$(dirname $(realpath $0))

# Include variables
source "$MY_PATH/00-nominatim-vars.sh"

# Include utility functions
source "$MY_PATH/00-utility.sh"

echo "*************************************"
echo "Remove OSM NOMINATIM installation."
echo "Running ${0##*/}" 
echo "cwd: $(pwd)"
echo "*************************************"

echo "Remove OSM NOMINATIM installation?  (BE CAREFUL!, TEM CUIDADO!)"
echo "Deleting Postgres databases (all of them!)"
echo "This will DROP ALL DATABASES AND THE POSTGRES ITSELF."
echo "Deleting Apache2 and its settings."
echo "Deleting Nominatim user interface (website)."
echo "Deleting Nominatim user and project folder."
echo

# Continue Yes/No? 
ask_yes_no "Continue Yes/No?";

# Are you sure? 
ask_yes_no "Are you sure? Reply Y/N:";

# Drop nominatim db.
# DROP SCHEMA db CASCADE; 
# (psql -l lists all databases)
echo "Dropping Nominatim database. (need password for nominatim user)"
dropdb --host=localhost --username=nominatim --password --force nominatim

echo
echo "Deleting packages and directories. (need password for root or sudo)"
sudo apt-get remove --purge -y  postgresql-* postgresql-client-* postgresql-contrib-* \
        postgresql-server-dev-* postgresql-postgis* postgis postgis-doc

sudo rm -frd /usr/lib/postgresql
sudo rm -frd /var/lib/postgresql
sudo rm -fr /usr/sbin/psql
sudo rm /etc/systemd/system/nominatim*
#sudo rm -fr /etc/postgresql

if [ ! -z "$PROJECT_WEBSITE" -a ${#PROJECT_WEBSITE} -gt 4 ]; then
  sudo rm -fr "$PROJECT_WEBSITE"
fi

if [ ! -z "$PROJECT_DIR" -a ${#PROJECT_DIR} -gt 4 ]; then
  sudo rm -fr "$PROJECT_DIR"
fi

if [ ! -z "$USERNAME" ]; then  
  sudo userdel -rf "$USERNAME"
fi

if [ ! -z "$USERHOME" -a ${#USERHOME} -gt 4 ]; then
  sudo rm -fr "$USERHOME"
fi

sudo apt-get remove -y --purge apache2* apache2-data* libapache2-mod-wsgi-py3
sudo apt-get -y autoremove
echo 

echo "DONE!"
echo_error "NOMINATIM and OSM, all data and PostgreSQL database(s) removed."


