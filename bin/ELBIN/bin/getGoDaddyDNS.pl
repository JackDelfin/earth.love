#!/usr/bin/perl
# Version 1.0.0.0      23-Nov-2024
#*******************************************************************************
#
# getGoDaddyDNS.pl   <Web_Domain>
#
# Purpose:
#   Get the domain DNS A records and forwarding information from GoDaddy
#
#   This calls the GoDaddy API with specific customerID in UUIDv4 format
#   and API key:secret retrieved from developer.godaddy.com - API Keys.
#
#   ex)
#       perl getGoDaddyDNS.pl   vegas.earth
#
# Parameters:
#   <Web_Domain>
#     - Domain DNS to be changed
#
# History:
#   2024.11.23 earth.love oK Created
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
use utf8;
use feature ':5.16';
use JSON::MaybeXS qw(decode_json encode_json);

my $Domain = shift;

# Initialize variables
$Domain = "" if (!defined($Domain));

#
# TEST
#my $GoDaddyAPI = 'https://api.ote-godaddy.com';  # TEST - OTE
#
# PRODUCTION
my $GoDaddyAPI = 'https://api.godaddy.com';  # Production
#
my $key_secret = $ENV{'gdkey_secret'};
my $customerID = $ENV{'gdcustomerid'};

#
# Check for Domain Directory as input
#
if ($key_secret eq "" || $customerID eq "") {
  print "\nERROR: Environment variables gdcustomerid and gdkey_secret must be set!\n";
  print "-----------------------\n";
  print "  source setkey.sh\n";
  print "-----------------------\n\n";
  BuildUsage();
}

