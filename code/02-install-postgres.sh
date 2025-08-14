#!/bin/bash
MY_PATH=$(dirname $(realpath $0))

# Include variables
source "$MY_PATH/00-nominatim-vars.sh"

# Include utility functions
source "$MY_PATH/00-utility.sh"

# Check if root or sudo user
check_if_root_super;

function install_postgresql() {

  # Confirm/verify versions of Postgresql, PostGIS
  # Ask user
  ask_about_postgres_version

  apt-get -q -y install postgresql-${POSTGRE_VER} osm2pgsql postgresql-${POSTGRE_VER}-postgis-${POSTGIS_VER} \
               postgresql-${POSTGRE_VER}-postgis-${POSTGIS_VER}-scripts pkg-config libicu-dev virtualenv

  apt-get -q -y install postgresql-client-${POSTGRE_VER} postgresql-contrib-${POSTGRE_VER} \
               postgresql-server-dev-${POSTGRE_VER} 

  if ! test -f /usr/lib/postgresql/${POSTGRE_VER}/bin/psql; then
    echo "Error when installing PostgreSQL. Cannot continue."
    exit 1
  fi

  ln -sf /usr/lib/postgresql/${POSTGRE_VER}/bin/pg_config  /usr/bin
  ln -sf /var/lib/postgresql/${POSTGRE_VER}/main/ /var/lib/postgresql
  ln -sf /var/lib/postgresql/${POSTGRE_VER}/backups /var/lib/postgresql

  systemctl restart postgresql

  # Set postgres password
  # Get old or create new password
  POSTGRE_PASSWD=$(get_saved_passwd "postgres password")
  if [ -z "$POSTGRE_PASSWD" ]; then
    NOW=$(date '+%B %d, %Y at %H:%M:%S')
    POSTGRE_PASSWD=$(pwgen -A -N 1)
    echo "postgres password: ${POSTGRE_PASSWD}      (created:${NOW})" >> /root/auth.txt
  fi
        
  # Add Postgre variables to environment
  ret=$(grep "PGDATA" /etc/environment | grep "=")
  if [ -z "$ret" ]; then 
    echo "export PGDATA=/var/lib/postgresql/${POSTGRE_VER}/main" >> /etc/environment

    #rm -fr /var/lib/pgsql/${POSTGRE_VER}/data/*
    #rm -fr /var/lib/pgsql/${POSTGRE_VER}/data/*
    #echo "export PGDATA=/var/lib/pgsql/${POSTGRE_VER}/data >> /etc/environment
    #/var/lib/pgsql/data
  fi
        
  # Add postgres user to sudo group
  usermod -aG sudo postgres

  # https://www.postgresql.org/docs/current/auth-pg-hba-conf.html
  # Configure ph_hba.conf
  cat > /etc/postgresql/${POSTGRE_VER}/main/pg_hba.conf << CMD_EOF
   #
   # Ref: https://www.postgresql.org/docs/current/auth-pg-hba-conf.html
   #
   # TYPE  DATABASE        USER            ADDRESS                 METHOD
   local   all             all                                     trust

   # The same using local loopback TCP/IP connections.
   host    all             all             127.0.0.1/32            trust

   # The same as the previous line, but using a separate netmask column
   host    all             all             127.0.0.1       255.255.255.255     trust

   # The same over IPv6.
   host    all             all             ::1/128                 trust

   # The same using a host name (would typically cover both IPv4 and IPv6).
   host    all             all             localhost               trust

   host     all             all             0.0.0.0/0               scram-sha-256

   host     all             all             ::1/128                 scram-sha-256

   hostssl all            all             127.0.0.1              255.255.255.255    scram-sha-256

   hostssl all            all             0.0.0.0/0              scram-sha-256

   hostssl all            all             ::1/128                                              scram-sha-256
CMD_EOF

  # Create Symlinks for Backward Compatibility
  # ??
  #mkdir -p /var/lib/pgsql
  #ln -sf /var/lib/postgresql/${PG_VER}/main /var/lib/pgsql
  #ln -sf /var/lib/postgresql/${PG_VER}/backups /var/lib/pgsql

  # Restart postgresql
  systemctl restart postgresql
  
  # Inform user
  echo
  echo_step "${RED_TEXT}-----------"
  echo_step "${RED_TEXT}Notice!"
  echo_step "${RED_TEXT}-----------"  
  echo_step "Password of user ${RED_TEXT}postgres${WHITE_TEXT} has been written to /root/auth.txt file. Ok?  (check that file)"

  echo       
  echo "You can change Postgres password with:"
  echo "sudo -u postgres psql"
  echo "Then in the psql console, change the password and quit:"
  echo "postgres=# \password postgres"
  echo "Enter new password: new-password"
  echo "postgres=# \q"
  echo 
  echo "Or by ALTER USER:"
  echo "ALTER USER postgres PASSWORD 'new-password';"
  echo 
  echo "Or by one liner:"
  echo "sudo -u postgres psql -c \"ALTER USER postgres PASSWORD 'new-password';\""
  echo 
  echo "Check the \"/root/auth.txt\" file."
}

function ask_about_postgres_version() {
  #AVAIL_VERSIONS=$(apt-cache policy postgresql)
  do_peep 3
  echo_step "Please check the latest available versions of Postgresql and PostGIS in your Linux."
  echo "Use commands like:"
  echo "apt-cache search postgresql | grep -E '^postgresql-[0-9]{1,3}(-postgis-[0-9]{1,3})* '"
  echo "apt-cache policy postgresql"
  echo 
  echo_step "Check and modify \"00-nominatim-vars.sh\" file."
  echo_step "Current versions of Postgresql and PostGIS in \"00-nominatim-vars.sh\" are:"
  echo "POSTGRE_VER=$POSTGRE_VER"
  echo "POSTGIS_VER=$POSTGIS_VER"

  ask_yes_no "Do you want to continue? Reply Yes/No:"
}

# Run the functions
bash "$MY_PATH/01-prepare-system.sh"

install_postgresql;


