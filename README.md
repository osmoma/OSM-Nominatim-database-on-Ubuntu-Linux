# OSM Nominatim database on Ubuntu Linux 25.04.
Small bash-scripts that install Nominatim database and user interface for OSM, Open Street Map (data) - on Ubuntu Linux.  
These scripts do not install "map tiles" themselves. Tiles are a dfferent matter.
The tile layers (in the Nominatim web-interface) come from https://tile.openstreetmap.org/{z}/{x}/{y}.png.

**The bash-scripts are:**    
00-nominatim-vars.sh  
00-prep-nominatim-env.sh  
00-reindex-nominatim-db.sh  
00-restart-services.sh  
00-utility.sh  

01-prepare-system.sh  
02-install-postgres.sh  
03-tune-postgres.sh  
04-install-nominatim-user.sh  
05-install-new-data.sh  
06-install-apache.sh  
07-install-nominatim-web-ui.sh  
08-final-settings.sh  
09-check-installation.sh  
10-update-data.sh

99-remove-nominatim.sh   

Notice.  
This is my first attempt at installing OSM data and Nominatim.
I have done this work on Ubuntu Linux 25.04.
I hope you'll get some inspiration from my effort.

Download the bash scripts and make them executable.  
$ chmod +x *.sh

Check the variables in "00-nominatim-vars.sh" and run the scripts sequentially from 01 to 10.  
$ ./01-prepare-system.sh  
...  

The "99-remove-nominatim.sh" script will delete/wipe out Postgres and its databases + Nominatim!
