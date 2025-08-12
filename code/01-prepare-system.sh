#!/bin/bash
MY_PATH=$(dirname $(realpath $0))

# Include variables
source "$MY_PATH/00-nominatim-vars.sh"

# Include utility functions
source "$MY_PATH/00-utility.sh"

# Check if root or sudo user
check_if_root_super;

function prepare_system() {
  echo_step "Your system is $(lsb_release -a)."

  # Update system
  echo "Updating system."         

  apt-get -q -y update; apt-get -q -y upgrade; apt-get -q -y autoremove

  # Install some necessities
  apt-get install -q -y osm2pgsql pkg-config libicu-dev virtualenv pyosmium 
  apt-get install -q -y wget aria2 unzip pwgen gawk git tree curl 

  echo 
  echo_step "System update done."
}

prepare_system;
