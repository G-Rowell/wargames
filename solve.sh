#!/bin/bash

#This is the main script which then calls the appropriate script for the requested level
#Author: GRowell

################################################################################
#Set strict shell options

#set -o errexit		#'errexit' - exit script on any error (non-0 return value)
#set -o nounset		#undefined variables are errors
#set -o pipefail		#pipe are (kinda) evaluated (read 'man bash')

#set -x				#Show commands as they are executed

################################################################################
#Constant declarations

readonly CONNECTIONS='meta/connections.txt'
readonly PASSWORDS_DIR='meta/passwords/'

iFlag='false'
kFlag='false'
wargame=''
levelScript=''
#Set as readonly later

################################################################################
#Script helper functions

#Args: $1-error text
function error {
	echo "$0: error: $1" >&2
	exit 1
}

#Args: No args
function usage {
	echo "$0: usage: $0 <wargame>" >&2
	echo "$0: usage: $0 [-ik] <wargame> [level number]" >&2
	echo "$0: flags: '-k' keep temporary files, will prompt for deletion on next run" >&2
	echo "$0: flags: '-i' login to the level, instead of solving it" >&2
	echo -e "\t     note: these two flags are mutually exclusive" >&2
	print_wargames
	#echo "$0: try: ./solve.sh --help for more information" >&2 #TODO: Implement?
}

#Args: No args
function print_wargames {
	echo "Wargames available:"
	cut -f 1,5 -d ',' "$CONNECTIONS" | sed -E 's/(.*?),(.*?)/\t\2: \1/'
}

#Args: $1-wargame	NOTE: Assume caller has validated wargame
function print_wargame_levels {
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

##Args: $1-wargame	Note:set the 'wargame' global
#function set_wargame {
#
#}
#
##Args: $1-wargame	Note:sets the 'level' global
#function set_level {  
#
#}

################################################################################
#Script input validation

while getopts 'ik' flag; do
	case "${flag}" in
		i) iFlag='true' ;;
		k) kFlag='true' ;;
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
else
	if ! valid_wargame "$1"; then
		error "invalid wargame: $1"
	fi
	wargame="$1"

	if [[ $# -eq 1 ]]; then 
		print_wargame_levels "$1"
		exit 0
	fi

	local lowest="$(ls -1v "$wargame/scripts/" | head -n 1 | sed 's/\..*?$//')"
	local highest="$(ls -1vr "$wargame/scripts/" | head -n 1 | sed 's/\..*?$//')"
	
	if [[ $2 =~ "^[0-9]+$" ]]; then
		error "Arg: $2, is not a positive number" >&2
	elif [[ $2 -lt $lowest || $2 -gt $highest ]]; then
		error "$wargame only has levels between $lowest & $highest: $2" >&2
	fi

	levelScript="$(find "$wargame/scripts/" -name "^$2\..*?$")"
	if [[ -n $levelScript ]]; then
		error "no level script for given level: $2" >&2
	fi
fi
	

echo "Printing vars"
echo "$iFlag"
echo "$kFlag"
echo "$wargame"
echo "$levelScript"


readonly iFlag
readonly kFlag
readonly wargame
readonly levelScript

print_wargame_levels $wargame
exit 0
#############################






fileCheck1="$(ls -A1 | grep -Ee '\.sshTemp\.txt' > /dev/null; echo $?)"
fileCheck2="$(ls -A1 | grep -Ee '\.sshleviathan[0-9]+\.script' > /dev/null; echo $?)"
if [[ "$fileCheck1" -eq 0 ]] || [[ "$fileCheck2" -eq 0 ]]; then
	echo "$0: error: a temporary file is present"
	exit 1
fi

################################################################################
#Variable setup

user="leviathan$1"
pass="$(cat passwords.txt | grep "^$1 .*$" | cut -d' ' -f2)"
scriptFile="scripts/$user.script"
parsedScriptFile=".ssh$user.script"

################################################################################
#Parse script file (add in echo of each command, to show what is being run)

while IFS= read -r line; do
	echo "echo '$ $line'"
	echo "$line"
done < "$scriptFile" > "$parsedScriptFile"

################################################################################
#Create ssh connection, using 'sshpass' to send the password for the level,
# LogLevel=error to prevent 
# UserKnownHostsFile=/dev/null to prevent
# StrictHostKeyChecking=no to preve
# bash -s (-s has bash read commands from stdin)

sshpass -p "$pass" ssh -o LogLevel=error -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no "$user"@leviathan.labs.overthewire.org -p 2223 'bash -s' < "$parsedScriptFile" > .sshTemp.txt 2>&1

################################################################################
#Final output & cleanup of temporary files

if [[ $# -eq 2 -a $2 != "-nc" ]]; then #TODO: Fix this flag, noclean flag
	cat .sshTemp.txt		#TODO: Handle colours properly (cat doesn't recognise colours)
	rm .sshTemp.txt
	rm "$parsedScriptFile"
fi 

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