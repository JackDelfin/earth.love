#!/bin/bash
# GDvaluations.sh <domain_pattern> <1=short>
# Show the valuations from /ELDOMS/VALUATIONS.dat for the web domain(s) specified

dom="$1";
short="$2";

VALUATIONS='/ELDOMS/VALUATIONS.dat';

if [ "$dom" == "" ]; then
  echo;
  echo "GDvaluations.sh <domain_pattern> <1=short>";
  echo;
  exit 1;
fi;

echo;
echo "-------------------------------------------------";
echo " DATE:" `date`;
echo "-------------------------------------------------";
echo " VALUATIONS for GoDaddy WEB DOMS: $dom";
echo "-------------------------------------------------";

#
# Show short listing without details if specified
#
if [ "$short" != "1" ]; then
  grep -e"$dom" $VALUATIONS|sed -e's/,/\t/g';
fi;

#
# Function to print year details if present
#
printYEAR () {
  DOMCNT=`grep -e"$dom" $VALUATIONS|grep -c -e"Active,$YEAR-"`;
  if [ $DOMCNT -gt 0 ]; then
    DOMRENEW=`grep -e"$dom" $VALUATIONS|grep -e"Active,$YEAR-" | cut -d, -f5 | awk '{sum += $1} END {print sum}'`;
    DOMVALUE=`grep -e"$dom" $VALUATIONS|grep -e"Active,$YEAR-" | cut -d, -f7 | awk '{sum += $1} END {print sum}'`;
    printf "|  $YEAR %'7d  %'8.0f %'11d  |\n" $DOMCNT $DOMRENEW $DOMVALUE;
  fi
}

echo;
echo   "-------------------------------------------";
echo   "| Parameter: $dom";
echo   "-------------------------------------------";
echo   "|  MONTH      DOMS   RENEWAL  VALUATIONS  |";
echo   "-------------------------------------------";
#YEAR=`date +%Y-01`; printYEAR;
#YEAR=`date +%Y-02`; printYEAR;
YEAR='2025-01'; printYEAR;
YEAR='2025-02'; printYEAR;
YEAR='2025-03'; printYEAR;
YEAR='2025-04'; printYEAR;
YEAR='2025-05'; printYEAR;
YEAR='2025-06'; printYEAR;
YEAR='2025-07'; printYEAR;
YEAR='2025-08'; printYEAR;
YEAR='2025-09'; printYEAR;
YEAR='2025-10'; printYEAR;
YEAR='2025-11'; printYEAR;
YEAR='2025-12'; printYEAR;
YEAR='2026-01'; printYEAR;
YEAR='2026-02'; printYEAR;
YEAR='2026-03'; printYEAR;
YEAR='2026-04'; printYEAR;
YEAR='2026-05'; printYEAR;
YEAR='2026-06'; printYEAR;
YEAR='2026-07'; printYEAR;
YEAR='2026-08'; printYEAR;
YEAR='2026-09'; printYEAR;
YEAR='2026-10'; printYEAR;
YEAR='2026-11'; printYEAR;
YEAR='2026-12'; printYEAR;
YEAR='2027-01'; printYEAR;
YEAR='2027-02'; printYEAR;
YEAR='2027-03'; printYEAR;
YEAR='2027-04'; printYEAR;
YEAR='2027-05'; printYEAR;
YEAR='2027-06'; printYEAR;
YEAR='2027-07'; printYEAR;
YEAR='2027-08'; printYEAR;
YEAR='2027-09'; printYEAR;
YEAR='2027-10'; printYEAR;
YEAR='2027-11'; printYEAR;
YEAR='2027-12'; printYEAR;
YEAR='2028-01'; printYEAR;
YEAR='2028-02'; printYEAR;
YEAR='2028-03'; printYEAR;
YEAR='2028-04'; printYEAR;
YEAR='2028-05'; printYEAR;
YEAR='2028-06'; printYEAR;
YEAR='2028-07'; printYEAR;
YEAR='2028-08'; printYEAR;
YEAR='2028-09'; printYEAR;
YEAR='2028-10'; printYEAR;
YEAR='2028-11'; printYEAR;
YEAR='2028-12'; printYEAR;
YEAR='2029-01'; printYEAR;
YEAR='2029-02'; printYEAR;
YEAR='2029-03'; printYEAR;
YEAR='2029-04'; printYEAR;
YEAR='2029-05'; printYEAR;
YEAR='2029-06'; printYEAR;
YEAR='2029-07'; printYEAR;
YEAR='2029-08'; printYEAR;
YEAR='2029-09'; printYEAR;
YEAR='2029-10'; printYEAR;
YEAR='2029-11'; printYEAR;
YEAR='2029-12'; printYEAR;
YEAR='2030-01'; printYEAR;
YEAR='2030-02'; printYEAR;
YEAR='2030-03'; printYEAR;
YEAR='2030-04'; printYEAR;
YEAR='2030-05'; printYEAR;
YEAR='2030-06'; printYEAR;
YEAR='2030-07'; printYEAR;
YEAR='2030-08'; printYEAR;
YEAR='2030-09'; printYEAR;
YEAR='2030-10'; printYEAR;
YEAR='2030-11'; printYEAR;
YEAR='2030-12'; printYEAR;

DOMCNT=`grep -e"$dom" $VALUATIONS|wc -l`;
DOMRENEW=`grep -e"$dom" $VALUATIONS | cut -d, -f5 | awk '{sum += $1} END {print sum}'`;
DOMVALUE=`grep -e"$dom" $VALUATIONS | cut -d, -f7 | awk '{sum += $1} END {print sum}'`;
echo   "-------------------------------------------";
printf "|  TOTALS  %'7d  %'8.0d %'11d  |\n" $DOMCNT $DOMRENEW $DOMVALUE;
echo   "-------------------------------------------";
echo;

exit 1;
