#!/bin/perl
#
# ROTATE_LOGS.pl "<domain_wildcard>" [1/0-CompressARCHIVES]
#   - Rotate the LOGS files to _WEB/DOWN/LOGS/ARCHIVES
#     for all the domains on this server matching the domain_wildcard (?*)
#   - Script only supports ROTATE once a day
#   - [1/0-CompressARCHIVES] - 1 to compress files in ARCHIVES, blank or 0 to just move
#
# 12.16.24 oK Created
#
use strict;
use warnings;
use File::Spec;

my $mydomain = shift;
my $compress = shift;

# Default to all domains
$mydomain = "" if (!defined($mydomain));

# Check to compress logs after moving to ARCHIVES
$compress = 0 if (!defined($compress) || $compress ne "1");

# Check Arguments
ShowUsage() if ($mydomain eq "");

my $SITESdir = "/etc/apache2/sites-available";

chdir $SITESdir;

#
# Get list of domains
#
my @DOMCONFS=`ls $mydomain*.conf;`;

#
# Check for valid domain
#
if ($mydomain ne "" && !-e "$SITESdir/$mydomain.conf" && @DOMCONFS == 0) {
  print "\nERROR DOMAIN CONF NOT FOUND: $SITESdir/$mydomain.conf\n";
  ShowUsage();
}

#
# Get the application directory
#
my ($volume, $appdir, $file) = File::Spec->splitpath(__FILE__);
$appdir =~ s/.$// if ($appdir =~ /.*\/$/);  # Remove Trailing / if present

#
# Loop through each domain and copy the OML
#
my $out;
my $processed=0;
my $domdir;
my $servername;
my $LOGS;
my $LOGSMAIN;
my $LOGSCURRENT;
my $procnt = 0;
my $found;
my $dirconf;
my $logbase;
my $logfile;
my $logoutfile;
my $onceaday;
my $STAMP = `date +%Y%m%d_%H%M%S`;
chomp($STAMP);
my $TODAY = `date +%Y%m%d`;
chomp($TODAY);

