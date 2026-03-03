#!/bin/perl
# geologpipe.pl
# - Take IP Addresses on STDIN and run geoiplookup and dig +short -x
use strict;
use warnings;

my $dom;
my $ip;
my $rest;
my $dig;
my $geo;

while (<STDIN>) {
  chomp($_);
  ($ip, $rest) = split(' ', $_);
  $rest = $_;

  if (!defined($ip)) {
    print "\n";
    next;
  }

  # Check for valid IP
  if (!($ip =~ /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/)) {
    # Check for vhosts syntax: hostname.tld:443 ipaddr
    ($dom, $ip, $rest) = split(' ', $_);
    $rest = $_;

    if (!defined($ip)) {
      print "\n";
      next;
    }
    
    # Check again for valid IP
    if (!($ip =~ /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/)) {
      print "$rest\n";
      next;
    }
  }

  # Get reverse DNS lookup
  $dig=`dig +short -x $ip`;
  chomp($dig);
  $dig = 'comms error' if ($dig =~ /.*communications error.*/);
  
  # Get Country
  $geo=`geoiplookup $ip |sed -e's/GeoIP Country Edition: //'`;
  chomp($geo);
  
  #ORIG print "$ip \t$geo\t$dig\n";
  print "$geo\t$dig\t$rest\n";
}

exit 1;

