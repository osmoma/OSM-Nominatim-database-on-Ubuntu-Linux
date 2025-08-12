#!/bin/bash
MY_PATH=$(dirname $(realpath $0))

# Include variables
source "$MY_PATH/00-nominatim-vars.sh"

# Include utility functions
source "$MY_PATH/00-utility.sh"

# Check if root or sudo user
check_if_root_super;

echo_step "****************************************************" >&1
echo_step "Check Apache2 config." >&1
echo_step "****************************************************" >&1

# sudo apachectl -t
apachectl configtest

echo_step "****************************************************" >&1
echo_step "Check nominatim database." >&1
echo_step "****************************************************" >&1

su - nominatim<<END_CMD
  # Check nominatim database 
  nominatim admin --check-database
  nominatim status 
END_CMD

echo_step "****************************************************" >&1
echo_step "You may check the .log files in ${APACHE_LOG_DIR}." >&1
echo_step "****************************************************" >&1
echo "Nominatim log: ${APACHE_LOG_DIR}/nominatim_error.log"
echo "and"
echo "Apache2 log: /var/log/apache2/error.log"
echo 
echo "ls -l ${APACHE_LOG_DIR}" 
ls -l "${APACHE_LOG_DIR}"

echo
echo_step "****************************************************" >&1
echo_step "Start a small, local web server (normally on http://127.0.0.1:8088)" >&1
echo "su - nominatim<<END_CMD"
echo "  nominatim serve"
echo "END_CMD"
echo_step "****************************************************" >&1

# Kill existing server (the port is normally 8088)
# sudo lsof -t -i tcp:8088 | xargs kill -9 2>&1 1>/dev/null
for PID in $(sudo lsof -t -i tcp:8088); do
  echo "Kill nominatim serve, PID:$PID"
  kill -9 "$PID" 1>&2 2>/dev/null
done

# Start a new one
(su - nominatim<<END_CMD
  echo "Test the Nominatim search mechanism:"
  echo "Trying to start a small test-server (see: nominatim serve --help)."
  echo "Open the URL in your browser (normally  http://127.0.0.1:8088)."
  echo 
  echo "Do some tests similar to these:"
  echo "http://127.0.0.1:8088/status"
  echo "http://127.0.0.1:8088/search?city=Lisbon"
  echo "http://127.0.0.1:8088/search?country=finland&city=helsinki"
  echo "http://127.0.0.1:8088/search?q=lisbon"
  echo 
  echo "See: https://nominatim.org/release-docs/latest/api/Search/"

  # nominatim serve --server 127.0.0.1:1337
  nominatim serve
END_CMD
)&

echo 
echo_step "Check web access. Expecting status 'OK'">&1
echo_step "Open the following link in your browser;" >&1
echo "http://localhost/nominatim/status"
echo_step "or use curl, wget..." <&1
echo "curl http://localhost/nominatim/status"
echo "curl http://localhost/nominatim/status returns:  $(curl -sS http://localhost/nominatim/status)"
echo 
echo_step 'The reply/status should be "OK"  - !!!!' >&1

echo 
echo 
echo_step "You may also try some queries:"
echo "http://localhost/nominatim/search?q=monaco"
echo "http://localhost/nominatim/search?country=monaco&city=Monaco-Ville"
echo
echo "Ref: https://nominatim.openstreetmap.org/ui/search.html"
echo 
echo_step "http://localhost/nominatim/search?country=monaco&city=Monaco-Ville&polygon_geojson=1&format=geojson"

# Ref: https://nominatim.openstreetmap.org/ui/search.html