# LOOP
foreach my $domconf (@DOMCONFS) {
  $processed = 0;
  chomp($domconf);
  # See if document root exists
  if (!-e $domconf) {
    print "\nERROR: Virtual Host NOT FOUND: $domconf\n";
    next;
  }

  # Get the ServerName from apache conf
  $servername = `grep -e'^[ \\t]*ServerName' $domconf|sed -e's/^[ \\t]*ServerName[ \\t]*//'`;
  chomp($servername);
  if ($servername eq "") {
    print "\nERROR: ServerName [$servername] NOT FOUND for $domconf\n";
    next;
  }

  print "-- Processing: $servername\n";

  # Get the Domain Dir from DocumentRoot in apache conf
  $domdir = DocRoot($servername);
  
  next if ($domdir eq "");
  if (!-d $domdir) {
    print "\nERROR: Domain Dir ($domdir) NOT FOUND\n";
    next;
  }

  #
  # Put the LOGS files under _WEB/DOWN/LOGS/ARCHIVES with password control
  #
  `sudo mkdir -v "$domdir/_WEB/DOWN" 2>/dev/null` if (!-d "$domdir/_WEB/DOWN");
  $LOGSMAIN    = "$domdir/_LOGS";
  $LOGS        = "$domdir/_WEB/DOWN/LOGS";
  $LOGSCURRENT = "$domdir/_WEB/DOWN/LOGS/CURRENT";
  if (!-d "$LOGS") {
    print `sudo mkdir -v "$LOGS"`;
    print `sudo mkdir -v "$LOGS/ARCHIVES" 2>/dev/null`;
    print `sudo mkdir -v "$LOGS/CURRENT" 2>/dev/null`;
    print `sudo mkdir -v "$LOGS/SAMPLE" 2>/dev/null`;
    print `sudo chown -R www-data:www-data $domdir/_WEB/DOWN;`;
    print `sudo chmod -R g+w $domdir/_WEB/DOWN;`;
  }
  
  #
  # access.log
  #
  $logbase = "access";
  $logfile = "$logbase.log";
  $logoutfile = $logbase."_".$STAMP.".log";
  $onceaday = $logbase."_".$TODAY."*.log*";
  $found = `ls $LOGS/ARCHIVES/$onceaday 2>/dev/null|wc -l;`;
  chomp($found);
  # Check for source log file and not already run today
  if (-e "$LOGSMAIN/$logfile" && $found == 0) {
    $out=`sudo mv -v $LOGSMAIN/$logfile $LOGS/ARCHIVES/$logoutfile 2>&1;`;
    chomp($out);
    $processed = 1;
    print "$out\n";
  }
  $found = `ls $LOGS/ARCHIVES/$onceaday 2>/dev/null|wc -l;`;
  chomp($found);
  # Check for source log file in CURRENT directory and not already run today
  if (-e "$LOGSCURRENT/$logfile" && $found == 0) {
    $out=`sudo mv -v $LOGSCURRENT/$logfile $LOGS/ARCHIVES/$logoutfile 2>&1;`;
    chomp($out);
    $processed = 1;
    print "$out\n";
  }

  #
  # accessBOT.log
  #
  $logbase = "accessBOT";
  $logfile = "$logbase.log";
  $logoutfile = $logbase."_".$STAMP.".log";
  $onceaday = $logbase."_".$TODAY."*.log*";
  $found = `ls $LOGS/ARCHIVES/$onceaday 2>/dev/null|wc -l;`;
  chomp($found);
  # Check for source log file and not already run today
  if (-e "$LOGSMAIN/$logfile" && $found == 0) {
    $out=`sudo mv -v $LOGSMAIN/$logfile $LOGS/ARCHIVES/$logoutfile 2>&1;`;
    chomp($out);
    $processed = 1;
    print "$out\n";
  }
  $found = `ls $LOGS/ARCHIVES/$onceaday 2>/dev/null|wc -l;`;
  chomp($found);
  # Check for source log file in CURRENT directory and not already run today
  if (-e "$LOGSCURRENT/$logfile" && $found == 0) {
    $out=`sudo mv -v $LOGSCURRENT/$logfile $LOGS/ARCHIVES/$logoutfile 2>&1;`;
    chomp($out);
    $processed = 1;
    print "$out\n";
  }

  #
  # accessHACK.log
  #
  $logbase = "accessHACK";
  $logfile = "$logbase.log";
  $logoutfile = $logbase."_".$STAMP.".log";
  $onceaday = $logbase."_".$TODAY."*.log*";
  $found = `ls $LOGS/ARCHIVES/$onceaday 2>/dev/null|wc -l;`;
  chomp($found);
  # Check for source log file and not already run today
  if (-e "$LOGSMAIN/$logfile" && $found == 0) {
    $out=`sudo mv -v $LOGSMAIN/$logfile $LOGS/ARCHIVES/$logoutfile 2>&1;`;
    chomp($out);
    $processed = 1;
    print "$out\n";
  }
  $found = `ls $LOGS/ARCHIVES/$onceaday 2>/dev/null|wc -l;`;
  chomp($found);
  # Check for source log file in CURRENT directory and not already run today
  if (-e "$LOGSCURRENT/$logfile" && $found == 0) {
    $out=`sudo mv -v $LOGSCURRENT/$logfile $LOGS/ARCHIVES/$logoutfile 2>&1;`;
    chomp($out);
    $processed = 1;
    print "$out\n";
  }

  #
  # error.log
  #
  $logbase = "error";
  $logfile = "$logbase.log";
  $logoutfile = $logbase."_".$STAMP.".log";
  $onceaday = $logbase."_".$TODAY."*.log*";
  $found = `ls $LOGS/ARCHIVES/$onceaday 2>/dev/null|wc -l;`;
  chomp($found);
  # Check for source log file and not already run today
  if (-e "$LOGSMAIN/$logfile" && $found == 0) {
    $out=`sudo mv -v $LOGSMAIN/$logfile $LOGS/ARCHIVES/$logoutfile 2>&1;`;
    chomp($out);
    $processed = 1;
    print "$out\n";
  }
  $found = `ls $LOGS/ARCHIVES/$onceaday 2>/dev/null|wc -l;`;
  chomp($found);
  # Check for source log file in CURRENT directory and not already run today
  if (-e "$LOGSCURRENT/$logfile" && $found == 0) {
    $out=`sudo mv -v $LOGSCURRENT/$logfile $LOGS/ARCHIVES/$logoutfile 2>&1;`;
    chomp($out);
    $processed = 1;
    print "$out\n";
  }

  ####################################################################
  # virtual host logs
  ####################################################################

  #
  # vhost_access.log
  #
  $logbase = "vhost_access";
  $logfile = "$logbase.log";
  $logoutfile = $logbase."_".$STAMP.".log";
  $onceaday = $logbase."_".$TODAY."*.log*";
  $found = `ls $LOGS/ARCHIVES/$onceaday 2>/dev/null|wc -l;`;
  chomp($found);
  # Check for source log file and not already run today
  if (-e "$LOGSMAIN/$logfile" && $found == 0) {
    $out=`sudo mv -v $LOGSMAIN/$logfile $LOGS/ARCHIVES/$logoutfile 2>&1;`;
    chomp($out);
    $processed = 1;
    print "$out\n";
  }

  #
  # vhost_accessBOT.log
  #
  $logbase = "vhost_accessBOT";
  $logfile = "$logbase.log";
  $logoutfile = $logbase."_".$STAMP.".log";
  $onceaday = $logbase."_".$TODAY."*.log*";
  $found = `ls $LOGS/ARCHIVES/$onceaday 2>/dev/null|wc -l;`;
  chomp($found);
  # Check for source log file and not already run today
  if (-e "$LOGSMAIN/$logfile" && $found == 0) {
    $out=`sudo mv -v $LOGSMAIN/$logfile $LOGS/ARCHIVES/$logoutfile 2>&1;`;
    chomp($out);
    $processed = 1;
    print "$out\n";
  }

  #
  # vhost_accessHACK.log
  #
  $logbase = "vhost_accessHACK";
  $logfile = "$logbase.log";
  $logoutfile = $logbase."_".$STAMP.".log";
  $onceaday = $logbase."_".$TODAY."*.log*";
  $found = `ls $LOGS/ARCHIVES/$onceaday 2>/dev/null|wc -l;`;
  chomp($found);
  # Check for source log file and not already run today
  if (-e "$LOGSMAIN/$logfile" && $found == 0) {
    $out=`sudo mv -v $LOGSMAIN/$logfile $LOGS/ARCHIVES/$logoutfile 2>&1;`;
    chomp($out);
    $processed = 1;
    print "$out\n";
  }

  #
  # vhost_error.log
  #
  $logbase = "vhost_error";
  $logfile = "$logbase.log";
  $logoutfile = $logbase."_".$STAMP.".log";
  $onceaday = $logbase."_".$TODAY."*.log*";
  $found = `ls $LOGS/ARCHIVES/$onceaday 2>/dev/null|wc -l;`;
  chomp($found);
  # Check for source log file and not already run today
  if (-e "$LOGSMAIN/$logfile" && $found == 0) {
    $out=`sudo mv -v $LOGSMAIN/$logfile $LOGS/ARCHIVES/$logoutfile 2>&1;`;
    chomp($out);
    $processed = 1;
    print "$out\n";
  }

  # Increase processed count for total after loop
  $procnt++ if ($processed);

} #foreach $domconf

