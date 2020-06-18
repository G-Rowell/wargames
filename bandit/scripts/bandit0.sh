#!/bin/bash

#This is a bash script written by G-Rowell to solve the Bandit wargame by OverTheWire
#https://overthewire.org/wargames/bandit/

user=bandit0
pass=bandit0

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
