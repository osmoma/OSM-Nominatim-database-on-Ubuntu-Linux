#!/bin/bash
MY_PATH=$(dirname $(realpath $0))

# Include variables
source "$MY_PATH/00-nominatim-vars.sh"

# Include utility functions
source "$MY_PATH/00-utility.sh"

# Check if root or sudo user
check_if_root_super;

# Restrict access to localhost and local intranet only (this was my best try!)
ACCESS_LOCAL_ONLY="
<Directory \"$PROJECT_WEBSITE\">
 Options FollowSymLinks MultiViews
 AddType application/json .php
 DirectoryIndex search.html search.php

 Require local
 #Require ip 192.168.1.0/24
 Require ip 192.168
 Require ip 10
</Directory>
"

# Allow global access
ACCESS_ALL="
<Directory \"$PROJECT_WEBSITE\">
 Options FollowSymLinks MultiViews
 AddType application/json .php
 DirectoryIndex search.html search.php
 Require all granted
</Directory>
"

function install_apache() {
  mkdir $PROJECT_DIR 2>/dev/null

  apt-get install -y -q apache2 
  a2enmod proxy_http

  echo
  do_peep 3 
  echo_step "Now defining \"/etc/apache2/conf-available/nominatim.conf\" file." 
  echo 
  echo_step "Do you want restrict access to your Nominatim/Postgres database for localhost and local net only?"
  echo_step "If you restrict, then only localhost (127.0.0.1) and your local intranet (198.168.X.X) can access the data."
  echo "  You could then only do requests like:"
  echo "  http://localhost/search.html?city=porto&country=portugal"
  echo "  http://127.0.0.1/search.html?q=lisbon"
  echo "  or by using wget, curl:"
  echo "  curl http://$HOSTNAME/nominatim/search?country=portugal" 
  echo 

  ask_yes_no "Restrict access? Give access to localhost and local intranet only. Block outsiders? Yes/No?" "true"
  # Notice: ask_yes_no returns value in $FN_RETURN_VAL variable!
  # Test $FN_RETURN_VAL.

  ACCESS_TXT=""
  if [ "$FN_RETURN_VAL" == "Y" ]; then 
    ACCESS_TXT=$ACCESS_LOCAL_ONLY
  else
    ACCESS_TXT=$ACCESS_ALL
  fi
        
 cat >/etc/apache2/conf-available/nominatim.conf <<CMD_EOF
<VirtualHost *:80>
 ProxyPass /nominatim "unix:/run/nominatim.sock|http://localhost/"

 # You may change these values.
 # Add server alias "nominatim.com"
 ServerAdmin "admin@$HOSTNAME.com"
 ServerName "$HOSTNAME.com"
 ServerAlias "www.$HOSTNAME.com"
 
 # Eg. /var/www/nominatim
 DocumentRoot $PROJECT_WEBSITE

 #<Directory "$PROJECT_WEBSITE">
 # Options FollowSymLinks MultiViews
 # # ??
 # AddType text/html .php
 #  
 # AddType application/json   .php
 # DirectoryIndex search.html search.php
 # Require all granted
 #</Directory>
        
 $ACCESS_TXT

 alias /nominatim $PROJECT_WEBSITE
 alias /.well-known /var/www/html/.well-known

 ErrorLog ${APACHE_LOG_DIR}/nominatim_error.log
 LogLevel warn
 CustomLog ${APACHE_LOG_DIR}/nominatim_access.log combined
</VirtualHost>
CMD_EOF

  #setfacl -R -m u:www-data:rx $USERHOME
  chown $USERNAME:www-data $PROJECT_WEBSITE -R

  # Disable/enable configuration file
  a2disconf nominatim
  a2enconf nominatim

  # Restart apache2 and Postgres
  systemctl restart apache2
  systemctl restart postgresql
  
  echo "Done."
}

install_apache;

do_peep 4
echo
echo 
echo "Notice."
echo "I had to rename the default Apache2 \"index.html\" to something else.. "
echo "so I can access nominatim page from my intranet (from tablets and phones via intranet 192.168.xx.xx address)."
echo "I did:"
echo "mv /var/www/html/index.html /var/www/html/index.old"
echo "After that my IP 192.168.xx.xx shows the nominatim page and map."
echo "There must be a better solution...my understanding of Apache2 config was not good enough."
echo 


