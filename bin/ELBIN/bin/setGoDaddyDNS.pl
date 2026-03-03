#!/usr/bin/perl
# Version 1.0.0.0      23-Nov-2024
#*******************************************************************************
#
# setGoDaddyDNS.pl   <Web_Domain>   <IPv4_Address>   [SubDomain (s1-s77)]   [--FORCE]
#
# Purpose:
#   Set the domain name A record in DNS to point to the IP Address specified.
#
#   This calls the GoDaddy API with specific customerID in UUIDv4 format
#   and API key:secret retrieved from developer.godaddy.com - API Keys.
#
#   The SubDomain (s1-s77) optional parameter will create the subdomain A record.
#   ie) s1.vegas.earth
#
#   This supports the multi-server distributed WEB which keeps the data
#   in sync between the servers.
#
#   For s1 specifically, the "@" and "s1" A records will be created together
#   - If the "s1" A record subdomain does NOT exist, it will be created
#   - If "s1" exists and has a different IP Address, it will be ignored 
#     unless --FORCE is specified, in which case it will be replaced
#
#   The main "@" A record will never be replaced or deleted
#   unless --FORCE is specified.
#
#   NOTE: Any "forwarding" of the root domain name will also be DELETED
#         so the A records will now control DNS redirection
#
#   If "--FORCE" is specified as the 4th parameter, existing @ and SubDomain
#   records will be overridden if they already exist (delete and add new)
#
#   ex)
#       perl setGoDaddyDNS.pl   vegas.earth   99.6.104.130   s1
#       perl setGoDaddyDNS.pl   vegas.earth   99.6.104.130
#
#
# Parameters:
#   <Web_Domain>
#     - Domain DNS to be changed
#   <IPv4_Address>
#     - Traditional IP address: ex) 127.0.0.1
#   [s1-s77]
#     - Server SubDomain for Distributed WEB access
#   [--FORCE]
#     - Force new @ and s records
#
# History:
#   2024.12.21 earth.love oK Updated for s2-77 logic
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
my $IPAddr = shift;
my $SubDomain = shift;
my $FORCE = shift;

# Initialize variables
$Domain = "" if (!defined($Domain));
$IPAddr = "" if (!defined($IPAddr));
# Don't default subdomain - must be specified
$SubDomain = "" if (!defined($SubDomain));
$FORCE = 0 if (!defined($FORCE) || $FORCE eq "");
# Only set force if specified as uppercase "--FORCE"
$FORCE = 1 if ($FORCE eq "--FORCE");

# Lowercase subdomain
$SubDomain = lc($SubDomain) if ($SubDomain ne "");

# Check the --FORCE directive
if (!($FORCE =~ /[0-1]/)) {
  print "\nERROR: --FORCE directive improperly specified ($FORCE)!\n";
  BuildUsage();
}

