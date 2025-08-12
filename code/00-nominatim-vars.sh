#!/bin/bash
MY_PATH=$(dirname $(realpath $0))

# The OSM Nominatim project.
# Installation variables for Nominatim.
# Check and modify these values before running the scripts.

POSTGRE_VER=17
POSTGIS_VER=3

# User name and home
USERNAME=nominatim
USERHOME=/srv/nominatim

# User password. If left empty the password is auto-generated (or read from /root/auth.txt).
# Notice: All passwords are saved in /root/auth.txt file.
USER_PASSWD="nominatim"

# Project directory for region/country data, imports and updates. 
# Flatnode files (polygons) if enabled are also stored here.
PROJECT_DIR=$USERHOME/data

# Nominatim website 
PROJECT_WEBSITE="/var/www/nominatim"

# See: https://github.com/osm-search/nominatim-ui/releases
PROJECT_WEB_UI_VER=3.6.1  

# Error log directory for Apache2, Nominatim.
# See: ls -l /var/log/apache2/nominatim*
APACHE_LOG_DIR="/var/log/apache2"

# Import data to the PostgreSQL database.
# COUNTRY_LIST is a list of region/countries separated by space or ,
# See: https://download.geofabrik.de or 
#      https://download.openstreetmap.fr/extracts/
#
# Find a download site near you: https://wiki.openstreetmap.org/wiki/Planet.osm#Extracts 
#
# Test the installation with small countries like; europe/malta, europe/andorra, europe/monaco, europe/estonia.
# Big/huge imports are: planet, africa, europe, asia, ...
# Big imports need upto 1TB disk space and may take several days to process and import.
# Samples:
# COUNTRY_LIST="planet"
# COUNTRY_LIST="europe"
# COUNTRY_LIST="europe/monaco europe/andorra"
# COUNTRY_LIST="europe/monaco europe/portugal"
COUNTRY_LIST="europe/finland europe/portugal"

# Choose a download/mirror site.  
# See: https://wiki.openstreetmap.org/wiki/Planet.osm#Planet.osm_mirrors
#      https://wiki.openstreetmap.org/wiki/Planet.osm#Extracts 
#
#DOWNLOAD_SITE=https://download.openstreetmap.fr/extracts
DOWNLOAD_SITE="https://download.geofabrik.de"

# Variable NOMINATIM_FLATNODE_FILE.
# If you plan to import a large dataset (e.g. Europe, North America, the entire planet), you should also enable flatnode storage of node locations.
# With this setting, node co-ordinates and polygons are stored in a simple file instead of the Nominatim database.
# See: https://nominatim.org/release-docs/latest/admin/Import/
# Notice:
# This variable/value is copied to "$PROJECT_DIR/.env" file.

NOMINATIM_FLATNODE_FILE="$PROJECT_DIR/flatnode-polygon.data"
# Disable it?
# unset NOMINATIM_FLATNODE_FILE

# Download wikipedia/wikidata rankings? 
# This is additional data to improve search results.
# Ref: https://nominatim.org/release-docs/latest/admin/Import/
# Download is around 400MB that adds 4GB to the Postgres database. 
# Yes/No
IMPORT_WIKIPEDIA_RANKINGS="No"

# Import external postcodes?
# See: https://nominatim.org/release-docs/latest/admin/Import/
# Here are postcodes the USA and GB (Great Britain)
# POSTCODE_FILES="https://nominatim.org/data/gb_postcodes.csv.gz
#                 https://nominatim.org/data/us_postcodes.csv.gz"
POSTCODE_FILES=""

# Default is 80
LOCALHOST_PORT=

HOSTNAME=$(hostname -f)

