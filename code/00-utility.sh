#!/bin/bash
MY_PATH=$(dirname $(realpath $0))

# Utility functions
#set -v
#set -x

#bold_txt=$(tput bold)
#normal_txt=$(tput sgr0)
RED_TEXT="\033[0;31m$*"
WHITE_TEXT="\033[0;37m$*\e[0;97m"

function trim_str() {
	# Remove leading and trailing whitespaces from a string 
	# $1 : a string 
	echo "$1" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'
}

function remove_all_spaces() {
	# Remove *all* whitespaces from a string
	# $1 : a string
	echo "$1" | tr -d "[:blank:]"
}

function echo_step () {
	# Ref: https://github.com/makinacorpus/osm-mirror/blob/master/update-conf.sh
	# $1 : text
	echo -e "\e[92m\e[1m$1\e[0m"
}

function echo_error () {
	# Ref: https://github.com/makinacorpus/osm-mirror/blob/master/update-conf.sh
	# $1 : text
  echo -e "\e[91m\e[1m$1\e[0m"
}

function replace_file_var() {
# Add or modify variable in a file.
# Replace value of variable (in $1) with a new value (in $2).
# $1 = variable
# $2 = value
# $3 = filename
# $4 = Add a missing variable to the file?  Values: "add"/"yes"/"true" |  (empty or "false")   

# Sample call:
# replace_file_var "name" "João Sousa" "names.txt"
# replace_file_var "name" "João Sousa" "names.txt"  "add"
#
# Match all these cases:
# Around "=" can be any number of whitespaces
# variable=value
# variable=        value
# variable     =value
# variable     =         value
#           variable     =         value

# The variable must start the line, or after whitespaces (\s).
# The following line will not match/replace anything. 
# xxxx variable = value

# Tests: 
# echo "variable = value" |  awk '{gsub(/variable[[:space:]]*[=].*/, "variable=value")} 1'
# awk -v pat="$PAT" -v rep="$REP" '{gsub(pat, rep)} 1' "$3" 
# echo "variable = value" | sed -E "s/^\s*variable\s*=.*/variable=value/g"

	VAR=$1
	VAL=$2
	FILENAM=$3

	# Remove spaces
	VAR=$(trim_str "$VAR")
	VAL=$(trim_str "$VAL")
	FILENAM=$(trim_str "$FILENAM")

	if [[ -z "$VAR" || -z "$VAL" ]]; then
		# Return
		return
	fi		
	
	# $4 = Add to file?  Valid values: TRUE*, YES*, ADD*
	ADD_TO_FILE=$(echo "$4" | tr '[:upper:]' '[:lower:]') 
	if [[ "$ADD_TO_FILE" =~ true*|yes*|add* ]]; then 
		ADD_TO_FILE="yes"
	else
		ADD_TO_FILE=""		
	fi

	if ! test -f "$FILENAM"; then 
		 echo_error "Function ${FUNCNAME}(): Cannot find file [$FILENAM]." >&2
		 return
	fi 

	gawk -i inplace  -v pat="^[[:space:]]*${VAR}[[:space:]]*=.*" -v rep="$VAR=$VAL" 'BEGIN {v=0} {v+=gsub(pat, rep)} END{ if(v==0) exit 100}1' "$FILENAM"
	# Return status:
	# $?: 0,   OK. $VAR was found and substituted 
	#     100, ERROR. Did not find $VAR
	
	# Add to file?
	if test "$?" -eq "100" && test "$ADD_TO_FILE" == "yes"; then
		echo "$VAR=$VAL" >> "$FILENAM" 
	fi
	
	# "$VAR=" exists in $FILENAM?
	#if grep -q "^[[:blank:]]*$VAR[[:blank:]]*=" "$FILENAM"; then
	# quote "#"
	# VAL="#" -->  "\#"
	#VAL=$(echo "$VAL" | sed 's#\##\\\##g')  

	# quote "\"
	# VAL="\" -->  "\\"
	#"VAL=$(echo "$VAL" | sed 's#\\#\\\\#g')  

	#echo "VAR=($VAR) val=($VAL)" >&2
	#sed -i -E "s#^\s*${VAR}\s*=.*#${VAR}=${VAL}#g" "$FILENAM"
	
	#// awk '{ v += sub(/Java/, "Kotlin"); print } END{ if(v==0) exit 100 }' input.txt 
	#
	#gawk -i inplace  -v pat="^[[:space:]]*${VAR}[[:space:]]*=.*" -v rep="$VAR=$VAL" 'BEGIN {v=0} {v+=gsub(pat, rep)} END{ if(v==0) exit 100}1' "$FILENAM" 
	#gawk -i inplace -v pat="^[[:space:]]*${VAR}[[:space:]]*=.*" -v rep="$VAR=$REP" '{v = gsub(pat, rep)} 1' "$FILENAM" 
	#else
	#	# Add to file?
	#	if  test "$ADD_TO_FILE" == "yes"; then
	#		echo "$VAR=$VAL" >> "$FILENAM" 
	#	fi
	#fi
}

