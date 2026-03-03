#!/bin/bash

mkdir -pv /home/el/PLAYS/blocker 2>/dev/null;
cd /home/el/PLAYS/blocker;

echo "#";
echo "# Get DENY.ip from ufw status";
echo "#";
sudo ufw status|grep DENY|
  sed -e's/.*DENY[ ]*//' -e's/[ ]*//g'|sort -u>DENY.ip;

echo "#";
echo "# Get Top Hackers IP";
echo "#";
/ELBIN/getallTopHACK.pl |sort -u |sort -n 2>&1 |sed -e'/^[1-7]\t/d' |tee topHACK.ip |tail -n10;

echo "#";
echo "# Get Top Bots IP";
echo "#";
/ELBIN/getallTopBOT.pl |sort -u |sort -n 2>&1 |sed -e'/^[1-7]\t/d' |tee topBOT.ip |tail -n10;

echo "#";
echo "# Get Unique IP - UserAgent for all IPs";
echo "#";
cat *BOT.log *HACK.log |cut -d"\"" -f1,6|sed -e's/ .*\] /\t/' -e's/$/"/' |sort -u >ip_UserAgent.ip


wc -l DENY.ip topHACK.ip topBOT.ip ip_UserAgent.ip;


