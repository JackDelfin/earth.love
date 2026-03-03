#!/bin/perl
# Build the DOMS.dat file and run some basic statistics
use strict;
use warnings;

my $dom = shift;
# Usage
if (!defined($dom) || !-e $dom) {
  print "$0 <domains_GoDaddy_date.csv>\n\n";
  print "  Build the DOMS.dat file and run some basic statistics\n\n";
  exit 0;
}

# Grab the lowercase domain name and put it in DOMS.dat
print "Generating DOMS.dat\n";
`sed -e 's/,.*//' -e '/Domain Name/d' -e 's/.*/\\L&/' $dom >DOMS.dat;`;

print "\n--------:---------------- \n";
print "Count   : ".`wc -l DOMS.dat`;
print "--------:---------------- \n\n";

print "--------:---------------- \n";
print "     WEB GROUPS\n";
print "--------:---------------- \n";

print "DIG     : ".`grep -ce dig DOMS.dat`;
print ".LAND   : ".`grep -ce "\.land\$" DOMS.dat`;
print "FOOD    : ".`grep -ce food DOMS.dat`;
print "FOODSILO: ".`grep -ce foodsilo DOMS.dat`;
print ".LIFE   : ".`grep -ce "\.life\$" DOMS.dat`;
print ".LOVE   : ".`grep -ce "\.love\$" DOMS.dat`;
print "ECO     : ".`grep -ce eco DOMS.dat`;
print "LOCAL   : ".`grep -ce local DOMS.dat`;
print ".WORLD  : ".`grep -ce "\.world\$" DOMS.dat`;
print ".EARTH  : ".`grep -ce "\.earth\$" DOMS.dat`;
print "101     : ".`grep -ce 101 DOMS.dat`;
print ".SPACE  : ".`grep -ce "\.space\$" DOMS.dat`;

#print "--------:---------------- \n";
#print "NAMES   : ".`grep -ce kevin DOMS.dat`;
#print "JOB     : ".`grep -ce job DOMS.dat`;

print "--------:---------------- \n";
print "RUNNER  : ".`grep -e runner DOMS.dat|sed -e'/kevinrunner/d'|wc -l`;
print "CLEAN   : ".`grep -ce clean DOMS.dat`;
print "RUNCH   : ".`grep -ce runch DOMS.dat`;
print "KEVIN   : ".`grep -ce kevin DOMS.dat`;
print "TEAM    : ".`grep -ce team DOMS.dat`;
print "--------:---------------- \n";
print ".COM    : ".`grep -ce "\.com\$" DOMS.dat`."\n";


mkdir('/ELDOMS');
# Copy the first time
print `cp -pv DOMS.dat /ELDOMS;` if (!-e "/ELDOMS/DOMS.dat");
print "diff DOMS.dat /ELDOMS/DOMS.dat\n";
print `diff DOMS.dat /ELDOMS/DOMS.dat;`;
print "\n";

print "Top TLDs in DOMS.dat:\n";
print `./getTLDcount.sh`;

print "\nTo RELEASE DOMS.dat:\n";
print "cp -pv DOMS.dat /ELDOMS/DOMS.dat\n\n";

print `/ELBIN/help`;

exit 0;