#
# Check Domain and IP Addr Systax
#
if ($Domain eq "" || !($IPAddr =~ /(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/)) {
  print "\nError on IP Address: $IPAddr\n\n" if ($IPAddr ne "");
  print "\nERROR: The Domain Name and IP Address must be specified as parameters!\n" if ($Domain eq "");
  BuildUsage();
}

my $work = 0;

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

#
# See if Domain is Available
#
#print "IsDomainAvail: ".IsDomainAvail($Domain)."\n";

#print 'LWPCurl: '.LWPCurl('banks.earth')."\n\n";
#print 'NETCurl: '.NETCurl('banks.earth')."\n\n";

print "\n>>> ".$Domain." <<<\n";
#
# Get the forwarding information
#
my $forwards = GetForwarding($Domain);
print 'Existing Forwarding: '.$forwards."\n\n" if ($forwards ne '' && !($forwards =~ /NOT_FOUND/));

#
# Get DNS A Records BEFORE we do anything
#
my $DNSrecords = GetDNS_A_records($Domain, '');
print 'DNS A records: '.$DNSrecords."\n";

#
# Conditionally add @ DNS Record if it doesn't exist
# 12.21.24 Don't add if ANY "@" A record exists - unless forwarding is on
#          - Only create "@" A record if none exists
if (  !($DNSrecords =~ /.*\@:.*/)
   ||  ($DNSrecords =~ /.*\@:Parked/i)
   || !($forwards =~ /.*NOT_FOUND.*/)) {
  #
  # Delete @:Parked if it exists
  #
  if ($DNSrecords =~ /.*\@:Parked.*/i) {
    print 'DELETE DNS A rec: '.DeleteADNSRecord($Domain, '@')."\n";
  }

  #
  # Don't add @ if IP already exists - check for s1 SubDomain
  #
  if (!($DNSrecords =~ /.*\@:$IPAddr.*/)
     # 2025.1.6 - only create @ for s1 or blank SubDomain
     && (  $SubDomain eq "s1"
        || $SubDomain eq "")) {
    print 'Add DNS A record: '.AddADNSRecord($Domain, '@')."\n";
    $work = 1;
  }

  #
  # Add s1 record here if not specified as SubDomain and doesn't exist
  #
  if ( !($DNSrecords =~ /.*s1:.*/)
     && ($SubDomain eq "" || $SubDomain ne "s1")) {
    print 'Add s1 DNS A record: '.AddADNSRecord($Domain, 's1')."\n";
  }
} elsif ($FORCE) {
  #
  # Force the @ A record if directed (Delete existing and add New)
  #
  if (!($DNSrecords =~ /.*\@:$IPAddr.*/) || $DNSrecords =~ /.*\@:Parked.*/i) {
    #
    # Last check - only FORCE @ delete/add if "s1" SubDomain specified with --FORCE
    #
    if ($SubDomain eq "s1") {
      print 'DELETE DNS A rec: '.DeleteADNSRecord($Domain, '@')."\n";
      print 'Add DNS A record: '.AddADNSRecord($Domain, '@')."\n";
      $work = 1;
    }
  }
}

# Add s1 subdomain if it doesn't exist
$SubDomain = 's1' if ($SubDomain eq "" && !($DNSrecords =~ /.*s1:.*/));

#
# Conditionally add Subdomain DNS A Record if it doesn't exist
#if (!($DNSrecords =~ /s1:$IPAddr/) && $SubDomain eq 's1') {
# 12.21.24 Only add "s1-77" if @ A record exists or was just created with same IP Address
#          - don't create "s1" A record if IP Address doesn't match "@" A record
#
if ($SubDomain ne "") {
  # Check for SubDomain in existing list
  if (!($DNSrecords =~ /.*$SubDomain:.*/i)) {
    # NOT FOUND
    #
    # Add a Fresh subdomain record
    #
    print 'Add DNS A record: '.AddADNSRecord($Domain, $SubDomain)."\n";
    $work = 1;
  } elsif ($FORCE) {
    # FOUND - Check if same IP Address
    #
    # Force the s1 record - Delete current and Add new
    #
    if (!($DNSrecords =~ /.*$SubDomain:$IPAddr.*/)) {
      print 'DELETE DNS A rec: '.DeleteADNSRecord($Domain, $SubDomain)."\n";
      print 'Add DNS A record: '.AddADNSRecord($Domain, $SubDomain)."\n";
      $work = 1;
    }
  }
}

  #
  # Remove forwarding if present (from above)
  #
  if (!($forwards =~ /.*NOT_FOUND.*/)) {
    print 'Delete Forwarding: '.DeleteForwarding($Domain)."\n";
    # Check for: Delete Forwarding: INVALID_BODY: Forwarding Delete is not allowed for the domain
    $work = 1;
  }

#
# Only show DNS records again if work was done
#
# TESTING: Save the transaction for large runs
#if ($work == 1) {
#  print 'DNS A records: '.GetDNS_A_records($Domain, '')."\n";
#}

#
# Write the elSETUP_DOM.pl script output for IP Address
#
# Get Deployment Group based on Domain name
my $group = "EARTH";
$group = "ECO"    if ($Domain =~ /eco/i);
$group = "FOOD"   if ($Domain =~ /food/i     && $group eq "EARTH");
$group = "DIG"    if ($Domain =~ /dig/i      && $group eq "EARTH");
$group = "101"    if ($Domain =~ /1.1/i      && $group eq "EARTH");
$group = "LAND"   if ($Domain =~ /\.land/i   && $group eq "EARTH");
$group = "LIFE"   if ($Domain =~ /\.life/i   && $group eq "EARTH");
$group = "LOVE"   if ($Domain =~ /\.love/i   && $group eq "EARTH");
$group = "LEGACY" if ($Domain =~ /\.net/i    && $group eq "EARTH");
$group = "LEGACY" if ($Domain =~ /\.com/i    && $group eq "EARTH");
$group = "LEGACY" if ($Domain =~ /\.org/i    && $group eq "EARTH");
$group = "RUNCH"  if ($Domain =~ /runch/i    && $group eq "EARTH");

my $datestr = `date +%Y%m%d`;
chomp($datestr);
open(OUT, ">>".$IPAddr."_SETUP_DOM_".$datestr.".sh");
# Print Main domain Record
if ($SubDomain eq "s1" || $SubDomain eq "") {
  print OUT "./elSETUP_DOM.pl $Domain $group\n";
}
# Print Subdomain Record
if ($SubDomain ne "") {
  print OUT "./elSETUP_DOM.pl $SubDomain.$Domain $group\n";
}
close(OUT);

# Slow IT DOWN for GoDaddy
`sleep 1`;

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
# LWPCurl  <get_url>  [referer_url] - returns content
################################################################################
#sub LWPCurl
#{
#use LWP::Curl;
#  my $get_url = shift;
#  my $referer = shift;
#  $referer = "http://earth.love" if (!defined($referer) || $referer eq '');
#  my $lwpcurl = LWP::Curl->new();
#  my $content = $lwpcurl->get($get_url, $referer);
#  $content = "" if (!defined($content));
#  return $content;
#} #LWPCurl


################################################################################
# CheckQUOTA - Check response if Monthly Transaction Quota has been exceeded
#            - Look for string QUOTA_EXCEEDED and touch file: QUOTA_EXCEEDED
################################################################################
sub CheckQUOTA
{
  my $code = shift;
  return 0 if (!defined($code));
  #
  # Check return code for QUOTA_EXCEEDED
  #
  if ($code =~ /QUOTA_EXCEEDED/) {
    # Touch a file in current directory so we can stop processing in all scripts
    #`touch QUOTA_EXCEEDED;`;
    my $STAMP=`date +%Y%m%d_%H%M%S`;
    chomp($STAMP);
    open(ERR, ">> QUOTA_EXCEEDED");
    print ERR "$STAMP QUOTA_EXCEEDED: $Domain $IPAddr $SubDomain $FORCE\n";
    close(ERR);
    return 1;
  }
  
  #
  # Check return code for ERROR_INTERNAL
  #
  if ($code =~ /ERROR_INTERNAL/) {
    # Touch a file in current directory so we can stop processing in all scripts
    #`touch ERROR_INTERNAL;`;
    my $STAMP=`date +%Y%m%d_%H%M%S`;
    chomp($STAMP);
    open(ERR, ">> ERROR_INTERNAL");
    print ERR "$STAMP ERROR_INTERNAL: $Domain $IPAddr $SubDomain $FORCE\n";
    close(ERR);
    return 1;
  }
  return 0;
} #CheckQUOTA


################################################################################
# IsQUOTA_EXCEEDED - See if Monthly Transaction Quota has been exceeded
#                  - Look for file: QUOTA_EXCEEDED
################################################################################
sub IsQUOTA_EXCEEDED
{
  # STOP processing if QUOTA_EXCEEDED
  return 1 if (-e "QUOTA_EXCEEDED");
  # Also STOP processing and check status if ERROR_INTERNAL
  # Second thought - keep rolling
  # return 1 if (-e "ERROR_INTERNAL");
  return 0;
} #IsQUOTA_EXCEEDED


################################################################################
# IsDomainAvail - See if Domain is available
################################################################################
sub IsDomainAvail
{
  my $DomainName = shift;

  my $url = $GoDaddyAPI.'/v1/domains/available?domain='.$DomainName.'&checkType=FAST&forTransfer=false';

  # Check for Exceeded Quota for Transactions
  return -1 if (IsQUOTA_EXCEEDED());

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
# GetForwarding - Get forwarding information for the Domain
################################################################################
sub GetForwarding
{
  my $DomainName = shift;

  my $url = $GoDaddyAPI.'/v2/customers/'.$customerID.'/domains/forwards/'.$DomainName;

  # Check for Exceeded Quota for Transactions
  return "QUOTA_EXCEEDED" if (IsQUOTA_EXCEEDED());

  # Do the curl
  my $reply = NETCurl($url, 'GET');

  # Check of Monthly Transaction Quota has been exceeded
  CheckQUOTA($reply);

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
# DeleteForwarding - Remove forwarding in GoDaddy for the Domain
################################################################################
sub DeleteForwarding
{
  my $DomainName = shift;

# curl -X 'DELETE' \
#   'https://api.godaddy.com/v2/customers/'.$customerID.'/domains/forwards/vegas.earth' \
#   -H 'accept: application/json' \
#   -H 'Authorization: sso-key '.$key_secret

  my $url = $GoDaddyAPI.'/v2/customers/'.$customerID.'/domains/forwards/'.$DomainName;

  # Check for Exceeded Quota for Transactions
  return "QUOTA_EXCEEDED" if (IsQUOTA_EXCEEDED());

  # Do the curl
  my $reply = NETCurl($url, 'DELETE');

  # Check of Monthly Transaction Quota has been exceeded
  CheckQUOTA($reply);

  return "Forward Removed: $forwards" if ($reply eq '');

  # Decode the response in JSON
  my $decoded_json = decode_json( $reply );

  # Referencable Fields
  #print $decoded_json->{code}; #ERROR_INTERNAL
  #print $decoded_json->{message}; #Not Found : Failed to get customer data for customerId or shopperId

  # Check for: INVALID_BODY: Forwarding Delete is not allowed for the domain
  # - Verify Code email required to delete
  if ($reply =~ /INVALID_BODY/) {
    my $STAMP=`date +%Y%m%d_%H%M%S`;
    chomp($STAMP);
    open(ERR, ">> DELETE_FORWARDING_ERROR");
    print ERR "$STAMP ".$decoded_json->{code}.": $Domain $IPAddr $SubDomain $FORCE - ".$decoded_json->{message}."\n";
    close(ERR);
  }

  return $decoded_json->{code}.": ".$decoded_json->{message};
} #DeleteForwarding


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

  # Check for Exceeded Quota for Transactions
  return "QUOTA_EXCEEDED" if (IsQUOTA_EXCEEDED());

  # Do the curl
  my $reply = NETCurl($url, 'GET');

  # Check of Monthly Transaction Quota has been exceeded
  CheckQUOTA($reply);

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
    # Error Response
    $response = $decoded_json->{code}.": ".$decoded_json->{message};
  } elsif ($reply =~ /"data":/) {
    #
    # Success Response - multiple records perhaps
    #
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

  # Check for Exceeded Quota for Transactions
  return "QUOTA_EXCEEDED" if (IsQUOTA_EXCEEDED());

  # Do the curl
  my $reply = NETCurl($url, 'GET');

  # Check of Monthly Transaction Quota has been exceeded
  CheckQUOTA($reply);

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
# AddADNSRecord - Add an "A" DNS Record for Domain
################################################################################
sub AddADNSRecord
{
  my $DomainName = shift;
  my $Sub = shift;
  $Sub = '@' if (!defined($Sub) || $Sub eq '');

  my $url = $GoDaddyAPI.'/v1/domains/'.$DomainName.'/records';

  my $data = '[
  {
    "data": "'.$IPAddr.'",
    "name": "'.$Sub.'",
    "port": 80,
    "priority": 0,
    "protocol": "string",
    "service": "string",
    "ttl": 600,
    "type": "A",
    "weight": 0
  }
  ]';

  # Check for Exceeded Quota for Transactions
  return "QUOTA_EXCEEDED" if (IsQUOTA_EXCEEDED());

  # Do the curl
  my $reply = NETCurl($url, 'PATCH', $data);

  # Check of Monthly Transaction Quota has been exceeded
  CheckQUOTA($reply);

  return "$Sub -> $IPAddr Success" if ($reply eq '');
  
  # Decode the response in JSON
  my $decoded_json = decode_json( $reply );

  # Referencable Fields
  #print $decoded_json->{code}; #UNKNOWN_DOMAIN
  #print $decoded_json->{message}; #The given domain is not registered, or does not have a zone file

  return $decoded_json->{code}.": ".$decoded_json->{message};

} #AddADNSRecord


################################################################################
# DeleteADNSRecord - Delete an "A" DNS Record for Domain
################################################################################
sub DeleteADNSRecord
{
  my $DomainName = shift;
  my $Sub = shift;
  $Sub = '' if (!defined($Sub) || $Sub eq '');

  # Must have a subdomain specified to Delete
  if ($Sub eq "") {
    return "ERROR: SubDomain must be specified!";
  }

  # Translate for web url
  $Sub = "%40" if ($Sub eq '@');

  my $url = $GoDaddyAPI.'/v1/domains/'.$DomainName.'/records/A/'.$Sub;

  # Check for Exceeded Quota for Transactions
  return "QUOTA_EXCEEDED" if (IsQUOTA_EXCEEDED());

  # Do the curl
  my $reply = NETCurl($url, 'DELETE');

  # Check of Monthly Transaction Quota has been exceeded
  CheckQUOTA($reply);

  # Translate back for printing
  $Sub = "@" if ($Sub eq '%40');
  return "Deleted $Sub A Record" if ($reply eq '');
  
  # Decode the response in JSON
  my $decoded_json = decode_json( $reply );

  # Referencable Fields
  #print $decoded_json->{code}; #UNKNOWN_DOMAIN
  #print $decoded_json->{message}; #The given domain is not registered, or does not have a zone file

  return $decoded_json->{code}.": ".$decoded_json->{message};

} #DeleteADNSRecord


################################################################################
# BuildUsage - Show usage information
################################################################################
sub BuildUsage
{
  print "\nUsage: $0   <Web_Domain>   <IPv4_Address>   [SubDomain (s1-s77)]   [--FORCE]\n\n";

  print " Purpose:\n";
  print "   Set the domain name A record in DNS to point to the IP Address specified.\n\n";

  print "   This calls the GoDaddy API with specific customerID in UUIDv4 format\n";
  print "   and API key:secret retrieved from developer.godaddy.com - API Keys.\n\n";

  print "   The SubDomain (s1-s77) optional parameter will create the subdomain A record.\n";
  print "   ie) s1.vegas.earth\n\n";

  print "   This supports the multi-server distributed WEB which keeps the data\n";
  print "   in sync between the servers.\n\n";

  print "   For s1 specifically, the \"@\" and \"s1\" A records will be created together\n";
  print "   - If the \"s1\" A record subdomain does NOT exist, it will be created\n";
  print "   - If \"s1\" exists and has a different IP Address, it will be ignored\n";
  print "     unless --FORCE is specified, in which case it will be replaced\n\n";

  print "   The main \"@\" A record will never be replaced or deleted\n";
  print "   unless --FORCE is specified.\n\n";

  print "   If \"--FORCE\" is specified as the 4th parameter, existing @ and SubDomain\n";
  print "   records will be overridden if they already exist (delete and add new)\n\n";

  print "   NOTE: Any \"forwarding\" of the root domain name will also be DELETED\n";
  print "         so the A records will now control DNS redirection\n\n";

  print "   ex)\n";
  print "       perl setGoDaddyDNS.pl   vegas.earth   99.6.104.130   s1\n";
  print "       perl setGoDaddyDNS.pl   vegas.earth   99.6.104.130\n\n\n";

  print " Parameters:\n";
  print "   <Web_Domain>\n";
  print "     - Domain DNS to be changed\n";
  print "   <IPv4_Address>\n";
  print "     - Traditional IP address: ex) 127.0.0.1\n";
  print "   [s1-s77]\n";
  print "     - Server SubDomain for Distributed WEB access\n";

  exit 1;
}
