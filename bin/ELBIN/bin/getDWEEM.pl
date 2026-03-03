#!/usr/bin/perl
# Version 1.0.0.0      25-Nov-2024
#*******************************************************************************
#
# getDWEEM.pl   [DOMS.dat]
#
# Purpose:
#   Get the domain DNS A records using 'dig +short <dom>' for the domains in DOMS.dat
#     Default: /ELDOMS/DOMS.dat
#
#   Builds a file named DWEEM.dat consisting of:
#   <domain_name>   <IPAddr>
#
#   ex)
#       ./getDWEEM.pl DOMS.dat
#
# Parameters:
#   <DOMS.dat>
#
# History:
#   2024.11.25 earth.love oK Created
#*******************************************************************************
# Copyright 2024 Kevin Runner / Runchero Federation / PISA
#*******************************************************************************
# License: AGPLv3+: GNU Affero General Public License Version 3 or later
#*******************************************************************************
# This file is part of Akashic for Perl.
#
# Akashic for Perl is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Akashic for Perl is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with Akashic for Perl.  If not, see <https://www.gnu.org/licenses/>.
#*******************************************************************************
use strict;
use warnings;
use feature ':5.16';

my $DOMS = shift;

# Initialize variables
$DOMS = "/ELDOMS/DOMS.dat" if (!defined($DOMS) || $DOMS eq '');

#
# Check for Domain Directory as input
#
if (!-e $DOMS) {
  print "\nERROR: DOMS.dat must be specified as parameter or located at /ELDOMS/DOMS.dat !\n";
  BuildUsage();
}

#
# Load the Akashic subroutines
#
use lib qw( ./lib ../lib );
use Akashic::Process;

#
# Create new Akashic class - Initialize
# - Set DomainDir in EARTH_LOVE environment variable
#
my $A = Akashic->new(1);

#
# Set the Akashic Domain variable and in the environment
#
#$A->SetVar('DomainDir', $DomainDir);
#$ENV{'EARTH_LOVE'} = $DomainDir;

# Initialize the environment (after the Main Root _ROOT is created)
#$A->InitAkashic();

# Check initialization
#BuildUsage() if (!$A->getInitialized());

# Show Start Time and get time in seconds
my $startdate = localtime();
my $starttime = time();
print "Build Start: $startdate\n";

print "############################################################\n";

#*****************************************
#*****************************************
#*****************************************

print "\nProcessing DWEEM.dat for:\n";
print "\n>>> ".$DOMS." <<<\n";

# Open the DOMS.dat file read only
if (!open(DOMS, '<'.$DOMS)) {
  print "ERROR: Could not open $DOMS\n";
  exit 0;
}

# Open the DWEEM.dat for output
if (!open(OUT, '>DWEEM.dat')) {
  print "ERROR: Could not open DWEEM.dat for output\n";
  exit 0;
}

my $DNSrecords='';
my $subdom='';

foreach my $Domain (<DOMS>) {
  chomp($Domain);
  
  # Get the DNS A records
  #$DNSrecords = GetDNS_A_records($Domain, '');
  $DNSrecords = DIG($Domain);
  # Print to standard out and DWEEM.dat
  print "$Domain   $DNSrecords\n";
  print OUT "$Domain   $DNSrecords\n";

  # Check s1-s7 subdomains
  for (my $s=1; $s<=7; $s++) {
    $subdom = 's'.$s.'.'.$Domain;
    $DNSrecords = DIG($subdom);
    
    # Leave after first non-null subdomain
    last if ($DNSrecords eq '');

    print "$subdom   $DNSrecords\n";
    print OUT "$subdom   $DNSrecords\n";
  }
  
  #`sleep 1`; # Only sleep for GoDaddy

} #foreach

close(DOMS);
close(OUT);

print "diff DWEEM.dat /ELDOMS/DWEEM.dat\n";
print `diff DWEEM.dat /ELDOMS/DWEEM.dat`;

print "\nRUN THIS MANUALLY:\ncp -pv DWEEM.dat /ELDOMS\n\n";

#*****************************************
#*****************************************
#*****************************************

# Show End Times
my $enddate = localtime();
my $endtime = time();
my $HMS     = $A->TimeDiffHMS($starttime, $endtime);
print "\n--------------------------------------------------\n";
print "DWEEM Start:  $startdate\n";
print "DWEEM End  :  $enddate\n";
print "--------------------------------------------------\n";
print "TIME : $HMS\n";
print "--------------------------------------------------\n";

print "############################################################\n";

exit 0;


################################################################################
# DIG  <domain>  - return all IP addresses from DNS for this domain
################################################################################
sub DIG {
  my $domain = shift;
  my $IPAddrs = "";
  my @lines;
  
  # Repeat if communications error
  do {
    $IPAddrs = `dig +short $domain`;
  } while ($IPAddrs =~ /communications error/i || $IPAddrs =~ /ID mismatch/);

  # Get IPs in array for sorting
  push @lines,
    split ("\n", $IPAddrs);
  $IPAddrs = '';
  
  # Get Sorted list of IPs
  foreach (sort(@lines)) {
    $IPAddrs .= ' ' if ($IPAddrs ne '');
    $IPAddrs .= $_;
  }
 
  return $IPAddrs;
} #DIG

  
################################################################################
# BuildUsage - Show usage information
################################################################################
sub BuildUsage
{

  print "\nUsage: $0   [DOMS.dat]\n\n";

  print " Purpose:\n";
  print "   Get the domain DNS A records using 'dig +short <dom>' for the domains in DOMS.dat\n";
  print "     Default: /ELDOMS/DOMS.dat\n\n";

  print "   Builds a file named DWEEM.dat consisting of:\n";
  print "   <domain_name>   <IPAddr>\n\n";

  print "   ex)\n";
  print "       ./getDWEEM.pl DOMS.dat\n\n";

  print " Parameters:\n";
  print "   <DOMS.dat>\n";

  exit 1;
}
