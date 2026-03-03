#!/bin/perl
# geopipe.pl
# - Take IP Addresses on STDIN and run geoiplookup and dig +short -x
use strict;
use warnings;

my $ip;
my $dig;
my $geo;

while (<STDIN>) {
  chomp($_);
  $ip = $_;

  next if ($_ eq "" || $_ =~ /==.*/);

  # Check for valid IP
  next if (!($ip =~ /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/));

  # Get reverse DNS lookup
  $dig=`dig +short -x $ip`;
  chomp($dig);
  $dig = 'comms error' if ($dig =~ /.*communications error.*/);
  
  # Get Country
  $geo=`geoiplookup $ip |sed -e's/GeoIP Country Edition: //'`;
  chomp($geo);
  
  print "$ip \t$geo\t$dig\n";
}

exit 1;

