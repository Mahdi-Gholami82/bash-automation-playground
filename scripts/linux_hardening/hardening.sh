#!/bin/bash

#config
CREATE_NEW_USER=1
USER_NAME="nick"
CREATE_HOME_DIR=1
USER_SHELL=$(which bash)

SET_APT_MIRROR=1
MIRROR_LINK="http://mirror.aminidc.com/ubuntu"

SSH_PORT=8585
#end-of-config

echo -e "\ninitiating..."

echo "****************************************************************"
uname -n
uname -v
echo "****************************************************************"
echo -e "\n"

#apt mirror
UBUNTU_SOURCES_FILE="/etc/apt/sources.list.d/ubuntu.sources"
UBUNTU_SOURCES_FILE_OLD="/etc/apt/sources.list"
if [[ $SET_APT_MIRROR == 1 ]]; then
	if [[ ! -f $UBUNTU_SOURCES_FILE ]]; then
		UBUNTU_SOURCES_FILE=$UBUNTU_SOURCES_FILE_OLD
	fi		
	perl -pi -e "s#https?:\/\/(?:[\w-]+\.?)+(?:\/[\w-]+)+\/?#$MIRROR_LINK#g" "$UBUNTU_SOURCES_FILE"
fi
if [[ $? == 0 ]]; then 
	echo -e "\e[32mSuccessfully changed mirror\e[0m"
else
	echo -e "\e[31mFailed to change mirror\e[0m"
fi

#system update
echo "System Update and installing neccassary packages"
if ! apt update && apt upgrade; then
	echo -e "\e[31m\nFailed to update!\e[0m"
	exit 1
fi

apt install -y vim wget curl network-manager fail2ban crudini


#new user
if [[ $CREATE_NEW_USER == 1 ]]; then
	if [[ $CREATE_HOME_DIR == 1 ]]; then
		useradd -m "$USER_NAME" 
	else
		useradd "$USER_NAME" 
	fi
fi
if [[ $? == 0 ]]; then
	echo "Successfully created the new user"
fi
usermod -aG sudo "$USER_NAME" || echo -e "\e[31mFailed to add new user to Sudo\e[0m"



#sshd_config
echo "Configuring sshd..."
SSHD_CONFIG="/etc/ssh/sshd_config"
SSHD_CONFIG_OPTIONS="\
PasswordAuthentication,no
Port,$SSH_PORT
PermitRootLogin,no
MaxAuthTries,3
MaxSessions,2
X11Forwarding,no"

cp "$SSHD_CONFIG" "$SSHD_CONFIG.back"

for OPTION in $(echo "$SSHD_CONFIG_OPTIONS" | cut -d "," -f1); do
	OPTION_VALUE=$(echo "$SSHD_CONFIG_OPTIONS" | grep "$OPTION" | cut -d "," -f2)
	perl -0777 -pi -e "/\n$OPTION/
			? s#(\n$OPTION)\s+.+#\1 $OPTION_VALUE#g
			: s#\$#\n$OPTION $OPTION_VALUE#s" "$SSHD_CONFIG"
	if [[ $? == 0 ]]; then
		echo -e "change ($OPTION = $OPTION_VALUE) \e[32msuccess!\e[0m"
	else
		echo -e "change ($OPTION = $OPTION_VALUE) \e[31mfailure!\e[0m"	
	fi	
done
systemctl restart sshd

if [[ $? == 0 ]]; then
        echo -e "\e[32msshd ready!\e[0m"
else 
	echo -e "\e[31msomething went wrong with restarting sshd you might need to do it manually.\e[0m"
fi
#firewall
echo "setting up firewall"
ufw disable && yes "y" | ufw reset
ufw default deny incoming
ufw default allow outgoing

ufw allow "$SSH_PORT"
ufw allow http
ufw allow https

systemctl start ufw
yes "y" | ufw enable


#fail2ban 
echo "configuring fail2ban.."
test -f /etc/fail2ban/fail2ban.local || cp /etc/fail2ban/fail2ban.conf /etc/fail2ban/fail2ban.local
test -f /etc/fail2ban/jail.local || cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local 

FAIL2BAN_CONFIG_OPTIONS="\
bantime,1d
findtime,1d
maxretry,2"

for OPTION in $(echo "$FAIL2BAN_CONFIG_OPTIONS" | cut -d "," -f1); do
	OPTION_VALUE=$(echo "$FAIL2BAN_CONFIG_OPTIONS" | grep "$OPTION" | cut -d "," -f2)
		crudini --set /etc/fail2ban/jail.local sshd "$OPTION" "$OPTION_VALUE":
		if [[ $? == 0 ]]; then
			echo -e "change ($OPTION = $OPTION_VALUE) \e[32msuccess!\e[0m"
		else
			echo -e "change ($OPTION = $OPTION_VALUE) \e[31mfailure!\e[0m"	
		fi
done



#install docker
echo "Installing docker.."
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do 
	sudo apt-get remove $pkg
done

sudo apt update
sudo apt install ca-certificates
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update


sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

docker --version > /dev/null || echo -e "\e[31mThere was a problem with Docker Installation.\e[0m"

