#!/bin/perl
# fixcertbotconf.pl - switch from apache to webroot authentication in certbot
#                   - fixes slow speed for hundreds of domains
# 12.10.2024 oK created
use strict;
use warnings;

#
# Get all certbot renewal configurations
#
my @CERTS=`ls /etc/letsencrypt/renewal/*.conf`;
my $apacheconf;
my $webroot;
my @DOMS; # Domain ServerName / ServerAlias array
my $dom;
my $dom_webroots;
my $apacheauth;

foreach my $cert (@CERTS) {
  chomp($cert);
  
  $apacheauth=`grep -c -e'authenticator = apache' $cert;`;
  chomp($apacheauth);

  # next loop if authenticator = apache is not found
  next if (!$apacheauth);

  #
  # Get the Apache Configuration File
  #
  $apacheconf=$cert;
  $apacheconf =~ s:^.*/:/etc/apache2/sites-available/:;

  # Get the DocumentRoot - webroot
  $webroot=`grep "^[ \\t]*DocumentRoot" $apacheconf|sed -e's/^[ \\t]*DocumentRoot[ \\t]*//';`;
  chomp($webroot);

  # Get the Domain name
  @DOMS=`grep -e'^[ \\t]*ServerName' -e'^[ \\t]*ServerAlias' $apacheconf|sed -e's/[ \\t]*ServerName[ \\t]*//' -e's/[ \\t]*ServerAlias[ \\t]*//';`;

  $dom_webroots="";
  # Loop through @DOMS array and add webroot to for appending to letsencrypt .conf file
  foreach $dom (@DOMS) {
    chomp($dom);
    $dom_webroots .= "$dom = $webroot\\n";
  }

  # Processing
  print "\n-- PROCESSING: cert-apache-webroot: $cert\n\n";

  #print "sudo sed $cert -e's/authenticator = apache/authenticator = webroot/' -e's:= ecdsa:= ecdsa\\n[[webroot_map]]\\n$dom_webroots:';"."\n";
  print `sudo sed -i $cert -e's/authenticator = apache/authenticator = webroot/' -e'/installer = apache/d' -e's:= ecdsa:= ecdsa\\n[[webroot_map]]\\n$dom_webroots:';`."\n";
  print `grep -e"webroot" -e"LOVE" $cert;`;

}

exit 1;
