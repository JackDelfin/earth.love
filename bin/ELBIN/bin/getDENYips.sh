#!/bin/bash

mkdir -pv /home/el/PLAYS/blocker 2>/dev/null;
cd /home/el/PLAYS/blocker;

echo "#";
echo "# Get DENY.ip from ufw status";
echo "#";
sudo ufw status|grep DENY|
  sed -e's/.*DENY[ ]*//' -e's/[ ]*//g'|sort -u>DENY.ip;

# Backup the DENY.ip file
STAMP=`date +%Y%m%d_%H%M%S`;
cp -puv DENY.ip DENY_$STAMP.ip;

wc -l DENY.ip DENY_$STAMP.ip;


