#!/bin/bash

trap "" SIGINT SIGTERM SIGTSTP

SERVER_CHOICES=$"\
ubuntu-2,192.168.1.1
ubuntu-3,192.168.1.2
fedora-1,172.16.1.1
fedora-2,172.16.1.2"

DEFAULT_USER="mahdi"

SERVER_NAMES=`echo "$SERVER_CHOICES" | cut -d "," -f1`  


while true
do
CHOICE=$(whiptail --title "Jump Server Menu" --menu "Choose a Server" 25 78 16 \
	$(echo "$SERVER_NAMES" | sed -e "s/$/ server/g") 3>&1 1>&2 2>&3) 

if [[ $? != 0 ]]; then
clear
exit
fi

CHOICE_IP=$(echo "$SERVER_CHOICES" | grep "$CHOICE" | cut -d "," -f2)

ssh-keyscan $CHOICE_IP >/dev/null &
PID=$!

TERM=ansi whiptail --title "SSH" \
--infobox "Checking host availability...\n$DEFAULT_USER@$CHOICE_IP" 8 50
while kill -0 $PID 2>/dev/null
do
sleep 0.1
done
wait $PID

if [[ $? == 0 ]]; then
	clear 
	ssh -A "$DEFAULT_USER@$CHOICE_IP"
else 
	whiptail --title "SSH" \
--msgbox "Connection Failed!" 8 50 \
--nocancel \
--ok-button "Return To Menu"
continue
fi
done
