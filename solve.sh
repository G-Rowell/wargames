#!/bin/bash

#This is the main script which then calls the appropriate script for the requested level
#Author: GRowell

################################################################################
#Set strict shell options

set -o errexit		#'errexit' - exit script on any error (non-0 return value)
set -o nounset		#undefined variables are errors
set -o pipefail		#pipe are (kinda) evaluated (read 'man bash')

#set -x				#Show commands as they are executed

################################################################################
#Constant declarations

readonly CONNECTIONS='meta/connections.txt'
readonly PASSWORDS_DIR='meta/passwords/'

iFlag='false'
kFlag='false'
vFlag='true'
wargame=''
level=0
scriptFile=''
parsedScriptFile="meta/parsed.script"
sshOutput='meta/sshLog.txt'
username=''
password=''
hostname=''
port=''
#Set as readonly later

################################################################################
#Script helper functions

#Args: $1-error text
function error {
	echo "$0: error: $1" >&2
	exit 1
}

#Args: $1-information/debug text
function verbose {
	if [[ $vFlag = 'true' ]]; then
		echo "$0: $1"
	fi
}

#Args: No args
function usage {
	echo "$0: usage: $0 <wargame>" >&2
	echo "$0: usage: $0 [-ikq] <wargame> [level number]" >&2
	echo "$0: flags: '-k' keep temporary files, will prompt for deletion on next run" >&2
	echo "$0: flags: '-i' login to the level, instead of solving it" >&2
	echo "$0: flags: '-q' decrease verbosity" >&2
	echo -e "\t     note: 'k' & 'i' are mutually exclusive" >&2
	print_wargames
	#echo "$0: try: ./solve.sh --help for more information" >&2 #TODO: Implement?
}

#Args: No args
function print_wargames {
	echo "Wargames available:"
	cut -f 1,5 -d ',' "$CONNECTIONS" | sed -E 's/(.*?),(.*?)/\t\2: \1/'
}

#Args: $1-wargame
function print_wargame_levels {
	valid_wargame "$1"
	echo "Levels with scripts:"
	ls -1v "$1/scripts" | sed 's/\..*$//' | sed -E 's/^([0-9])$/0\1/' | column -c 20
}

#Args: $1-wargame	#NOTE: Exits script if the wargame is invalid, otherwise quit
function valid_wargame {
	local wargame="$(cut -f 1 -d ',' "$CONNECTIONS" | grep -Ee "^$1$")"
	if [[ -z $wargame ]]; then
		error "invalid wargame: $1"
	fi
	return 0
}

#Args: $1-wargame $2-level
function valid_level {
	valid_wargame "$1"

	#Make a main function and two vars below 'local'?
	local lowest="$(ls -1v "$1/scripts/" | head -n 1 | sed -E 's/\..*?$//')"
	local highest="$(ls -1vr "$1/scripts/" | head -n 1 | sed -E 's/\..*?$//')"
	
	if [[ $2 =~ "^[0-9]+$" ]]; then
		error "Arg: $2, is not a positive number" >&2
	elif [[ $2 -lt $lowest || $2 -gt $highest ]]; then
		error "$1 only has levels between $lowest & $highest: $2" >&2
	fi

	#'find' is an utterly silly command, which has terrible regex formatting,
		#defaults and design. EG. find "bandit/scripts" -regex 'bandit/scripts/2.*'
		#how ridiculous is it that you have to provide the path twice!?!?!
		#TODO: Fix the below, and write for non .ssh scripts
	levelScript="$(ls "$1/scripts/$2.ssh")"
	if [[ -z $levelScript ]]; then
		error "no level script for given level: $2" >&2
	fi
	return 0
}

################################################################################
#Script input validation

while getopts 'ikq' flag; do
	case "${flag}" in
		i) iFlag='true' ;;
		k) kFlag='true' ;;
		q) vFlag='false' ;;
		#TODO: Check the syntax of getopts, maybe need preceeeding ':'
		#*) error "Unexpected option ${flag}" ;;
	esac
done

shift "$(($OPTIND -1))" #Discard flags found by 'getopts' from "$@"

if [[ $iFlag == "true" && "$kFlag" == "true" ]]; then
	error "i(nteractive) & k(eep) flags are mutually exclusive"
fi

