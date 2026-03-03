#!/bin/perl
#
#
# Get the Remaining Forwarding Domains from the GoDaddy domain_date.csv file
# and put them in elFORWARDS.txt for review
#
#
use strict;
use warnings;

my $DOMS = shift;

my $out = 'elFORWARDS.txt';
my $getout = 'getGoDaddy.txt';
my $setout = 'setGoDaddy.txt';
# Usage
if (!defined($DOMS) || !-e $DOMS) {
  print "\n$0 <domains_GoDaddy_date.csv>\n\n";
  print " Get the Remaining Forwarding Domains from the GoDaddy domain_date.csv file\n";
  print " and put them in $out for review and assignment\n\n";
  exit 0;
}

#
# Get the domains still being forwarded from the GoDaddy domain list
#
`cut -d"," -f1,4 $DOMS |sed -e 's/.*/\\L&/'|sed -e'/,\$/d' -e's/,/\t\t# /'>$out;`;

# Build getGoDaddy
`cut -d"," -f1,4 $DOMS |sed -e 's/.*/\\L&/'|sed -e's/^/\\/ELBIN\\/getGoDaddyDNS.pl  /' -e's/,\$//' -e's/,/ \t# /'>$getout;`;

# Build setGoDaddy
`cut -d"," -f1,4 $DOMS |sed -e 's/.*/\\L&/'|sed -e'/,\$/d' -e's/^/\\/ELBIN\\/setGoDaddyDNS.pl  /' -e's/,/        99.6.104.     s1       # /' >$setout;`;

print "\n";
print "-----------------------\n";
print "Building $out\n";
print "-----------------------\n";
print "- remaining WEB Domains with forwarding turned ON\n";

print "\nRecords:\n".`wc -l $out $getout $setout;`."\n";

print `head -n5 $out;`;
print "\n";
print `tail -n5 $getout;`;
print "\n";
print `tail -n5 $setout;`;
print "\n";

print "# Copy $out $getout $setout to /ELDOMS\n\n";
mkdir('/ELDOMS') if (!-d '/ELDOMS');
print `cp -puv $out /ELDOMS/;`;
print `cp -puv $getout /ELDOMS/;`;
print `cp -puv $setout /ELDOMS/;`."\n";

exit 1;

