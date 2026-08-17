#!/bin/bash -e
##########################################
# el_setup_BASE.sh
#
# Install the BASE components for Akashic-Orbit
#
# Consider redirecting output from this script to a log record
# ./el_setup_BASE.sh 2>&1 1|tee el_setup_BASE_`date +%Y%m%d_%H%M%S`.out
#
# 2024.11.27 oK refactored
# 2022.09.13 oK created
##########################################

echo '##################################################';
echo '# Install the BASE components for Akashic-Orbit  #';
echo '##################################################';

echo
echo '# System Information:';
lsb_release -a;
DISTRO=`lsb_release -is`;
PROCESSORS=`cat /proc/cpuinfo |grep processor|wc -l`;
echo
echo 'Processors:' $PROCESSORS;
cat /proc/meminfo | grep MemTotal;
echo 'Drives:';
lsblk|grep -e"G " -e"T "|sed -e'/^loop/d';

#########################################
echo
echo '# -------------------------'
echo '# System Update and Upgrade'
echo '# -------------------------'
# CHECK ONLY
echo '--'
echo '-- apt-get update  # Check ONLY'
echo '--'
sudo apt-get update
sudo apt update

# DO UPGRADE
echo
echo '--'
echo '-- apt upgrade -y'
echo '--'
sudo apt upgrade -y

echo
echo '# -------------------------'
echo '# Install snap Installer (certbot latest version)'
echo '# -------------------------'
sudo apt install snap

echo
echo '# -------------------------'
echo '# Install Needed Components'
echo '# -------------------------'
echo
echo '--'
echo '-- Install cpp'
echo '--'
sudo apt install cpp -y
echo
echo '--'
echo '-- Install gcc'
echo '--'
sudo apt install gcc -y

echo
echo '--'
echo '-- Install dos2unix'
echo '--'
sudo apt install dos2unix -y

echo
echo '--'
echo '-- Install curl'
echo '--'
sudo apt install curl -y

echo
echo '--'
echo '-- Install wget'
echo '--'
sudo apt install wget -y

echo
echo '--'
echo '-- Install rsync'
echo '--'
sudo apt install rsync -y

echo
echo '--'
echo '-- Install geoip-bin - geoiplookup'
echo '--'
sudo apt install geoip-bin -y;

echo
echo '--'
echo '-- Install rfkill'
echo '--'
sudo apt install rfkill -y

# Don't block Wireless and Bluetooth Automatically
#echo
#echo '--'
#echo '-- Block Bluetooth and Wireless'
#echo '--'
#echo '-- BEFORE'
#sudo rfkill
#sudo rfkill block 0
#sudo rfkill block 1
#sudo rfkill block 2
#echo '-- AFTER'
#sudo rfkill

echo
echo '# -------------------------'
echo '# -- INSTALL NETWORKS'
echo '# --     and SYS UTILITIES'
echo '# -------------------------'
echo
echo '--'
echo '-- Install dnsutils'
echo '-- - dig hostname'
echo '--'
sudo apt install dnsutils -y
echo
echo '--'
echo '-- Install net-tools'
echo '--'
sudo apt install net-tools -y
echo
echo
echo '--'
echo '-- Install inetutils-traceroute'
echo '--'
sudo apt install inetutils-traceroute -y
echo
echo '--'
echo '-- Install sysstat'
echo '--'
sudo apt install sysstat -y
echo
echo '--'
echo '-- Install atop'
echo '--'
sudo apt install atop -y

echo
echo '--'
echo '-- Install OpenSSH'
echo '--'
sudo apt install openssh-server -y
sudo systemctl enable ssh

echo
echo '# -------------------------'
echo '# -- Install Apache2'
echo '# -------------------------'
sudo apt install apache2 -y

echo
echo '# -------------------------'
echo '# -- Install libcurl4 and dev'
echo '# -------------------------'
sudo apt install pkg-config -y
sudo apt install libcurl4 -y
sudo apt install libcurl4-openssl-dev -y

echo
echo '--'
echo '-- Set el user to www-data group'
echo '--'
sudo usermod -a -G www-data el

echo
echo '# -------------------------'
echo '# -- Install goaccess'
echo '# -------------------------'
sudo apt install goaccess -y

echo
echo '# -------------------------'
echo '# -- Install Perl CPAN: LWP/CGI'
echo '# -------------------------'

echo
echo '--'
echo '-- Install perl'
echo '--'
sudo apt install perl -y

echo
echo '--'
echo '-- Install cpanminus'
echo '--'
sudo apt install cpanminus -y

echo
echo '--'
echo '-- CPAN LWP'
echo '--'
echo 'YES
'|sudo cpan LWP

echo
echo '--'
echo '-- CPAN NET::CURL'
echo '--'
sudo cpan ExtUtils::PkgConfig
sudo cpan Net::Curl::Easy

echo
echo '--'
echo '-- CPAN CGI'
echo '--'
sudo cpan CGI

echo
echo '--'
echo '-- CPAN JSON JSON::MaybeXS'
echo '--'
sudo cpan JSON
sudo cpan JSON::MaybeXS

echo
echo '--'
echo '-- Perl authentication crypto (apt)'
echo '-- Crypt::Argon2 hashes passphrases; Crypt::URandom provides secure random bytes'
echo '-- Term::ReadKey safely reads passphrases in the local eluser tool'
echo '--'
sudo apt install libcrypt-argon2-perl libcrypt-urandom-perl libterm-readkey-perl -y

echo
echo '# -------------------------'
echo '# Install ImageMagick'
echo '#   Command-Line Image Conversion Tools'
echo '# -------------------------'
sudo apt-get install imagemagick -y

echo
echo '# -------------------------'
echo '# Install UFW'
echo '#   Uncomplicated Fire WALL'
echo '# -------------------------'
sudo apt install ufw -y

echo
echo '-- Configure UFW -' $DISTRO
#
# UBUNTU
if [ $DISTRO == 'Ubuntu' ]; then
  sudo ufw allow ssh
  sudo ufw allow 'Apache'
  sudo ufw allow 'Apache Secure'
fi
#
# DEBIAN
if [ $DISTRO == 'Debian' ]; then
  sudo ufw allow OpenSSH
  sudo ufw allow 'WWW'
  sudo ufw allow 'WWW Secure'
fi
echo y|sudo ufw enable
sudo ufw status|grep ALLOW

echo
echo '# -------------------------'
echo '# Configure Apache'
echo '# -------------------------'

echo
echo '--'
echo '-- Enable CGI on Apache2'
echo '--'
sudo a2enmod cgid

echo
echo '--'
echo '-- Enable SSL on Apache2'
echo '--'
sudo a2enmod ssl

echo
echo '--'
echo '-- Enable the Apache2 Rewrite Rules module'
echo '-- - /etc/elRewrite.conf'
echo '-- - contains BOT and HACK rules for logging'
echo '--'
sudo a2enmod rewrite

echo
echo '--'
echo '-- Install Certbot for HTTPS Certificate Management'
echo '--'
sudo snap install --classic certbot
# - Raspberry Pi OS
# sudo apt install certbot

echo
echo '--'
echo '-- Restart Apache2'
echo '--'
sudo systemctl restart apache2

echo '#########################################'
echo '# BASE Setup Complete'
echo '#########################################'
