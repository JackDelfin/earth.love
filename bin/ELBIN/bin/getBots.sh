#!/bin/bash
# getBots.sh
# Get List of BOTs

mkdir -pv /home/el/PLAYS/blocker 2>/dev/null;
cd /home/el/PLAYS/blocker;

TODAYDATE=`date +%d/%b/%Y`;
TODAYSTAMP=`date +%Y%m%d`;
TODAYDATETIME=`date +%Y%m%d_%H%M%S`;

echo;
echo "---------------------------";
echo "Date: $TODAYDATETIME";
echo "---------------------------";
echo "TOTAL BOT       :";
cat /LOVE*/*/*/_LOGS/*accessBOT.log /LOVE*/*/_LOGS/*accessBOT.log 2>/dev/null| wc -l;

echo;
echo "TOTAL UNIQUE BOT:";
cat /LOVE*/*/*/_LOGS/accessBOT.log /LOVE*/*/_LOGS/*accessBOT.log 2>/dev/null| \
  sed -e's/^[-a-z0-9\.]*\.[a-z]*:443 //' -e's/^[-a-z0-9\.]*\.[a-z]*:80 //' -e's/^[-a-z0-9\.]*\.[a-z]* //' |\
  cut -d" " -f1 |sort -u |wc -l;

echo "---------------------------";

# Get TODAYs BOT logs
# Exclude certain addresses so we don't block ourselves
cat /LOVE*/*/*/_LOGS/accessBOT.log /LOVE*/*/_LOGS/accessBOT.log 2>/dev/null|\
  sed -f /ELBIN/ipblockWHITELIST.sed | grep -e"$TODAYDATE" >"$TODAYSTAMP"_BOT.log;
# Append vhost and strip off domain word first
cat /LOVE*/*/_LOGS/vhost_accessBOT.log |\
  sed -e's/^[-a-z0-9\.]*\.[a-z]*:443 //' -e's/^[-a-z0-9\.]*\.[a-z]*:80 //' -e's/^[-a-z0-9\.]*\.[a-z]* //' |\
  sed -f /ELBIN/ipblockWHITELIST.sed | grep -e"$TODAYDATE" >>"$TODAYSTAMP"_BOT.log;

# Create unique BOT.ip for today
cat "$TODAYSTAMP"_BOT.log | cut -d" " -f1 |sort -u >BOT.ip;

echo "UNIQUE BOT TODAY $TODAYDATETIME:";
wc -l BOT.ip;

echo "---------------------------";
echo;

echo "Top Bots: topBOT.ip";
/ELBIN/getTopBOT.pl |sort -u |sort -n >topBOT.ip;
tail -n25 topBOT.ip;

/ELBIN/getUFWBOT.pl >ipUFWBOTblock.sh;
chmod +x ipUFWBOTblock.sh;
echo;
echo "Run: ./ipUFWBOTblock.sh";
echo;

