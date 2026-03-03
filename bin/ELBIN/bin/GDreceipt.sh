#!/bin/bash
# GDreceipt.sh <domain_pattern> <1=short>
# Show the receipts from /ELDOMS/RECEIPTS.dat for the web domain(s) specified

dom="$1";
short="$2";

RECEIPTS='/ELDOMS/RECEIPTS.dat';

if [ "$dom" == "" ]; then
  echo;
  echo "GDreceipt.sh <domain_pattern> <1=short>";
  echo;
  exit 1;
fi;

echo;
echo "-------------------------------------------------";
echo " DATE:" `date`;
echo "-------------------------------------------------";
echo " RECEIPT for GoDaddy WEB DOMS: $dom";
echo "-------------------------------------------------";

#
# Show short listing without details if specified
#
if [ "$short" != "1" ]; then
  grep -e"$dom" $RECEIPTS|sed -e's/,/\t/g' -e's/\.000Z//';
fi;

#
# Function to print year details if present
#
printYEAR () {
  DOMCNT=`grep -e"$dom" $RECEIPTS|grep -c -e"$YEAR-"`;
  if [ $DOMCNT -gt 0 ]; then
    DOMTOT=`grep -e"$dom" $RECEIPTS|grep -e"$YEAR-" | cut -d, -f4 | awk '{sum += $1} END {print sum}'`;
    printf "|  $YEAR   %'7d  %'13.2f\n" $DOMCNT $DOMTOT;
  fi
}

echo;
echo   "------------------------------------------";
echo   "| Parameter: $dom";
echo   "------------------------------------------";
echo   "|  YEAR    RECEIPTS        COST          |";
echo   "------------------------------------------";
YEAR=2025; printYEAR;
YEAR=2024; printYEAR;
YEAR=2023; printYEAR;
YEAR=2022; printYEAR;
YEAR=2021; printYEAR;
YEAR=2020; printYEAR;
YEAR=2019; printYEAR;
YEAR=2018; printYEAR;
YEAR=2017; printYEAR;
YEAR=2016; printYEAR;
YEAR=2015; printYEAR;
YEAR=2014; printYEAR;
YEAR=2013; printYEAR;
YEAR=2012; printYEAR;
YEAR=2011; printYEAR;
YEAR=2010; printYEAR;
YEAR=2009; printYEAR;
YEAR=2008; printYEAR;
YEAR=2007; printYEAR;
YEAR=2006; printYEAR;

echo   "------------------------------------------";
DOMCNT=`grep -e"$dom" $RECEIPTS|wc -l`;
DOMTOT=`grep -e"$dom" $RECEIPTS | cut -d, -f4 | awk '{sum += $1} END {print sum}'`;
printf "| TOTALS  %'7d  %'13.0f\n" $DOMCNT $DOMTOT;
echo   "------------------------------------------";
echo;

exit 1;
