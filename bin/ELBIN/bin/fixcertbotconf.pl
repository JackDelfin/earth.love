#!/bin/perl
# fixcertbotconf.pl - switch from apache to webroot authentication in certbot
#                   - fixes slow speed for hundreds of domains
#
# 12.10.2024 oK created
use strict;
use warnings;

#
# Get all certbot renewal configurations
#
my @CERTS=`ls /etc/letsencrypt/renewal/*.conf`;
#my @CERTS=`ls /etc/letsencrypt/renewal/ann*dig.com.conf`;
my $apacheconf;
my $webroot;
my @DOMS; # Domain ServerName / ServerAlias array
my $dom;
my $dom_webroots;
my $apacheauth;
my $webrootsFOUND;
my $oldpathFOUND;

foreach my $cert (@CERTS) {
  chomp($cert);
  
  $apacheauth=`grep -c -e'authenticator = apache' $cert;`;
  chomp($apacheauth);

  #
  # Get the Apache Configuration File
  #
  $apacheconf=$cert;
  $apacheconf =~ s:^.*/:/etc/apache2/sites-available/:;
  
  # Make sure apache conf exists
  if (!-e $apacheconf) {
    print "CONF NOT FOUND: $apacheconf\n"; 
    next;
  }

  # Get the DocumentRoot - webroot
  $webroot=`grep "^[ \\t]*DocumentRoot" $apacheconf|sed -e's/^[ \\t]*DocumentRoot[ \\t]*//';`;
  chomp($webroot);

  # Get the Domain name
  @DOMS=`grep -e'^[ \\t]*ServerName' -e'^[ \\t]*ServerAlias' $apacheconf|sed -e's/[ \\t]*ServerName[ \\t]*//' -e's/[ \\t]*ServerAlias[ \\t]*//';`;

  # Look for webroot in cert file
  $webrootsFOUND=`grep -c -e"$webroot" $cert`;
  chomp($webrootsFOUND);
  
  # Look for old path webroot_path in cert file - redundant since we add [[webroot_map]]
  $oldpathFOUND = `grep -c -e"webroot_path = " $cert`;
  chomp($oldpathFOUND);

  #print "webrootsFOUND: $webrootsFOUND - $webroot - $cert \n"; #DEBUG TESTING

  #
  # next loop if authenticator = apache is not found AND webroots are the same
  #
  next if (!$apacheauth && $webrootsFOUND > 0 && $oldpathFOUND == 0);

  #
  # Build new webroots array for insertion
  #
  $dom_webroots="";
  # Loop through @DOMS array and add webroot to for appending to letsencrypt .conf file
  foreach $dom (@DOMS) {
    chomp($dom);
    $dom_webroots .= "\\n" if ($dom_webroots ne "");
    $dom_webroots .= "$dom = $webroot";
  }

  # Remove current webroots in webroot_map in case they changed
  # Loop through @DOMS array
  foreach $dom (@DOMS) {
    chomp($dom);
    `sudo sed -i -e'/webroot_path = /d' -e'/[[webroot_map]]/d' -e'/^$dom = /d' $cert`;
  }

  # Processing
  print "\n-- PROCESSING: cert-apache-webroot: $cert\n\n";

  #print "sudo sed $cert -e's/authenticator = apache/authenticator = webroot/' -e's:= ecdsa:= ecdsa\\n[[webroot_map]]\\n$dom_webroots:';"."\n";
  print `sudo sed -i $cert -e's/authenticator = apache/authenticator = webroot/' -e'/installer = apache/d' -e's:= ecdsa:= ecdsa\\n[[webroot_map]]\\n$dom_webroots:';`."\n";
  print `grep -e"webroot" -e"LOVE" $cert;`;

}

exit 1;

