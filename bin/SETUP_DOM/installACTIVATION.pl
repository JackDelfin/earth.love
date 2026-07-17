#!/bin/perl
#
# installACTIVATION.pl "<domain_wildcard>"
#   - Installs the activation OML on all the domains on this server matching the domain_wildcard (?*)
#
# 12.16.24 oK Updated for ACTIVATION root - only copy root common _TEMPLATES if they don't exist; added .htaccess setup
# 12.12.24 JAD Created
#
use strict;
use warnings;
use File::Spec;

my $mydomain = shift;

# Default to all domains
$mydomain = "" if (!defined($mydomain));

# Check Arguments
ShowUsage() if ($mydomain eq "");

my $SITESdir = "/etc/apache2/sites-available";

#
# Get list of domains
#
my @DOMCONFS=`ls $SITESdir/$mydomain*.conf;`;

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
my $dompass;
my $templates;
my $LOGS;
my $LOGShtaccess;
my $procnt = 0;
my $found;
my $dirconf;
# LOOP
foreach my $domconf (@DOMCONFS) {
  $processed = 0;
  chomp($domconf);
  # See if document root exists
  if (!-e $domconf) {
    print "\nERROR: Virtual Host NOT FOUND: $domconf\n";
    next;
  }

  # Get the Domain Dir from DocumentRoot in apache conf
  $domdir = `grep -e'^[ \\t]*DocumentRoot' $domconf |sed -e's/^[ \\t]*DocumentRoot[ \\t]*//' -e's:/_WEB\$::' -e'/.*\\/var\\/www\\/html.*/d'`;
  chomp($domdir);
  next if ($domdir eq "");
  if (!-d $domdir) {
    print "\nERROR: Domain Dir ($domdir) does not exist\n";
    next;
  }

  # Get the ServerName from apache conf
  $servername = `grep -e'^[ \\t]*ServerName' $domconf|sed -e's/^[ \\t]*ServerName[ \\t]*//'`;
  chomp($servername);
  if ($servername eq "") {
    print "\nERROR: ServerName [$servername] NOT FOUND for $domconf\n";
    next;
  }

  print "==> Processing: $servername   ->   $domconf\n";

  #
  # Copy / Sync just the ACTIVATION templates
  #
  $templates = "$domdir/_ROOT/_TEMPLATES/";
  $out=`sudo cp -pruv $appdir/_TEMPLATES/ACTIVATION $templates;`;
  chomp($out);
  if ($out ne "") {
    $processed = 1;
    print "..Copy _TEMPLATES/ACTIVATION -> $domdir\n";
    print "$out\n";
  }
  
  #
  # Now copy other _TEMPLATES boilerplate oml (only if it doesn't exist)
  if (!-e "$templates/DEFAULT.oml") {
    $out = `sudo cp -puv $appdir/_TEMPLATES/DEFAULT.oml $templates;`;
    chomp($out);
    $processed = 1;
    print "$out\n";
  }
  #
  # EL_FN_SET_ROOT.oml
  if (!-e "$templates/EL_FN_SET_ROOT.oml") {
    $out = `sudo cp -puv $appdir/_TEMPLATES/EL_FN_SET_ROOT.oml $templates 2>&1;`;
    chomp($out);
    $processed = 1;
    print "$out\n";
  }
  #
  # EL_TOKENS.oml
  if (!-e "$templates/EL_TOKENS.oml") {
    $out = `sudo cp -puv $appdir/_TEMPLATES/EL_TOKENS.oml $templates 2>&1;`;
    chomp($out);
    $processed = 1;
    print "$out\n";
  }
  #
  # POL.oml - Proof of Life
  if (!-e "$templates/POL.oml") {
    $out = `sudo cp -puv $appdir/_TEMPLATES/POL.oml $templates 2>&1;`;
    chomp($out);
    $processed = 1;
    print "$out\n";
  }
  #
  # _STYLES
  if (!-d "$templates/_STYLES") {
    $out = `sudo cp -pruv $appdir/_TEMPLATES/_STYLES $templates 2>&1;`;
    chomp($out);
    $processed = 1;
    print "$out\n";
  }

  # Set ownership to www-data and group write permissions
  if ($processed eq "1") {
    `sudo chown -R www-data:www-data $templates;`;
    `sudo chmod -R g+w $templates;`;
  }

  #
  # Put the LOGS files under _WEB/DOWN/LOGS with password control
  #
  `sudo mkdir -v "$domdir/_WEB/DOWN" 2>/dev/null` if (!-d "$domdir/_WEB/DOWN");
  $LOGS = "$domdir/_WEB/DOWN/LOGS";
  if (!-d "$LOGS") {
    print `sudo mkdir -v "$LOGS"`;
    print `sudo mkdir -v "$LOGS/ARCHIVES" 2>/dev/null`;
    print `sudo mkdir -v "$LOGS/CURRENT" 2>/dev/null`;
    print `sudo mkdir -v "$LOGS/SAMPLE" 2>/dev/null`;
    print `sudo chown -R www-data:www-data $domdir/_WEB/DOWN;`;
    print `sudo chmod -R g+w $domdir/_WEB/DOWN;`;
  }

  # Check for .htpasswd in domain root
  if (!-e "$domdir/.htpasswd") {
    $processed=1;
    # Default pass is uppercase domain name (first word)
    $dompass = uc($servername);
    $dompass =~ s:\..*$::g;  # Remove TLD
    $out=`sudo htpasswd -b -c $domdir/.htpasswd $servername $dompass 2>&1;`;
    chomp($out);
    print "$out\n";
    `sudo chown www-data:www-data $domdir/.htpasswd;`;
    `sudo chmod g+w $domdir/.htpasswd;`;
  }
  
  # Check for .htaccess in _WEB/DOWN/LOGS
  $LOGShtaccess = "$LOGS/.htaccess";
  if (!-e $LOGShtaccess) {
    $processed=1;
    $out=`sed -e's/#DOM#/$servername/' -e's:#DOMAIN_DIR#:$domdir:' $appdir/CONFIG/htaccess.template >/tmp/$servername.htaccess;`;
    $out=`sudo mv -v /tmp/$servername.htaccess $LOGShtaccess;`;
    chomp($out);
    print "$out\n";
    `sudo chown www-data:www-data $LOGShtaccess;`;
    `sudo chmod g+w $LOGShtaccess;`;
    # SELinux (Fedora/RHEL): file was built in /tmp - restore the label
    # so Apache is allowed to read it (no-op on Debian/Ubuntu)
    `sudo /usr/sbin/restorecon -F $LOGShtaccess;` if (-x "/usr/sbin/restorecon");
  }

  #
  # Link the active log to CURRENT directory
  #
  # Check for links to LOGS/CURRENT and create if necessary
  # NOTE: LOGS/ARCHIVES is updated during log rotations
  # Use pipelogsplit to create CURRENT logs for domains
  #if (!-l "$LOGS/CURRENT/access.log") {
  #  $processed=1;
  #  print "..Creating $LOGS/CURRENT symbolic links for logs\n";
  #  print `sudo ln -vs $domdir/_LOGS/access.log $LOGS/CURRENT/;`;
  #  print `sudo ln -vs $domdir/_LOGS/accessBOT.log $LOGS/CURRENT/;`;
  #  print `sudo ln -vs $domdir/_LOGS/accessHACK.log $LOGS/CURRENT/;`;
  #  print `sudo ln -vs $domdir/_LOGS/error.log $LOGS/CURRENT/;`;
  #}

  #
  # Add the Directory directive (htaccess.conf) to virtual host
  #
  $found = `grep -e'_WEB/DOWN/LOGS' $domconf;`;
  chomp($found);
  if ($found eq "") {
    $processed=1;
    print "..Adding security for _WEB/DOWN/LOGS to $domconf\n";
    $dirconf = `sed -e's:#DOMAIN_DIR#:$domdir:' $appdir/CONFIG/htaccess.conf;`;
    chomp($dirconf);
    $dirconf =~ s/\n/\\n/g;
    $out = `sudo sed -i -e's:</VirtualHost>:$dirconf\\n</VirtualHost>:' $domconf;`;
    print $out;
  }

  # Increase processed count for total after loop
  $procnt++ if ($processed);

} #foreach $domconf

print "\nProcessed: $procnt\n\n";

exit 1;

# Show Usage
sub ShowUsage {
  print "\ninstallACTIVATION.pl \"<domain>\"\n\n";
  print "  <domain> - specific domain name virtual host, or wildcard (\"*\")\n\n";
  exit 0;
}

