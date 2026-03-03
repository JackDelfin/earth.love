#!/bin/bash
# getHackers.sh
# Get List of hackers

mkdir -pv /home/el/PLAYS/blocker 2>/dev/null;
cd /home/el/PLAYS/blocker;

TODAYDATE=`date +%d/%b/%Y`;
TODAYSTAMP=`date +%Y%m%d`;
TODAYDATETIME=`date +%Y%m%d_%H%M%S`;

echo;
echo "---------------------------";
echo "Date: $TODAYDATETIME";
echo "---------------------------";
echo "TOTAL HACK  :";
cat /LOVE*/*/*/_LOGS/*accessHACK.log /LOVE*/*/_LOGS/*accessHACK.log 2>/dev/null| wc -l;

echo;
echo "TOTAL UNIQUE HACK:";
cat /LOVE*/*/*/_LOGS/accessHACK.log /LOVE*/*/_LOGS/*accessHACK.log 2>/dev/null| \
  sed -e's/^[-a-z0-9\.]*\.[a-z]*:443 //' -e's/^[-a-z0-9\.]*\.[a-z]*:80 //' -e's/^[-a-z0-9\.]*\.[a-z]* //' |\
  cut -d" " -f1 |sort -u |wc -l

echo "---------------------------";

# Get TODAYs HACK logs
# Exclude certain addresses so we don't block ourselves
cat /LOVE*/*/*/_LOGS/accessHACK.log /LOVE*/*/_LOGS/accessHACK.log 2>/dev/null|\
  sed -f /ELBIN/ipblockWHITELIST.sed | grep -e"$TODAYDATE" >"$TODAYSTAMP"_HACK.log;
# Append vhost and strip off domain word first
cat /LOVE*/*/_LOGS/vhost_accessHACK.log |\
  sed -e's/^[-a-z0-9\.]*\.[a-z]*:443 //' -e's/^[-a-z0-9\.]*\.[a-z]*:80 //' -e's/^[-a-z0-9\.]*\.[a-z]* //' |\
  sed -f /ELBIN/ipblockWHITELIST.sed | grep -e"$TODAYDATE" >>"$TODAYSTAMP"_HACK.log;

# Create unique HACK.ip for today
cat "$TODAYSTAMP"_HACK.log | cut -d" " -f1 |sort -u >HACK.ip;

echo "UNIQUE HACK TODAY $TODAYDATE_TIME:";
wc -l HACK.ip;

#echo
#echo "------------------------------------------"
#echo "Add 'Require not ip ' before the IPAddr for ipHACKblacklist.conf";
#sed -e's/^/Require not ip /' HACK.ip > ipHACKblacklist.conf

#echo
#echo "------------------------------------------"
#echo 'Run:    sudo cp ipHACKblacklist.conf /etc/apache '
#echo '-or-'
#echo '        sudo cat ipHACKblacklist.conf >>/etc/apache/ipHACKblacklist.conf '
#echo "------------------------------------------"
#echo

#echo
#echo "------------------------------------------"
#echo "Created ipUFWblock.sh:  cat ipUFWblock.sh"
#echo "------------------------------------------"
#sed -e's/^/sudo ufw prepend deny to any from /' HACK.ip > ipUFWblock.sh
#echo "sudo ufw disable;" >> ipUFWblock.sh
#echo "echo y|sudo ufw enable;" >> ipUFWblock.sh

echo "---------------------------";
echo;

echo "Top Hackers: topHACK.ip";
/ELBIN/getTopHACK.pl |sort -u |sort -n >topHACK.ip;
tail -n25 topHACK.ip;

/ELBIN/getUFWHACK.pl >ipUFWHACKblock.sh;
chmod +x ipUFWHACKblock.sh;
echo;
echo "Run: ./ipUFWHACKblock.sh";
echo;

