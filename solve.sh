#!/bin/bash

#This is the main script which then calls the appropriate script for the requested level
#Author: GRowell

#####################################################################
#Script helper functions

function print_wargames {
	echo "Wargames available:"
	cut -f 1,6 -d ',' "connections.txt" | sed -E 's/(.*?),(.*?)/\t\2: \1/'
}

function print_wargame_levels {
	if [[ $# -ne 1 ]]	#$1-wargame
	then
		echo "$0: print_wargame_levels: usage: $0 <wargame>" >&2
		exit 1
	fi
}

function valid_wargame {
	local wargame=$(cut -f 1,2 -d ',' "connections.txt" | grep -Ee "(^$1,)|(,$1$)" | cut -f 1 -d ',')
	if [[ -z "$wargame" ]]
	then
		echo "$0: error: invalid argument #1 (wargame): $1" >&2
		exit 1
	fi
}

#####################################################################
#Script input validation

if [[ $# -eq 0 ]]
then
	echo "$0: usage: $0 [options] [wargame] [level number]" >&2
	#echo "$0: try: ./solve.sh --help for more information" >&2 #TODO: Implement?
	print_wargames
	exit 1
fi

if [[ $# -eq 1 ]]	#$1-wargame $2-levelNum 
then
	echo "$0: usage: $0 <wargame>" >&2
	echo "$0: usage: $0 <wargame> <level number>" >&2
	exit 1
fi


print_wargames
print_wargame_levels
exit 0

#	echo "$0: levels with scripts"
#	ls -1v scripts | sed 's/^/   /g' | sed 's/\.script//g'


if echo $2 | grep -E -v -x -q "[0-9]+"
then
	echo "$0: error: invalid argument #2 (level number): $1" >&2
	exit 1
fi

if [[ $1 -lt 0 -o $1 -gt 34 ]] #There are 0-7 leviathan levels
then
	echo "$0: error: invalid level number: $1" >&2
	exit 1
fi

highestSolvedLevel=`ls scripts -1v | tail -n1 | sed 's/\.script//' | sed 's/leviathan//'`
if [[ $1 -gt $highestSolvedLevel ]]
then	
	echo "$0: error: no level script for given level: $1" >&2
	exit 1
fi

fileCheck1=`ls -A1 | grep -Ee '\.sshTemp\.txt' > /dev/null; echo $?`
fileCheck2=`ls -A1 | grep -Ee '\.sshleviathan[0-9]+\.script' > /dev/null; echo $?`
if [[ $fileCheck1 -eq 0 ]] || [[ $fileCheck2 -eq 0 ]]
then
	echo "$0: error: a temporary file is present"
	exit 1
fi

#####################################################################
#Variable setup

user="leviathan$1"
pass=`cat passwords.txt | grep "^$1 .*$" | cut -d' ' -f2`
scriptFile="scripts/$user.script"
parsedScriptFile=".ssh$user.script"

#####################################################################
#Parse script file (add in echo of each command, to show what is being run)

while IFS= read -r line
do
	echo "echo '$ $line'"
	echo "$line"
done < "$scriptFile" > "$parsedScriptFile"

#####################################################################
#Create ssh connection, using 'sshpass' to send the password for the level,
# LogLevel=error to prevent 
# UserKnownHostsFile=/dev/null to prevent
# StrictHostKeyChecking=no to preve
# bash -s (-s has bash read commands from stdin)

sshpass -p "$pass" ssh -o LogLevel=error -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no "$user"@leviathan.labs.overthewire.org -p 2223 'bash -s' < "$parsedScriptFile" > .sshTemp.txt 2>&1

#####################################################################
#Final output & cleanup of temporary files

if [[ $# -eq 2 -a $2 != "-nc" ]] #TODO: Fix this flag, noclean flag
then
	cat .sshTemp.txt		#TODO: Handle colours properly (cat doesn't recognise colours)
	rm .sshTemp.txt
	rm "$parsedScriptFile"
fi 

exit 0

#####################################################################
####################Notes & past commands############################
#####################################################################

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
