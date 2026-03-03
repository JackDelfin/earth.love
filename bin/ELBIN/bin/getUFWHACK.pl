#!/bin/perl
#
# Get the distribution of Hackers in ufw blocking script
#
use strict;
use warnings;

mkdir "/home/el/PLAYS";
mkdir "/home/el/PLAYS/blocker";
chdir "/home/el/PLAYS/blocker";

my $cnt;
my $ipDENYexists;

my $TODAYSTAMP;
$TODAYSTAMP = `date +%Y%m%d`;
chomp($TODAYSTAMP);
my $STAMP;

print "\n\n# UFW Deny IP List - make sure yours is not in the list\n\n";

print "# Get existing DENY ip list from into ipUFWDENY.out\n\n";
`sudo ufw status|grep DENY>ipUFWDENY.out`;

#
# RESTRICT HACK IPs from TODAY
#
open(IPADDR, "< HACK.ip");
#
foreach my $IP (<IPADDR>) {
  chomp($IP);
  #
  # Check for "HostnameLookups" for the IP name - do IP Lookup
  # i.e. ec2-13-250-15-200.compute.datacenter.com;
  #
  if (!($IP =~ /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/)) {
    #print "Doing IP Lookup for: $IP - ";
    $IP = `dig +short $IP`;
    chomp($IP);
    #print "$IP\n";
    next if ($IP eq "");
  }
  #
  # Get IP from today's logs
  $cnt = `grep $IP "$TODAYSTAMP"_HACK.log |wc -l`;
  chomp($cnt);
  #
  # Check if IP is currently being Denied
  $ipDENYexists = `grep $IP ipUFWDENY.out`;
  chomp($ipDENYexists);
  $STAMP=`date +%Y%m%d_%H%M%S;`;
  chomp($STAMP);
  #
  # Print the deny if over 2 attempts
  print "echo $STAMP `sudo ufw prepend deny to any from $IP;` \"- DENY ($cnt):\" `/ELBIN/cip $IP;`\n" if ($cnt >= 2 && $ipDENYexists eq "");
}
#
close(IPADDR);

print "\nsudo ufw reload;\n";
#print "echo 'sudo ufw status;'\n\n";

exit 1;
