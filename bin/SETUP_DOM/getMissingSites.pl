#!/bin/perl
#
# getMissingSites.pl [myIPaddress]
#
# - Get the Sites to add to this server based on ip Address passed in
# - Searches /ELDOMS/DWEEM.dat for s1-7 records based on IP Address stored in my.ip
# - If myIPaddress is not specified, my.ip will be used for the external IP address
# - searches exists_<IPADDRESS>.out to see if already exists if not found in /etc/apache2/sites-available
#   - for remote checking
#
use strict;
use warnings;

my $IP=shift;
my $site;
my $fileIP;
my $cnt=0;
my $total;
my $found;

# Get the date STAMP
my $STAMP=`date +%Y%m%d;`;
chomp($STAMP);

# Get my.ip from file if not specified as parameter
if (!defined($IP) || $IP eq "") {
  $IP=`cat my.ip;`;
  chomp($IP);
}

# Check if file "my.ip" exists
if (!-e "my.ip" && (!defined($IP) || $IP eq "")) {
  print "\nERROR: my.ip not found!\n\n";
  exit 1;
}

# Check for IP variable
if (!defined($IP) || $IP eq "") {
  print "\nERROR: IP Address ($IP) not found in my.ip!\n";
  exit 1;
}

my $OUTfile;
$OUTfile=$IP."_SETUP_DOM_".$STAMP.".sh";
my $IPexistsfile;

my @SITES=`grep $IP /ELDOMS/DWEEM.dat;`;

$total=scalar @SITES;

# Loop through all SITES for my.ip and see if they are processed or not
foreach my $line (@SITES) {
  chomp($line);

  # Reduce multiple spaces to one space so split gets correct results
  $line =~ s/[ ].*/ /g;

  ($site, $fileIP) = split(' ', $line); 
  
  # Check for site existing in sites-available with SSL activated
  # skip if SSl already enabled for this site
  # FOR LOCAL MACHINE EXECUTION
  next if (-e "/etc/apache2/sites-available/$site-le-ssl.conf");
  
  # For REMOTE EXECUTION
  # Check the exists_<IPAddress>.out file
  $IPexistsfile="exists_$IP.out";
  if (-e $IPexistsfile) {
    $found = `grep -e"^$site" exists_$IP.out;`;
    chomp($found);
    # Go to next record if found in the exists file
    next if ($found ne "");
  }
  
  # Append the line to the setup file for this IP
  # - Use the default domain group from elSETUP_DOM since we have no other intel
  open(OUT, ">>$OUTfile");
  print OUT "./elSETUP_DOM.pl $site\n";
  close(OUT);
  $cnt++;
}

# Show processed summary
print "\nProcessed IP ($IP): Missing $cnt / $total\n";

if ($cnt > 0) {
  # Set execute bit on output file
  `chmod +x $OUTfile;`;
  print "Run:   ./$OUTfile\n";
}

exit 1;

