#!/bin/bash
MY_PATH=$(dirname $(realpath $0))

# Include variables
source "$MY_PATH/00-nominatim-vars.sh"

# Include utility functions
source "$MY_PATH/00-utility.sh"

# Check if root or sudo user
check_if_root_super;

function final_settings() {
  # Firewall settings  
  apt-get -q -y install ufw
  ufw enable

  # Allow Postgres port
  psql -U postgres -c 'SELECT version();' | grep PostgreSQL

  PORT=$(psql -U nominatim -t -c "SELECT setting FROM pg_settings WHERE name='port';" | xargs)
  echo_step "Port for database 'nominatim' on PostgresSQL is $PORT."
  
  if [ -z "$PORT" ]; then
     # Default
     PORT=5432
  fi
  
  ufw allow ${PORT}/tcp

  ufw allow http
  ufw allow https
  ufw allow "Apache Full"
  #ufw allow proto tcp from any to any port 80,443

  # Other usefull are:
  # sudo ufw allow 8080/tcp
  #
  # Microsoft VS Code uses often port 5500 (you can access it from localhost or via intranet 192.168.x.x)
  # sudo ufw allow 5500/tcp       
}

final_settings;

