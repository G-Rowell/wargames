#!/bin/sh

#This is the main script which then calls the appropriate script for the requested level

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

if [ $1 -lt 0 -o $1 -gt 34 ]
then
	echo "$0: error: invalid level number: $1" >&2
	exit 1
fi

user="bandit$1"
pass=`cat banditPasswords.txt | grep "^$1 .*$" | cut -d' ' -f2`

sshpass -p $pass ssh -o LogLevel=error -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $user@bandit.labs.overthewire.org -p 2220 << ! > .sshTemp.txt
echo "-=End of MOTD=-"
echo "-=Logged into server=-"
echo "$ ls"
ls
echo "$ cat readme"
cat readme
!

sed '1,/^-=End of MOTD=-$/d' .sshTemp.txt
rm .sshTemp.txt
