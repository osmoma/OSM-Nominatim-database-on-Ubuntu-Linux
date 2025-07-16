#!/bin/bash
MY_PATH=$(dirname $(realpath $0))

# Include variables
source "$MY_PATH/00-nominatim-vars.sh"

# Include utility functions
source "$MY_PATH/00-utility.sh"

# Check if root or sudo user
check_if_root_super;

function tune_postgres_database() {
	# Tune PostgreSQL configuration
	# Ref: https://nominatim.org/release-docs/latest/admin/Installation/#tuning-the-postgresql-database

	# Find Postgresql's config file.
	# Normally: /etc/postgresql/17/main/postgresql.conf
	POSTGRE_CONF=$(psql -U postgres -c 'SHOW config_file'  | grep "\.conf")
	POSTGRE_CONF=$(echo $POSTGRE_CONF | xargs)	
	
	CONFIG_VARS="	
		track_activity_query_size = 32768
		maintenance_work_mem = 10GB
		autovacuum_work_mem = 2GB
		work_mem = 2GB
		synchronous_commit = off
		max_wal_size = 1GB
		checkpoint_timeout = 20min
		checkpoint_completion_target = 0.9
		random_page_cost = 1.0
		wal_level = minimal
		max_wal_senders = 0"
		
		# During import/update, set:
		#shared_buffers = 8GB  # normally 128MB
		#fsync = off
		#full_page_writes = off
		#
		#And this??
		#max_connections = 20

	echo 
	echo "Postgres configuration file is \"$POSTGRE_CONF\""
	echo "Now reconfiguring some variables:"

	IFS=$'\n'
	for VAR in $CONFIG_VARS; do 
		echo $VAR
	done
	echo 
	
	replace_file_var_list "$CONFIG_VARS" $POSTGRE_CONF "ADD" #add-var-if-missing
	
	echo "Restarting Postgres."
	
	systemctl restart postgresql
	
	echo "Done."

}

tune_postgres_database;