if ! [[ $# -eq 1 || $# -eq 2 ]]; then
	usage
	if [[ $# -ne 0 ]]; then
		error "unsupported number of arguments: $#, args: $*"
	fi
	exit 0
fi

if [[ $# -eq 1 ]]; then 
	if valid_wargame "$wargame"; then
		print_wargame_levels "$wargame"
		exit 0
	fi
fi

################################################################################
#Variable setup

wargame="$1"
level="$2"

if ! valid_wargame "$wargame"; then
	error "invalid wargame: $wargame"
elif ! valid_level "$wargame" "$level"; then
	error "invalid level: $level"
fi

scriptFile="$wargame/scripts/$level.ssh"
username="$wargame$level"
password="$(grep "meta/passwords/$wargame" -e "^$level " | cut -d ' ' -f 2)"
hostname="$(grep 'meta/connections.txt' -e "^$wargame," | cut -d ',' -f 2)"
port="$(grep 'meta/connections.txt' -e "^$wargame," | cut -d ',' -f 3)"

readonly iFlag
readonly kFlag
readonly wargame
readonly level
readonly scriptFile
readonly parsedScriptFile
readonly sshOutput
readonly username
readonly password
readonly port

verbose "variables are setup...notably username: $username"

#echo "Vars:"
#echo "$iFlag"
#echo "$kFlag"
#echo "$wargame"
#echo "$level"
#echo "$scriptFile"
#echo "$parsedScriptFile"
#echo "$sshOutput"
#echo "$username"
#echo "$password"
#echo "$port"
#echo "done"

################################################################################
#Check for exisiting log/temp files
if [[ -f $parsedScriptFile ]] || [[ -f $sshOutput ]]; then
	echo "There are temporary file(s) present,"

	while true; do
	    read -p "do you wish to overwrite these temporary files?" answer 
	    case $answer in
	        [Yy]* ) 
				rm -f "$sshOutput"
				rm -f "$parsedScriptFile"
				break;;

	        [Nn]* )
				echo "Not overwriting temporary files, located in ./meta/"
				echo "Exiting"
				exit 1;;
	        * ) echo "Please answer yes or no.";;
	    esac
	done
fi

################################################################################
#Solve the challenge OR
if [[ $iFlag = 'false' ]]; then
	############################################################################
	#Parse script file (add in echo of each command, to show what is being run)
	#TODO: Investigate better ways to read commands, maybe `tee`
	verbose "processing the script"

	while IFS= read -r line; do
		echo "echo '$ $line'"
		echo "$line"
	done < "$scriptFile" > "$parsedScriptFile" 

	############################################################################
	#Start SSH session through `sshpass`
	#Create ssh session, using 'sshpass' to send the password for the level,
		#LogLevel=error to prevent 
		#UserKnownHostsFile=/dev/null to prevent
		#StrictHostKeyChecking=no to preve
		#bash -s (-s has bash read commands from stdin)
	verbose "starting the ssh session"

	sshpass -p "$password" ssh -o LogLevel=error -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no "$username@$hostname" -p $port 'bash -s' < "$parsedScriptFile" > "$sshOutput" 2>&1

	############################################################################
	#Show the ssh session
	#TODO: Handle colours properly (cat doesn't recognise colours)
	#Does 'echo -e' work? allow backslash escapes?
	verbose "==========Start of ssh session"

	cat "$sshOutput"

	verbose "==========End of ssh session"

	############################################################################
	#Clean the temporary files
	if [[ $kFlag = 'false' ]]; then
		rm "$sshOutput"
		rm "$parsedScriptFile"
	fi 

################################################################################
#Perform interactive session, IE. don't solve the challenge, just log in
else
	#Create ssh session, using 'sshpass' to send the password for the level,
		#LogLevel=error to prevent 
		#UserKnownHostsFile=/dev/null to prevent
		#StrictHostKeyChecking=no to preve
	verbose "starting the sss session"

	sshpass -p "$password" ssh -o LogLevel=error -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no "$username@$hostname" -p $port
	
fi

verbose "done, exiting"
exit 0

################################################################################
############################Notes & past commands###############################
################################################################################

#echo "-=End of MOTD=-"
#echo "-=Logged into server=-"
#echo "$ ls"
#ls
#echo "$ cat readme"
#cat readme

#sshpass -p $pass ssh -o LogLevel=error -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $user@bandit.labs.overthewire.org -p 2220 << ! > .sshTemp.txt
#bash -s
#!
#sed '1,/^-=End of MOTD=-$/d' .sshTemp.txt | echo
#!/bin/bash

#input="./bandit0.script"
#
#while IFS= read -r line
#do
#  echo "echo '$ $line'"
#  echo "$line"
#done < "$input" > "./tempOutPut.txt"
