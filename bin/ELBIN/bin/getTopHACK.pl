#!/bin/perl
#
# Get the distribution of Hackers
#
use strict;
use warnings;

mkdir "/home/el/PLAYS";
mkdir "/home/el/PLAYS/blocker";
chdir "/home/el/PLAYS/blocker";

my $cnt;

my $TODAYSTAMP;
$TODAYSTAMP = `date +%Y%m%d`;
chomp($TODAYSTAMP);

open(IPADDR, "< HACK.ip");

foreach my $IP (<IPADDR>) {
  chomp($IP);

  $cnt = `grep ^$IP "$TODAYSTAMP"_HACK.log |wc -l`;
  chomp($cnt);

  print "$cnt\t$IP\n";
}

close(IPADDR);

