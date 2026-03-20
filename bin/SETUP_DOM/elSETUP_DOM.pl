#!/bin/perl
################################################
# elSETUP_DOMv2.pl <domainname> [domgroup] [1/0-certbot_install] [Alt-LOVE-root] [source-domain-dir]
#
#   - Setup WEB domain under /LOVE root
#
#   <domainname> = domainname to setup
#   [domgroup]   = (optional) EARTH LAND LIFE LOVE ECO 101 DIG FOOD RUNCHERO
#                  (ex: /LOVE/EARTH/<domain>
#                  domgroup will be set by default based on domain name if not specified
#   [1/0-certbot_install] - Default: 1 - install certbot; if 0, don't run certbot
#   [Alt-LOVE-root]       - Default /LOVE - Alternate root for all Domain Directories
#   [source-domain-dir]   - Optional source domain directory that includes _WEB data to import
#   Optional params can be provided in any order.
#
# 12.10.24 oK - created
# 03.20.26 AI - v2: optional source domain directory import support
use strict;
use warnings;
use File::Spec;

my $dom = shift @ARGV;
my $domgroup;
my $certbotinstall;
my $LOVEdir;
my $sourceDomainDir;
my $domroot="";
my $webroot;
my $apacheRELOAD=0;
my $certbot;
my $DomainConfig;
my $DomainROOTConfig;
my $DomainDir = "";
my $removeAliasWWW="";
my $sourceIsWebRoot=0;

#
# Parse optional params in any order:
# [domgroup] [1/0-certbot_install] [Alt-LOVE-root] [source-domain-dir]
#
# Rules:
# - 0/1 => certbot flag
# - Absolute existing path with _WEB (or containing _WEB) => source domain dir
# - Otherwise first absolute existing path => LOVE root dir
# - First unmatched non-path token => domgroup
#
my @unknownArgs=();
foreach my $arg (@ARGV) {
  next if (!defined($arg) || $arg eq "");

  if (!defined($certbotinstall) && $arg =~ /^(0|1)$/) {
    $certbotinstall = $arg;
    next;
  }

  if ($arg =~ m{^/} && -d $arg) {
    if (!defined($sourceDomainDir)
       && ($arg =~ m{/_WEB/?$} || -d "$arg/_WEB")) {
      $sourceDomainDir = $arg;
      next;
    }

    if (!defined($LOVEdir)) {
      $LOVEdir = $arg;
      next;
    }

    if (!defined($sourceDomainDir)) {
      $sourceDomainDir = $arg;
      next;
    }
  }

  if (!defined($domgroup)) {
    $domgroup = $arg;
    next;
  }

  push(@unknownArgs, $arg);
}

if (@unknownArgs) {
  print "\nERROR: Unrecognized extra parameters: @unknownArgs\n";
  ShowUsage();
}

# Default LOVE root (/LOVE) for all Domain Directories
$LOVEdir="/LOVE" if (!defined($LOVEdir) || $LOVEdir eq "");

# Check for valid LOVE root directory
if (!-d $LOVEdir) {
  print "\nERROR: LOVE root directory does not exist: $LOVEdir\n";
  ShowUsage();
}