function replace_file_var_list() {
	# $1 = list of variable=value pairs separated by \n.
	# Sample:
	#  list = "
	#	    max_connections = 20
	#	    track_activity_query_size = 32768
	#    somevar = someval"
	#
	# $2 = Filename

	LIST="$1"
	FILENAM="$2"

	ADD_TO_FILE="$3" # Valid positive values are; "true" | "add" | "yes". 
	# Can be blank.

	# Loop over the list, split on "\n"
	IFS=$'\n'
	IFS=$'\n'; for LINE in $LIST; do
	
		OIFS=$IFS
		# LINE: 
		# variable = value
		# Split on "="
		IFS='=' read -r -a array <<< "$LINE"
		
		VAR="${array[0]}"
		VAL="${array[1]}"

		IFS=$OIFS

		if [[ -z "$VAR" || -z "$VAL" ]]; then 
			#echo "Function ${FUNCNAME}(): Variable or value not set: variable=$VAR, value=$VAL." >&2
			continue;
	 	fi

		replace_file_var "$VAR" "$VAL" "$FILENAM"	"$ADD_TO_FILE"
	done
}

function calculate_threads() {
	# Number of threads 
	NUM_CPUs=$(grep -c processor /proc/cpuinfo)
	NUM_THREADs=$(( NUM_CPUs<8 ? 8 : NUM_CPUs ))
	echo $NUM_THREADs
}

function calculate_memory() {
	# Calculate available memory in bytes.
	# $1 = Take percentage of available memory.
	# Eg. Take 75% of available memory (in bytes).
	# calculate_memory 75%   
	
	PORCENTO=$(echo "$1" | grep -o '[[:digit:]]\+')
	PORCENTO=$(( "$PORCENTO" + 0 ))

	if test "$PORCENTO" -lt 1; then
		PORCENTO=100;
	fi
	
	# Total and available memory
	MEM_TOT=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
	MEM_AVAIL=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
	# Take $PORCENTO of total memory
	MEM_X=$(( MEM_TOT*PORCENTO/100 ))
	# Take minimum of calculated and available memory
	MEM_X=$(( MEM_X>MEM_AVAIL ? MEM_AVAIL : MEM_X ))

	echo $MEM_X
}

function calc_datetime_diff() {
	# $1 = date 1. 
	# $2 = date 2.
	#
	# Calculate difference between two dates.
	# Returns date/time difference as array of [days, hours, minutes, seconds]
	# ARR[1]=days
	# ARR[2]=hours
	# ARR[3]=minutes
	# ARR[4]=seconds
	#
	# Date format: "%Y-%m-%d %H:%M:%S"
	#
	# You can set the date with:
	# echo $(date +"%Y-%m-%d %H:%M:%S")
	#
	DT1=$1 # Eg."2023-01-26 14:10:34"
	DT2=$2 # Eg."2023-02-27 15:11:35"
	SEC1=$(date -d "$DT1" +"%s")
	SEC2=$(date -d "$DT2" +"%s")
	DIFF=$(($SEC2 - $SEC1))

	# Array
	declare -a ARR

	# Days
	ARR[1]=$(($DIFF / 86400))
	# Hours
	ARR[2]=$(($DIFF % 86400 / 3600))
	# Minutes
	ARR[3]=$(($DIFF % 3600 / 60))
	# Seconds
	ARR[4]=$(($DIFF % 60))

	echo "${ARR[@]}"
}

function check_var() {
 # Check if variable ($1) is set (not empty).
 # Exit and terminate program if not.
	if [ -z "$1" ]; then
 		echo "Variable \"$1\" is not set. Cannot continue.";
		exit 1	
	fi		
}

function get_saved_passwd() {
	# Read a saved password from /root/auth.txt file.
	local P=$(cat /root/auth.txt 2>/dev/null | grep "$1" | tail -1 | awk '{gsub (" ", "", $3); print $3}')
	echo "$P"
}

function check_if_root_super() {
	# Check if login user is sudo/root.
	# Exit and terminate program if not.
	if [ $(id -u) -ne 0 ]; then   
		echo_error "Please run this script as root or super user. (login as root or use sudo)" >&2
		echo_error "eg. Run sudo -s or sudo -i" >&2
		exit 1
	fi
}

function ask_yes_no() {
	# $1 = Question or prompt.
	# $2 = "false" or "true".  If empty or "false", then do "exit 1" if user answers "No".
	#                          If "true", then return the uppercase value of "Y" or "N" to the caller (do not "exit 1").
	#                          Value is returned in $FN_RETURN_VAL.
	#
	# Ask a question and loop until user replies "Y"es or "N"o.
	# Samples: 
	# ask_yes_no "Do you want to continue Y[es] N[o]?"
	#
	# ask_yes_no "Do you want to continue Y[es] N[o]?" , "true"
	# echo "$FN_RETURN_VAL"   # -- Notice... the value Y/N is returned in FN_RETURN_VAL variable!  
	

	# Generic variable that returns value from functions!
	FN_RETURN_VAL="N"

	PROMPT="$1"
	DO_RET="$2"
	if [ -z "$PROMPT" ]; then 
		PROPMT="Do you want to continue? Y[es] N[o]?"
	fi

	while true; do
		echo_step "$PROPMT"
		read -p "$PROMPT" RET
		case "$RET" in
		  [Yy]* ) echo "Continuing..." >&1; break;;
												
		  [Nn]* ) if [ -z "$DO_RET" -o "$DO_RET" == "false" ]; then 
		  						exit 1
		  					else
		  						break
							fi;;
							
	  * ) echo "Reply Yes or No." >&1;;
		esac
	done
	
	# Return "Y" or "N"
	FN_RETURN_VAL=$(echo ${RET:0:1} | tr a-z A-Z)
}

function do_peep() {
	# $1=Number of peeps
	# 	Make tiny peep sound
	# Sample:
	# do_peep 3
	
	N="$1"
	N="${N:-1}"
	
	for _n in $(seq "$N"); do 
		echo -ne '\007'
		sleep 0.1
	done
}
