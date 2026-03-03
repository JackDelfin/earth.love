#!/bin/perl
##########################################
#
# mkPOCKETS.pl <DOM> <1-7> [force]
#
# <DOM> - fqdm (Fully Qualified Domain Name)
# <1-7> - HIVES MASTERS mapping - primary hive
# [force] - (optional) force the DNS entries (for moving domain)
#
# Translate 1-7 on input to the HIVES MASTERS below: s1 s2 s3 s4 s5 s6 s7
# 
##########################################
use strict;
use warnings;

my $DOM=shift;
my $hive=shift;
my $force=shift;

#
# Check inputs
#
if (!defined($DOM) || $DOM eq "") {
  print "\nError: Domain not specified\n";
  Usage();
}

if (!defined($hive) || $hive lt "1" || $hive gt "7") {
  print "\nError: Hive 1-7 not specified\n";
  Usage();
}

$force = "" if (!defined($force) || $force eq "");
if ($force ne "" && $force ne "force") {
  print "\nError: force ($force) not applied correctly\n";
  Usage();
}

# Check for valid domain
my $chkdom=`dig +short $DOM;`;
chomp($chkdom);
if (!defined($chkdom) || $chkdom eq "") {
  print "\nError: Domain not found ($DOM) in dig lookup\n";
  print "Continue Anyways (y/n)?";
  my $ans=<STDIN>;
  chomp($ans);
  print "\n";
  Usage() if ($ans ne "y");
}

#
# SITES 1
#
my @S1IP = qw(
SITES_1_LIST
99.6.104.130
99.6.104.134
99.6.104.138
99.6.104.142
99.6.104.146
99.6.104.150
99.6.104.154
);
#
# SITES 2
#
my @S2IP = qw(
SITES_2_LIST
98.102.175.35
98.102.175.39
98.102.175.43
98.102.175.47
98.102.175.51
98.102.175.55
98.102.175.59
);
#
# SITES 3
#
my @S3IP = qw(
SITES_3_LIST
12.230.237.18
12.230.237.19
12.230.237.20
12.230.237.21
12.230.237.22
12.230.237.23
12.230.237.24
);
#
# SITES 5
#
my @S5IP = qw(
SITES_5_LIST
45.16.92.18
45.16.92.19
45.16.92.19
45.16.92.20
45.16.92.20
45.16.92.21
45.16.92.21
);
#
# SITES 7
#
my @S7IP = qw(
SITES_7_LIST
98.123.155.210
98.123.155.210
98.123.155.211
98.123.155.211
98.123.155.212
98.123.155.213
98.123.155.214
);


print "/ELBIN/setGoDaddyDNS.pl $DOM  $S1IP[$hive] s1\n";
print "/ELBIN/setGoDaddyDNS.pl $DOM  $S2IP[$hive] s2\n";
print "/ELBIN/setGoDaddyDNS.pl $DOM  $S3IP[$hive] s3\n";
#print "/ELBIN/setGoDaddyDNS.pl $DOM  $S4IP[$hive] s4\n";
print "/ELBIN/setGoDaddyDNS.pl $DOM  $S5IP[$hive] s5\n";
#print "/ELBIN/setGoDaddyDNS.pl $DOM  $S6IP[$hive] s6\n";
print "/ELBIN/setGoDaddyDNS.pl $DOM  $S7IP[$hive] s7\n";

$force="--FORCE" if ($force eq "force");

print `/ELBIN/setGoDaddyDNS.pl $DOM  $S1IP[$hive] s1 $force`;
print `/ELBIN/setGoDaddyDNS.pl $DOM  $S2IP[$hive] s2 $force`;
print `/ELBIN/setGoDaddyDNS.pl $DOM  $S3IP[$hive] s3 $force`;
#print `/ELBIN/setGoDaddyDNS.pl $DOM  $S4IP[$hive] s4 $force`;
print `/ELBIN/setGoDaddyDNS.pl $DOM  $S5IP[$hive] s5 $force`;
#print `/ELBIN/setGoDaddyDNS.pl $DOM  $S6IP[$hive] s6 $force`;
print `/ELBIN/setGoDaddyDNS.pl $DOM  $S7IP[$hive] s7 $force`;

exit 1;

#
# Show Usage
#
sub Usage {
  print "\n$0 <DOM> <1-7> [force]\n\n";

  print "<DOM> - fqdm (Fully Qualified Domain Name)\n";
  print "<1-7> - HIVES MASTERS mapping - primary hive\n";
  print "[force] - (optional) force the DNS entries (for moving domain)\n\n";

  print "Translate 1-7 on input to the HIVES MASTERS below: s1 s2 s3 s4 s5 s6 s7\n\n";

  exit 0;
}
