#!/bin/perl
#
# RMSITE.pl <domainname>
# - Remove a domain name configuration files (HTTP & SSL), domain directory, and lets-encrypt references
#
use strict;
use warnings;

my $rmsite=shift;

if (!defined($rmsite) || $rmsite =~ /\*/ || $rmsite eq "") {
  print "RMSITE.pl <domainname>\n";
  print " - Remove a domain name configuration files (HTTP & SSL), domain directory, and lets-encrypt references\n";
  exit 1
}

# Make sure
if (!-e "/etc/apache2/sites-available/$rmsite.conf") {
  print "ERROR: /etc/apache2/sites-available/$rmsite.conf Not Found!\n";
  exit 1;
}

#
# Disable site first
#
print "\n-1- Disable HTTP site first\n";
`sudo a2dissite $rmsite;`;
`sudo a2dissite $rmsite-le-ssl;`;

# Get the domain dir
my $domroot = `grep DocumentRoot /etc/apache2/sites-available/$rmsite.conf|sed -e's/[ \t]*DocumentRoot[ \t]*//' -e's:/_WEB::';`;
chomp($domroot);
print "domroot: $domroot\n";

#
# Remove the apache document root and domain directory
#
if (-d $domroot) {
  print "-2- Remove the apache document root and domain directory\n";
  print `sudo rm -rv $domroot | tail;`;
}

#
# Remove apache vhost configuration files
#
print "-3- Remove Apache vhost configuration files\n";
print `sudo rm -v /etc/apache2/sites-available/$rmsite-le-ssl.conf;`;
print `sudo rm -v /etc/apache2/sites-available/$rmsite.conf;`;

# Remove letsencrypt renewal files
if (-e "/etc/letsencrypt/renewal/$rmsite.conf") {
  print "-4- Remove letsencrypt renewal files\n";
  print `sudo rm -v /etc/letsencrypt/renewal/$rmsite.conf;`;
  print `sudo rm -rv /etc/letsencrypt/live/$rmsite.conf;`;
  print `sudo rm -rv /etc/letsencrypt/archive/$rmsite.conf;`;
}

# Reload apache
print `sudo systemctl reload apache2`;

exit 1;