print "\nProcessed: $procnt\n\n";

# Cycle Apache if we processed anything to reset log pointers
if ($procnt > 0) {
  # Check Apache Config
  print "sudo apachectl configtest;\n";
  print `sudo apachectl configtest;`;
  
  # Reload Apache
  print "sudo systemctl reload apache2;\n";
  print `sudo systemctl reload apache2;`;
}

#
# Show some stats
#
if ($procnt >= 0) {
  print "\n---------------------------\n";
  print ": TOTALS TODAY ($TODAY) :\n";
  print "---------------------------\n";
  #
  # access.log stats
  #
  $logfile = "access_".$TODAY."*.log";
  $out=`sudo cat /LOVE*/*/*/_WEB/DOWN/LOGS/ARCHIVES/$logfile /LOVE*/*/_WEB/DOWN/LOGS/ARCHIVES/$logfile 2>/dev/null|wc -l;`;
  chomp($out);
  print "access.log     : $out\n";
  #
  # accessBOT.log stats
  #
  $logfile = "accessBOT_".$TODAY."*.log";
  $out=`sudo cat /LOVE*/*/*/_WEB/DOWN/LOGS/ARCHIVES/$logfile /LOVE*/*/_WEB/DOWN/LOGS/ARCHIVES/$logfile 2>/dev/null|wc -l;`;
  chomp($out);
  print "accessBOT.log  : $out\n";
  #
  # accessHACK.log stats
  #
  $logfile = "accessHACK_".$TODAY."*.log";
  $out=`sudo cat /LOVE*/*/*/_WEB/DOWN/LOGS/ARCHIVES/$logfile /LOVE*/*/_WEB/DOWN/LOGS/ARCHIVES/$logfile 2>/dev/null|wc -l;`;
  chomp($out);
  print "accessHACK.log : $out\n";
  #
  # error.log stats
  #
  $logfile = "error_".$TODAY."*.log";
  $out=`sudo cat /LOVE*/*/*/_WEB/DOWN/LOGS/ARCHIVES/$logfile /LOVE*/*/_WEB/DOWN/LOGS/ARCHIVES/$logfile 2>/dev/null|wc -l;`;
  chomp($out);
  print "error.log      : $out\n";

  ####################################################################
  # virtual host logs
  ####################################################################

  #
  # vhost_access.log stats
  #
  $logfile = "vhost_access_".$TODAY."*.log";
  $out=`sudo cat /LOVE*/*/*/_WEB/DOWN/LOGS/ARCHIVES/$logfile /LOVE*/*/_WEB/DOWN/LOGS/ARCHIVES/$logfile 2>/dev/null|wc -l;`;
  chomp($out);
  print "vhost_access.log     : $out\n";
  #
  # vhost_accessBOT.log stats
  #
  $logfile = "vhost_accessBOT_".$TODAY."*.log";
  $out=`sudo cat /LOVE*/*/*/_WEB/DOWN/LOGS/ARCHIVES/$logfile /LOVE*/*/_WEB/DOWN/LOGS/ARCHIVES/$logfile 2>/dev/null|wc -l;`;
  chomp($out);
  print "vhost_accessBOT.log  : $out\n";
  #
  # vhost_accessHACK.log stats
  #
  $logfile = "vhost_accessHACK_".$TODAY."*.log";
  $out=`sudo cat /LOVE*/*/*/_WEB/DOWN/LOGS/ARCHIVES/$logfile /LOVE*/*/_WEB/DOWN/LOGS/ARCHIVES/$logfile 2>/dev/null|wc -l;`;
  chomp($out);
  print "vhost_accessHACK.log : $out\n";
  #
  # vhost_error.log stats
  #
  $logfile = "vhost_error_".$TODAY."*.log";
  $out=`sudo cat /LOVE*/*/*/_WEB/DOWN/LOGS/ARCHIVES/$logfile /LOVE*/*/_WEB/DOWN/LOGS/ARCHIVES/$logfile 2>/dev/null|wc -l;`;
  chomp($out);
  print "vhost_error.log      : $out\n";
  
  print "\n";
  
  print "Current active logs in /LOVE/earth.love/_LOGS:\n";
  print `ls -l /LOVE/earth.love/_LOGS/*;`;
}

