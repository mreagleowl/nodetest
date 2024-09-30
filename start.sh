#!/bin/bash
cd $HOME
if [ ! $NEWHOSTNAME ]; then
	read -p "Enter a new hostname for this server: " NEWHOSTNAME
fi
sudo hostnamectl set-hostname $NEWHOSTNAME
echo 'New hostname: ' $NEWHOSTNAME
sleep 2
echo '----------------------------------------------------------'
echo '---------------- Update and full upgrade: ----------------'
echo '----------------------------------------------------------'
sudo apt-get update && sudo apt-get full-upgrade -y
sleep 2
echo '----------------------------------------------------------'
echo '-------------------- Installing curl: --------------------'
echo '----------------------------------------------------------'
sudo apt install curl
sleep 2
echo '----------------------------------------------------------'
echo '-------------------- Installing htop: --------------------'
echo '----------------------------------------------------------'
sudo apt install htop
sleep 2
echo '----------------------------------------------------------'
echo '-------------------- Installing ncdu: --------------------'
echo '----------------------------------------------------------'
sudo apt install ncdu
sleep 2
echo '----------------------------------------------------------'
echo '------------------- Installing iotop: --------------------'
echo '----------------------------------------------------------'
sudo apt install iotop
sleep 2
echo '----------------------------------------------------------'
echo '-------------------- REBOOTING !!!: ----------------------'
echo '----------------------------------------------------------'
sleep 4
reboot
