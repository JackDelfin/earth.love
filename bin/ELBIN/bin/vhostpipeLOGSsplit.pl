#!/bin/perl
# vhostpipeLOGSsplit.pl [LOG / HACK / BOT] [vhost_combined_logfile]
#
# - Split up a vhost_access log into the respective virtual host LOG access directory: _WEB/DOWN/LOG/CURRENT
#
# LOG  - process normal access.log
# HACK - process accessHACK.log
# BOT  - process accessBOT.log
#
# [vhost_combined_logfile] - optional additional combined log file (not split)
#
# This is called in pipe fashion, as in:
#   cat vhost_accessHACK.log|vhostpipeLOGSsplit.pl HACK
#
# Within the /etc/apache2/conf-available/other-vhosts-access-log.conf:
# CustomLog "| /ELBIN/vhostpipeLOGSsplit.pl LOG  /LOVE/earth.love/_LOGS/vhost_access.log"     vhost_combined "expr=(-z reqenv('hacklog') && -z reqenv('botlog'))"
# CustomLog "| /ELBIN/vhostpipeLOGSsplit.pl HACK /LOVE/earth.love/_LOGS/vhost_accessHACK.log" vhost_combined env=hacklog
# CustomLog "| /ELBIN/vhostpipeLOGSsplit.pl BOT  /LOVE/earth.love/_LOGS/vhost_accessBOT.log"  vhost_combined env=botlog
#
# 2025.1.17 oK Created
#
use strict;
use warnings;

my $LOG=shift;
# Get fully qualified LOG combined filename (optional)
my $LOGcombined=shift;

my $LOGfile="";
my $LOGrec;
my $LOGdir;
my $domport;
my $dom;
my $port;
my $rest;
my $SITESdir = "/etc/apache2/sites-available";
my $domconf;
my $domdir;
my $cnt=0;

# Parameter checking
$LOG = "LOG" if (!defined($LOG));
$LOGcombined = "" if (!defined($LOGcombined));

$LOGfile = "access.log"     if ($LOG =~ /^LOG$/i);
$LOGfile = "accessHACK.log" if ($LOG =~ /^HACK$/i);
$LOGfile = "accessBOT.log"  if ($LOG =~ /^BOT$/i);

if ($LOGfile eq "") {
  print "\nERROR: Invalid LOG type ($LOG) - HACK / BOT / [blank]\n\n";
  exit 1;
}

#
# Read vhost log file from Standard Input (first word of line is the vhost domain)
#
while (<STDIN>) {
  chomp($_);

  # Check for vhosts syntax: hostname.tld:443 ipaddr
  ($domport, $rest) = split(' ', $_);

  # Check for domain and port
  if (!defined($domport) || $domport eq "" || !($domport =~ /.*:.*/)) {
    print "\nERROR: No domain found: $_\n";
    next;
  }

  # Get the domain and port from domain.tld:80 or domain.tld:443
  ($dom, $port) = split(':', $domport);

  # Check for valid port
  if ($port ne "80" && $port ne "443") {
    print "\nERROR: Invalid Port ($domport - $dom $port)\n";
    next;
  }

  # Set LOGrec to be the standard log format
  $LOGrec = $_;
  # Strip off vhost domain
  $LOGrec =~ s/^$domport //;
  
  #
  # Get the CURRENT log directory to append log record
  #

  # Get Domain Config file
  $domconf = "$SITESdir/$dom.conf" if ($port eq "80");
  $domconf = "$SITESdir/$dom-le-ssl.conf" if ($port eq "443");
  if (!-e $domconf) {
    print "\nERROR: Domain Config not found: $domconf ($_)\n";
    next;
  }
  
  # Get the Domain Dir from DocumentRoot in apache conf
  $domdir = `grep -e'^[ \\t]*DocumentRoot' $domconf |sed -e's/^[ \\t]*DocumentRoot[ \\t]*//' -e's:/_WEB\$::' -e'/.*\\/var\\/www\\/html.*/d'`;
  chomp($domdir);
  if ($domdir eq "") {
    print "\nERROR: DocumentRoot NOT FOUND in $domconf for ($dom)\n";
    next;
  }
  if (!-d $domdir) {
    print "\nERROR: Domain Dir ($domdir) does not exist for ($dom)!\n";
    next;
  }

  # Get Domain Root
  $LOGdir = "$domdir/_WEB/DOWN/LOGS/CURRENT";
  if (!-d $LOGdir) {
    print "\nERROR: CURRENT LOGS dir ($LOGdir) does not exist for ($dom)!\n";
    next;
  }

  #
  # Append the log record to existing file
  #
  open(VLOG, ">> $LOGdir/$LOGfile");
  print VLOG $LOGrec."\n";
  close(VLOG);

  #
  # Optionally write to a combined log for all records (from apache pipe)
  #
  if ($LOGcombined ne "") {
    open(VLOGC, ">> $LOGcombined");
    print VLOGC $_."\n";
    close(VLOGC);
  }
  
  # Show progress
  #print "$dom - $domdir\n";
  print ".";
  
  $cnt++;
}

print "\n\nProcessed: $cnt\n\n";

exit 1;