# Make sure LOVE root starts with / - absolute path
if (!($LOVEdir =~ /^\//)) {
  print "\nERROR: Not an absolute LOVE root directory - must start with \"/\": $LOVEdir\n";
  ShowUsage();
}

#
# Check for valid source domain directory (optional)
# Must be either:
# 1) a domain root that contains _WEB, or
# 2) an _WEB directory directly
#
if (defined($sourceDomainDir) && $sourceDomainDir ne "") {
  if (!-d $sourceDomainDir) {
    print "\nERROR: Source domain directory does not exist: $sourceDomainDir\n";
    ShowUsage();
  }

  if ($sourceDomainDir =~ m{/_WEB/?$}) {
    $sourceIsWebRoot = 1;
  } elsif (!-d "$sourceDomainDir/_WEB") {
    print "\nERROR: Source directory is not a valid web domain directory.\n";
    print "It must be a directory that has _WEB in it (as _WEB itself or as a child dir).\n";
    print "Provided: $sourceDomainDir\n";
    ShowUsage();
  }
}

#
# Check for minimum input
#
if (!defined($dom) || $dom eq "") {
  print "\nERROR: No Domain specified\n";
  ShowUsage();
}
if ($dom =~ /[?\*]/) {
  print "\nERROR: Wildcards now allowed for Domain in elSETUP_DOMv2.pl\n";
  ShowUsage();
}

#
# Check for valid domain in DNS
#
my $dns=`dig +short $dom;`;
chomp($dns);
if ($dns eq "") {
  print "\nERROR: No DNS record found for $dom\n";
  print "Enter 'y' to continue anyways\n";
  my $yes = <STDIN>;
  chomp($yes);
  ShowUsage() if ($yes ne "y");
}

$certbotinstall = 1 if (!defined($certbotinstall) || $certbotinstall eq "" || $certbotinstall ne "0");

#
# Get the application directory
#
my ($volume, $appdir, $file) = File::Spec->splitpath(__FILE__);
$appdir =~ s/.$// if ($appdir =~ /.*\/$/);  # Remove Trailing / if present

#
# UpperCase domgroup if specified
#
$domgroup = uc($domgroup) if (defined($domgroup) && $domgroup ne "");

#
# LowerCase domain name for standard
#
$dom = lc($dom);

#
# Set the domain root - take off s1-s7 prefix if specified
#
$domroot = $dom;
$domroot =~ s/^s[0-9]\.//;

#
# Check for s1-7 or any subdomain
# to remove "Alias www." line
#
if ($dom =~ /^s[0-9]\..*/ || $dom =~ /.*\..*\..*/) {
  $removeAliasWWW = "-e'/Alias www./d' -e'/RewriteCond.*=www./d'";
}

#
# Build the Apache Virtual Host .conf file: /etc/apache2/sites-available
#
# Use DOMS.earth.conf as Templates (switch out domain)
#
$DomainROOTConfig = "/etc/apache2/sites-available/$domroot.conf";
$DomainConfig = "/etc/apache2/sites-available/$dom.conf";
if (-e "$DomainConfig") {
  print "==> $dom.conf already exists!\n";

  # Get DocumentRoot from /etc/apache2/sites-available
  $DomainDir = `grep -ie "^[ \t]*DocumentRoot" $DomainConfig`;
  chomp($DomainDir);
  $DomainDir =~ s/^[ \t]*DocumentRoot[ \t]*//;  # Remove DocumentRoot from string
  $DomainDir =~ s/\/_WEB$//;    # Remove /_WEB from end of string

  #
  # Get existing LOVEdir from path
  #
  $LOVEdir = $DomainDir;
  $LOVEdir =~ s:^/::;      # Remove leading / for now
  $LOVEdir =~ s:/.*::g;    # Remove rest of path to get LOVE root dir
  $LOVEdir = "/$LOVEdir";  # Replace leading /
  
  #
  # Get existing Domain Group from path: /LOVE/EARTH/domain.earth/
  #
  $domgroup = $DomainDir;
  $domgroup =~ s:$LOVEdir/::;  # Remove LOVEdir from path
  $domgroup =~ s:$domroot::;       # Remove domain root from path

} elsif (-e "$DomainROOTConfig") {
  # Domain ROOT Config found, so get config settings from base domain

  print "==> ROOTEXISTS: $domroot.conf exists - using preset values!\n";

  # Get DocumentRoot from /etc/apache2/sites-available
  $DomainDir = `grep -ie "^[ \t]*DocumentRoot" $DomainROOTConfig`;
  chomp($DomainDir);
  $DomainDir =~ s/^[ \t]*DocumentRoot[ \t]*//;  # Remove DocumentRoot from string
  $DomainDir =~ s/\/_WEB$//;    # Remove /_WEB from end of string

  #
  # Get existing LOVEdir from path
  #
  $LOVEdir = $DomainDir;
  $LOVEdir =~ s:^/::;      # Remove leading / for now
  $LOVEdir =~ s:/.*::g;    # Remove rest of path to get LOVE root dir
  $LOVEdir = "/$LOVEdir";  # Replace leading /
  
  #
  # Get existing Domain Group from path: /LOVE/EARTH/domain.earth/
  #
  $domgroup = $DomainDir;
  $domgroup =~ s:$LOVEdir/::;  # Remove LOVEdir from path
  $domgroup =~ s:$domroot::;       # Remove domain root from path

  #
  # Create new $dom.conf file from template
  #
  `sed -e"s:#DOMAIN#:$dom:g" -e"s:#DOMAINROOT#:$domroot:g" $removeAliasWWW -e"s:#DOMGROUP#:$LOVEdir/$domgroup:g" $appdir/CONFIG/DOMS.earth.conf >/tmp/$dom.conf;`;
  print `sudo mv -v /tmp/$dom.conf $DomainConfig;`;
  print `sudo chown www-data:www-data $DomainConfig;`;
  print `sudo chmod 664 $DomainConfig;`;

} else {
  # Create new Virtual Host config file /etc/apache/sites-available/$dom.conf file from template

  #
  # Get Default domgroup if not specified
  #
  if (!defined($domgroup) || $domgroup eq "") {
    #
    # Get Deployment Group based on Domain name
    #
    # Default to EARTH first
    $domgroup = "EARTH";
    $domgroup = "ECO"      if ($dom =~ /eco/i);
    $domgroup = "FOOD"     if ($dom =~ /food/i   && $domgroup eq "EARTH");
    $domgroup = "DIG"      if ($dom =~ /dig/i    && $domgroup eq "EARTH");
    $domgroup = "101"      if ($dom =~ /1.1/i    && $domgroup eq "EARTH");
    $domgroup = "LAND"     if ($dom =~ /\.land/i && $domgroup eq "EARTH");
    $domgroup = "LIFE"     if ($dom =~ /\.life/i && $domgroup eq "EARTH");
    $domgroup = "LOVE"     if ($dom =~ /\.love/i && $domgroup eq "EARTH");
    $domgroup = "LEGACY"   if ($dom =~ /\.net/i  && $domgroup eq "EARTH");
    $domgroup = "LEGACY"   if ($dom =~ /\.com/i  && $domgroup eq "EARTH");
    $domgroup = "LEGACY"   if ($dom =~ /\.org/i  && $domgroup eq "EARTH");
    $domgroup = "RUNCHERO" if ($dom =~ /runch/i);
  }

  #
  # Check for valid Domain Group
  #
  if ( $domgroup =~ /EARTH/
     ||$domgroup =~ /ECO/
     ||$domgroup =~ /FOOD/
     ||$domgroup =~ /DIG/
     ||$domgroup =~ /101/
     ||$domgroup =~ /LAND/
     ||$domgroup =~ /LIFE/
     ||$domgroup =~ /LOVE/
     ||$domgroup =~ /LEGACY/
     ||$domgroup =~ /RUNCHERO/
     ) {
    # Append / to end of domgroup
    $domgroup .= '/';
  } else {
    print "\nDomain Group not recognized: $domgroup\n";
    ShowUsage();
  }

  #
  # Create new $dom.conf file from template
  #
  `sed -e"s:#DOMAIN#:$dom:g" -e"s:#DOMAINROOT#:$domroot:g" $removeAliasWWW -e"s:#DOMGROUP#:$LOVEdir/$domgroup:g" $appdir/CONFIG/DOMS.earth.conf >/tmp/$dom.conf;`;
  print `sudo mv -v /tmp/$dom.conf $DomainConfig;`;
  print `sudo chown www-data:www-data $DomainConfig;`;
  print `sudo chmod 664 $DomainConfig;`;
}

#
# Set the Domain Directory based on LOVE root, Domain Group, and Domain Name
#
$DomainDir = "$LOVEdir/$domgroup$domroot" if ($DomainDir eq "");

#
# Define the webroot (DocumentRoot) for certbot below
#
$webroot="$DomainDir/_WEB";

print "\nPROCESSING: $dom - $webroot - $dns\n";

#
# Build the Domain Directories
#
print "Build $DomainDir directories\n" if (!-d "$DomainDir");

#
# Define directories to create
#
my @DIRS=(
  "$LOVEdir/$domgroup",
  "$DomainDir",
  "$DomainDir/_LOGS",
  "$DomainDir/_WEB",
  "$DomainDir/_WEB/DOWN",
  "$DomainDir/_WEB/UPS",
  "$DomainDir/_WEB/PATCHES",
  "$DomainDir/_WEB/RELEASE",
  "$DomainDir/_WEB/SITES",
  "$DomainDir/_WEB/_STYLES"
);

#
# Loop through each directory and make IT
#
foreach my $dir (@DIRS) {
  chomp($dir);
  # next if directory already exists
  next if (-d $dir);
  print "mkdir $dir\n";
  print `sudo mkdir $dir`;
  print `sudo chown www-data:www-data $dir;`;
  print `sudo chmod g+w $dir;`;
}

#
# If source domain data was provided, copy it into the new domain directory.
# If source is an _WEB directory, merge into target _WEB.
# Otherwise, merge source domain root into target domain root.
#
if (defined($sourceDomainDir) && $sourceDomainDir ne "") {
  if ($sourceIsWebRoot) {
    print "\nImport _WEB data: $sourceDomainDir -> $DomainDir/_WEB\n";
    print `sudo cp -pruv $sourceDomainDir/* $DomainDir/_WEB/;`;
  } else {
    print "\nImport domain data: $sourceDomainDir -> $DomainDir\n";
    print `sudo cp -pruv $sourceDomainDir/* $DomainDir/;`;
  }
}

#
# Create default index.html in Apache DocumentRoot
#
if (!-e "$DomainDir/_WEB/index.html") {
  print `sudo cp -puv $appdir/CONFIG/index.html $DomainDir/_WEB/;`;
}

#
# Create default robots.txt in Apache DocumentRoot
#
if (!-e "$DomainDir/_WEB/robots.txt") {
  print `sudo cp -puv $appdir/CONFIG/robots.txt $DomainDir/_WEB/;`;
}

#
# Copy the _STYLES to the new site DocumentRoot for static access
#
print `sudo cp -pruv $appdir/_TEMPLATES/_STYLES/* $DomainDir/_WEB/_STYLES/;`;

#
# Set permissions on the domain root
#
print `sudo chown -R www-data:www-data $DomainDir;`;
print `sudo chmod -R g+w               $DomainDir;`;

#
# Build the Orbit-Akashic _ROOT data structures
#
print `$appdir/elBUILD_root.pl $dom LANGS;`;

#
# Enable virtual host site (a2ensite) and reload Apache
# - only if NOT enabled in /etc/apache2/sites-enabled
#
if (!-e "/etc/apache2/sites-enabled/$dom.conf") {
  #print `cat $DomainConfig;`;
  #
  # Enable the virtual host in Apache
  #
  print `sudo a2ensite $dom.conf;`;
  $apacheRELOAD=1;
}

#
# Reload Apache if needed
#
if ($apacheRELOAD) {
  # Test apache config
  print "-- apachectl configtest\n";
  print `sudo apachectl configtest;`;

  print "-- systemctl reload apache2\n";
  print `sudo systemctl reload apache2;`;
  $apacheRELOAD=0;
}

#
# Enable SSL (HTTPS) for the site using certbot
# Use DOMS.earth-le-ssl.conf as Template
#
$DomainConfig = "/etc/apache2/sites-available/$dom-le-ssl.conf";
if (-e "$DomainConfig") {
  print "==> SSL: $dom-le-ssl.conf already exists!\n";
} elsif ($certbotinstall eq "1") {
  #
  # Run Certbot
  #
  # Check for s1-7
  if ($dom =~ /^s[0-9]\..*/) {
    print "sudo certbot certonly --non-interactive --agree-tos --webroot -w $webroot -d $dom;\n";
  } else {
    print "sudo certbot certonly --non-interactive --agree-tos --webroot -w $webroot -d $dom -d www.$dom;\n";
  }
  my $retry=1;
  while ($retry) {
    $retry=0;
    # Over 300 new orders per 3 hours causes exception - retry if so
    # Buffer output
    if ($dom =~ /^s[0-9]\..*/) {
      $certbot=`sudo certbot certonly --non-interactive --agree-tos --webroot -w $webroot -d $dom 2>&1;`."\n";
    } else {
      $certbot=`sudo certbot certonly --non-interactive --agree-tos --webroot -w $webroot -d $dom -d www.$dom 2>&1;`."\n";
    }
    # Show output
    print $certbot;
    # Only retry if "too many new orders"
    if ($certbot =~ /.*too many new orders.*/) {
      print "Sleeping for 60 seconds and retry";
      sleep(15); print "  .";
      sleep(15); print "   .";
      sleep(15); print "    .";
      sleep(15); print "     .\n\n";
      $retry=1;
    }
  }

  #
  # Create the SSL Apache .conf file
  #
  # Make sure certificates were created and a rewewal record created for certbot
  if (-e "/etc/letsencrypt/renewal/$dom.conf") {
    `sed -e"s:#DOMAIN#:$dom:g" -e"s:#DOMAINROOT#:$domroot:g" $removeAliasWWW -e"s:#DOMGROUP#:$LOVEdir/$domgroup:g" $appdir/CONFIG/DOMS.earth-le-ssl.conf >/tmp/$dom-le-ssl.conf;`;
    print `sudo mv -v /tmp/$dom-le-ssl.conf $DomainConfig;`;
    print `sudo chown www-data:www-data $DomainConfig;`;
    print `sudo chmod 664 $DomainConfig;`;

    #
    # Enable the SSL site only if certbot was successful
    #
    if (  -e "$DomainConfig"
       && -e "/etc/apache2/sites-enabled/$dom-le-ssl.conf") {
      print "==> SSL: $dom-le-ssl.conf already enabled!\n";
    } else {
      #
      # Enable the virtual host in Apache for SSL
      #
      print `sudo a2ensite $dom-le-ssl.conf;`;
      $apacheRELOAD=1;
    }

  } else {
    my $STAMP = `date +%Y%m%d;`;
    my $STAMPTIME = `date +%Y%m%d_%H%M%S`;
    chomp($STAMP);
    chomp($STAMPTIME);
    print "\n==> $STAMPTIME ERROR: certbot FAILED for $dom!\n\n";
    `echo "==> $STAMPTIME ERROR: certbot FAILED for $dom!" >>CERTBOT_$STAMP.ERR;`;
  }
}

#
# Install the ACTIVATION ROOTWORD _TEMPLATES
#
print `$appdir/installACTIVATION.pl $dom;`;

#
# Reload Apache if needed
#
if ($apacheRELOAD) {
  # Test apache config
  print "-- apachectl configtest\n";
  print `sudo apachectl configtest;`;

  print "-- systemctl reload apache2\n";
  print `sudo systemctl reload apache2;`;
}

exit 0;

#
# ShowUsage
#
sub ShowUsage {
  print "\nelSETUP_DOMv2.pl <domainname>  [domgroup]  [1/0-certbot_install] [Alt-LOVE-root] [source-domain-dir]\n\n";

  print "  - Setup WEB domain under /LOVE root\n\n";
  
  print "  <domainname> = domainname to setup\n";
  print "  [domgroup]   = (optional) EARTH LAND LIFE LOVE ECO 101 DIG FOOD RUNCHERO\n";
  print "                 (ex: /LOVE/EARTH/<domain>\n";
  print "                 domgroup will be set by default based on domain name if not specified\n";
  print "  [1/0-certbot_install] - Default: 1 - install certbot; if 0, don't run certbot\n";
  print "  [Alt-LOVE-root]       - Default /LOVE - Alternate root for all Domain Directories\n";
  print "  [source-domain-dir]   - Optional directory with _WEB in it; contents copied into <domainname> directory\n";
  print "  Optional parameters may be passed in any order after <domainname>.\n\n";

  exit 1;
}