#
# Compress the log files with gzip if parameter directs us to
#
if ($procnt > 0 && $compress) {
  print "\nCompress the Log files with gzip:\n";
  # Only compress the logs we just worked with from time $STAMP
  $out=`sudo gzip -v /LOVE*/*/*/_WEB/DOWN/LOGS/ARCHIVES/*$TODAY*.log /LOVE*/*/_WEB/DOWN/LOGS/ARCHIVES/*$TODAY*.log;`;
  chomp($out);
  print "$out\n";
}

exit 1;

#
# Get the DocumentRoot for a domainname
#
sub DocRoot {
  my $dom=shift;
  
  $dom =~ s/:80$// if ($dom =~ /:80$/);
  $dom =~ s/:443$/-le-ssl/ if ($dom =~ /:443$/);
  
  my $docroot = `grep -e'^[ \\t]*DocumentRoot' $dom.conf |sed -e's/^[ \\t]*DocumentRoot[ \\t]*//' -e's:/_WEB\$::' -e'/.*\\/var\\/www\\/html.*/d'`;
  chomp($docroot);

  return $docroot;
}

#
# Show Usage
#
sub ShowUsage {
  print "\nROTATE_LOGS.pl \"<domain_wildcard>\" [1/0-CompressARCHIVES]\n\n";
  
  print "  - Rotate the LOGS files to _WEB/DOWN/LOGS/ARCHIVES\n";
  print "    for all the domains on this server matching the domain_wildcard (?*)\n\n";
  print "  - Script only supports ROTATE once a day\n";
  
  print "  - [1/0-CompressARCHIVES] - 1 to compress files in ARCHIVES, blank or 0 to just move\n\n";

  print "  ex) ./ROTATE_LOGS.pl \"*.earth\" 1\n\n";

  exit 0;
}

