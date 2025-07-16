#!/bin/bash
MY_PATH=$(dirname $(realpath $0))

# Include variables
source "$MY_PATH/00-nominatim-vars.sh"

# Include utility functions
source "$MY_PATH/00-utility.sh"

# Check if root or sudo user
check_if_root_super;

function install_nominatim_web_web_ui() {
	# Ref: https://nominatim.org/release-docs/latest/admin/Setup-Nominatim-UI/
	#      https://github.com/osm-search/nominatim-ui/blob/master/README.md
	#
	# Stable release
	# https://github.com/osm-search/nominatim-ui/releases

	# Has user and $HOME
	if [ -z "$USERNAME" -o -z "$USERHOME" ]; then
		echo_error "USERNAME or USERHOME variable is not set. Cannot continue." >&2
		exit 1
	fi

	cd "$USERHOME"

	rm -fr "$USERHOME/tmp"; mkdir "$USERHOME/tmp"; 
	cd "$USERHOME/tmp"
	
	TAR_BALL="nominatim-ui-${PROJECT_WEB_UI_VER}.tar.gz"
	wget https://github.com/osm-search/nominatim-ui/releases/download/v${PROJECT_WEB_UI_VER}/${TAR_BALL}
	tar -zxvf $TAR_BALL
	
	# Remove tar ball
	#rm $TAR_BALL

	UI_DIR=${TAR_BALL%*.tar.gz}
	cd $UI_DIR
	
		# Use the example theme.js
	mv dist/theme/config.theme.js.example dist/theme/config.theme.js

	if [ -z "$HOSTNAME" ]; then 
		HOSTNAME=$(hostname -f)
	fi

	# Replace title. Notice: the line must end at ","
	sed -i.save "s|Page_Title.*|Page_Title:'Nominatim on $HOSTNAME.',|" dist/config.defaults.js 

	# Replace the sample URL in dist/theme/config.theme.js  
	# Nominatim_Config.Nominatim_API_Endpoint = 'http://myserver.example.com:1234/nominatim/';
	# Notice: The line must end at ";"
	sed -i.save "s|Nominatim_Config.Nominatim_API_Endpoint.*|Nominatim_Config.Nominatim_API_Endpoint = 'http://${HOSTNAME}/nominatim/';|" \
					 dist/theme/config.theme.js

	#Replace the sample title 
	#Nominatim_Config.Page_Title = 'My Server demo';
	#Notice: The line must end at ";"
	sed -i.save "s|Nominatim_Config.Page_Title.*|Nominatim_Config.Page_Title = 'Nominatim-ui on ${HOSTNAME}.';|" \
					 dist/theme/config.theme.js

	# Do a test:
	# Start web-server from ./dist and paste the URL in your browser. 
	#  python3 -m http.server 8765 
	#  http://localhost:8765

	# Deploy the UI web site (so apache2 can serve it)
	mkdir "$PROJECT_WEBSITE" 2>/dev/null
	
	cp -fr dist/*  "$PROJECT_WEBSITE"
	chown -R www-data:www-data "$PROJECT_WEBSITE"

	# Remove tmp directory
	rm -fr "$USERHOME/tmp"

	# a2enmod rewrite
	systemctl reload apache2

	cd $USERHOME

	# echo $(hostname -f) 
	# xdg-open http://${HOSTNAME}/search.html
	# xdg-open http://localhost/search.html
	# Test in browser http://ubuntu2504/search.html
	#                 http://localhost/search.html


	echo "Done."
}

install_nominatim_web_web_ui;


echo 
echo_step "Now, test Nominatim web-interface in your browser:"
echo "http://127.0.0.1"
echo "http://localhost"
echo "http://localhost:80"
echo "http://$HOSTNAME"
echo 
echo_step "And search for a country or city that you imported to the database."
echo_step "I had imported europe/monaco and europe/andorra so I do..."
echo "http://$HOSTNAME/search?q=monaco"
echo "http://localhost/search?q=Monte"
echo 
echo "See: https://nominatim.org/release-docs/latest/api/Search/" 