#
# Check for Domain Directory as input
#
if ($Domain eq "") {
  print "ERROR: The Domain Name must be specified as parameter!\n";
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
#my $A = Akashic->new(1);

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
#my $startdate = localtime();
#my $starttime = time();
#print "Build Start: $startdate\n";

#print "############################################################\n";

#*****************************************
#*****************************************
#*****************************************

print "\n>>> ".$Domain." <<<\n";
#
# Get the fowarding information
#
my $forwards = GetFowarding($Domain);
print 'Forwarding: '.$forwards."\n\n" if ($forwards ne '' && !($forwards =~ /NOT_FOUND/));

my $DNSrecords = GetDNS_A_records($Domain, '');
print 'DNS A records: '.$DNSrecords."\n";

$DNSrecords = GetDNS_CNAME_records($Domain, '');
print 'DNS CNAME records: '.$DNSrecords."\n";

#*****************************************
#*****************************************
#*****************************************

# Show End Times
#my $enddate = localtime();
#my $endtime = time();
#my $HMS     = $A->TimeDiffHMS($starttime, $endtime);
#print "\n--------------------------------------------------\n";
#print "Build Root Start:  $startdate\n";
#print "Build Root End  :  $enddate\n";
#print "--------------------------------------------------\n";
#print "TIME : $HMS\n";
#print "--------------------------------------------------\n";

#print "############################################################\n";

exit 0;


################################################################################
# NETCurl  <url>  [GET/POST/DELETE/PATCH]  [PostFields]
################################################################################
sub NETCurl
{
  use Net::Curl::Easy qw(:constants);

  my $url = shift;
  my $reqtype = shift;
  $reqtype = 'GET' if (!defined($reqtype) || $reqtype eq '');
  my $postfields = shift;
  $postfields = "" if (!defined($postfields));
  
  my $easy = Net::Curl::Easy->new();
  my $response="";

  $easy->setopt( CURLOPT_URL, $url );
  $easy->setopt( CURLOPT_VERBOSE, 0 );
  $easy->setopt( CURLOPT_FOLLOWLOCATION, 1 );
  $easy->setopt( CURLOPT_CUSTOMREQUEST, $reqtype );
  $easy->setopt( CURLOPT_WRITEDATA, \$response );
  $easy->pushopt( CURLOPT_HTTPHEADER, ['Content-Type: application/json'] );
  $easy->pushopt( CURLOPT_HTTPHEADER, ['Accept: application/json'] );
  $easy->pushopt( CURLOPT_HTTPHEADER, ['Accept-Charset: UTF-8'] );
  $easy->pushopt( CURLOPT_HTTPHEADER, ['Authorization: sso-key '.$key_secret] );
  #$easy->setopt( CURLOPT_USERAGENT, "MyBrowser v0.1" );
  #$easy->setopt( CURLOPT_COOKIEFILE, "" ); # enable cookie session
  #$easy->setopt( CURLOPT_REFERER, 'http://earth.love' );

  $easy->setopt( CURLOPT_POSTFIELDS, $postfields) if ($postfields ne "");

  # Execute the curl
  $easy->perform();

  return $response;
} #NETCurl


################################################################################
# IsDomainAvail - See if Domain is available
################################################################################
sub IsDomainAvail
{
  my $DomainName = shift;

  my $url = $GoDaddyAPI.'/v1/domains/available?domain='.$DomainName.'&checkType=FAST&forTransfer=false';

  # Do the curl
  my $reply = NETCurl($url, 'GET');

  # Decode the response in JSON
  my $decoded_json = decode_json( $reply );

  # Referencable Fields
  #print $decoded_json->{available}; #1/0
  #print $decoded_json->{definitive}; #1/0
  #print $decoded_json->{domain};

  return $decoded_json->{available}; # Return 0/1 Boolean
} #IsDomainAvail

################################################################################
# GetFowarding - Get forwarding information for the Domain
################################################################################
sub GetFowarding
{
  my $DomainName = shift;

  my $url = $GoDaddyAPI.'/v2/customers/'.$customerID.'/domains/forwards/'.$DomainName;

  # Do the curl
  my $reply = NETCurl($url, 'GET');

  # Decode the response in JSON
  my $decoded_json = decode_json( $reply );

  # Referencable Fields
  # SUCCESS
  #print $decoded_json->{fqdn}; #domain.tld
  #print $decoded_json->{mask}; #{title,description,keywords}
  #print $decoded_json->{type}; #PERMANENT_REDIRECT
  #print $decoded_json->{url}; #forwarded url
  # ON ERROR
  #print $decoded_json->{code}; #NOT_FOUND
  #print $decoded_json->{message}; #Not Found : The requested resource was not found

  my $response = "";

  # Add the results together for multiple rows
  if ($reply =~ /"code":/) {
    $response = $decoded_json->{code}.": ".$decoded_json->{message};
  } elsif ($reply =~ /"fqdn":/) {
    foreach (@{ $decoded_json }) {
      $response .= ' ' if ($response ne '');
      $response .= $_->{fqdn}." -> ".$_->{url};
    }
  }
  
  return $response;
} #GetForwarding


################################################################################
# GetDNS_A_records <DomainName> [@/s1/s2] - Gets the "A" DNS RecordS for Domain
################################################################################
sub GetDNS_A_records
{
  my $DomainName = shift;
  my $ARecName = shift;
  $ARecName = '' if (!defined($ARecName));
  $ARecName = '%40' if ($ARecName eq '@');
  
  my $url = $GoDaddyAPI.'/v1/domains/'.$DomainName.'/records/A/'.$ARecName;

  # Do the curl
  my $reply = NETCurl($url, 'GET');

  # Decode the response in JSON
  my $decoded_json = decode_json( $reply );

  # Referencable Fields
  # SUCCESS
  #print $decoded_json->{data}; #127.0.0.1
  #print $decoded_json->{name}; #@
  #print $decoded_json->{ttl};  #3600
  #print $decoded_json->{type}; #A
  # ON ERROR
  #print $decoded_json->{code}; #UNKNOWN_DOMAIN
  #print $decoded_json->{message}; #The given domain is not registered, or does not have a zone file

  my $response = "";

  # Add the results together for multiple rows
  if ($reply =~ /"code":/) {
    $response = $decoded_json->{code}.": ".$decoded_json->{message};
  } elsif ($reply =~ /"data":/) {
    foreach (@{ $decoded_json }) {
      $response .= ' ' if ($response ne '');
      $response .= $_->{name}.":".$_->{data};
    }
  }
  
  return $response;
} #GetDNS_A_records


################################################################################
# GetDNS_CNAME_records <DomainName> [subdomain] - Gets the "CNAME" DNS RecordS for Domain
################################################################################
sub GetDNS_CNAME_records
{
  my $DomainName = shift;
  my $ARecName = shift;
  $ARecName = '' if (!defined($ARecName));
  $ARecName = '%40' if ($ARecName eq '@');
  
  my $url = $GoDaddyAPI.'/v1/domains/'.$DomainName.'/records/CNAME/'.$ARecName;

  # Do the curl
  my $reply = NETCurl($url, 'GET');

  # Decode the response in JSON
  my $decoded_json = decode_json( $reply );

  # Referencable Fields
  # SUCCESS
  #print $decoded_json->{data}; #127.0.0.1
  #print $decoded_json->{name}; #@
  #print $decoded_json->{ttl};  #3600
  #print $decoded_json->{type}; #CNAME
  # ON ERROR
  #print $decoded_json->{code}; #UNKNOWN_DOMAIN
  #print $decoded_json->{message}; #The given domain is not registered, or does not have a zone file

  my $response = "";

  # Add the results together for multiple rows
  if ($reply =~ /"code":/) {
    $response = $decoded_json->{code}.": ".$decoded_json->{message};
  } elsif ($reply =~ /"data":/) {
    foreach (@{ $decoded_json }) {
      $response .= ' ' if ($response ne '');
      $response .= $_->{name}.":".$_->{data};
    }
  }
  
  return $response;
} #GetDNS_CNAME_records


################################################################################
# BuildUsage - Show usage information
################################################################################
sub BuildUsage
{
  print "\nUsage: $0   <Web_Domain>\n\n";

  print " Purpose:\n";
  print "   Get the domain DNS A records and forwarding information from GoDaddy\n\n";

  print "   This calls the GoDaddy API with specific customerID in UUIDv4 format\n";
  print "   and API key:secret retrieved from developer.godaddy.com - API Keys.\n\n";

  print "   ex)\n";
  print "       perl setGoDaddyDNS.pl   vegas.earth\n";
 
  print " Parameters:\n";
  print "   <Web_Domain>\n";
  print "     - Domain DNS to be changed\n";

  exit 1;
}
