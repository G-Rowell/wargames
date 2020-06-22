#!/bin/sh

#This is the main script which then calls the appropriate script for the requested level
#Author: GRowell

#####################################################################
#Script input validation

if [ $# -ne 1 ]
then
	echo "$0: usage: $0 <bandit level number>" >&2
	exit 1
fi

if echo $1 | grep -E -v -x -q "[0-9]+"
then
	echo "$0: error: invalid argument 1: $1" >&2
	exit 1
fi

if [ $1 -lt 0 -o $1 -gt 34 ]  #There are 0-34 bandit levels
then
	echo "$0: error: invalid level number: $1" >&2
	exit 1
fi

fileCheck1=`ls -A1 | grep -Ee '\.sshTemp\.txt' > /dev/null; echo $?`
fileCheck2=`ls -A1 | grep -Ee '\.sshbandit[0-9]+\.script' > /dev/null; echo $?`
if [ $fileCheck1 -eq 0 ] || [ $fileCheck2 -eq 0 ]
then
	echo "$0: error: a temporary file is present"
	exit 1
fi

#####################################################################
#Variable setup

user="bandit$1"
pass=`cat banditPasswords.txt | grep "^$1 .*$" | cut -d' ' -f2`
scriptFile="$user.script"
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

sshpass -p "$pass" ssh -o LogLevel=error -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no "$user"@bandit.labs.overthewire.org -p 2220 'bash -s' < "$parsedScriptFile" > .sshTemp.txt

#####################################################################
#Final output & cleanup of temporary files

cat .sshTemp.txt
rm .sshTemp.txt
rm "$parsedScriptFile"

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