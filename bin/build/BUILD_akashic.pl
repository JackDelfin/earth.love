#!/usr/bin/perl
# Version 1.0.1.0      06-June-2021
#*******************************************************************************
#
# BUILD_akashic.pl   <Akashic_Domain_Directory>   [BUILD / ALL / LITE]
# BUILD_akashic.pl   <Akashic_Domain_Directory>   [<TextFile>/"<TextFile(s)>"/STDIN]   [<ROOT>]
#
# Purpose:
#   Build the Akashic ROOT trees under the Domain and load the data files
#
#   ex)
#       perl BUILD_akashic.pl c:/LOVE/earth.love_DEV "../TEXTFILES/Air*"
#
# Parameters:
#   <Akashic_Domain_Directory:>
#     /LOVE/earth.love_DEV
#     /LOVE/earth.love_TEST
#     /LOVE/earth.love_PROD
#     c:\LOVE\earth.love_DEV
#
# First Calling Style:   - ROOT is encoded in procedures
#     BUILD     - Only Build Structure
#     ALL   - Process ALL TEXTFILES, LOCATIONS, DOMAINS from ../data/
#     LITE  - Process a sample of TEXTFILES, LOCATIONS, DOMAINS, NAMES from ../data/
#
# Second Calling Style:   - ROOT is specified as third parameter (watch the quotes around filenames with wildcards)
#     <TextFile>/"<TextFile(s)>"/STDIN - Quoted string of files with wildcards passed to ProcessWords for processing (?* Wildcards accepted)
#       STDIN   - Process standard input to Domain <ROOT> if specified (Defaults to Domain Level Root: _ROOT)
#     <ROOT>    - Root Directory under Domain to process textfiles or STDIN into
#
#
# History:
#   2021.06.06 earth.love oK Updated
#   2021.06.04 earth.love oK Updated
#   2021.05.26 earth.love oK Updated
#   2021.04.08 earth.love oK Updated
#   2021.04.07 earth.love oK Created
#*******************************************************************************
# Copyright 2021 Kevin Runner / Runchero Federation / PISA
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

my $Domain = shift;
my $TEXTFILES = shift;
my $Root = shift;

# Initialize variables
$Domain = "" if (!defined($Domain));
$TEXTFILES = "" if (!defined($TEXTFILES) || $TEXTFILES eq "");
$Root = "_ROOT" if (!defined($Root) || $Root eq "");
$Root =~ tr/[a-z]/[A-Z]/;   # Uppercase per convention

#
# Load the Akashic subroutines
#
use lib qw( ./lib ../lib );
use Akashic::Process;

#
# Check for Akashic Domain Directory as input
#
if (!defined($Domain) || $Domain eq "") {
  print "ERROR: The Akashic Domain Directory must be specified as a parameter!\n";
  BuildUsage();
}

# Check if the Domain is a valid directory (DO NOT CREATE AUTOMATICALLY)
if (!-d $Domain) {
  print "ERROR: Akashic Domain Directory [$Domain] does not exist!  This must be created manually.\n";
  BuildUsage();
}

#
# Create new Akashic class - do not initialize (0)
#
my $A = Akashic->new(0);

#
# Set the Akashic Domain variable and in the environment
#
$A->SetVar('DomainDir', $Domain);
$ENV{'EARTH_LOVE'} = $Domain;

# Show Start Time and get time in seconds
my $startdate = localtime();
my $starttime = time();
print "Build Start: $startdate\n";

print "############################################################\n";

# Make the Domain Root WordBase
$A->CreateWordBase('_ROOT','ROOT', 'Domain Root');   # Create Domain Wordbase _ROOT (cumulative of all roots)

# Initialize the environment (after the Main Root _ROOT is created)
$A->InitAkashic();

# Check initialization
BuildUsage() if (!$A->getInitialized());

#*****************************************
#        BEGIN ORBIT CONFIGURATION       *
#*****************************************
# Activate Orbit Users in "Akashic Records"
$A->CreateWordBase('_ORBIT.USERS','USER',         'Users of this Domain',        'Users',       '', 'Users Root  (Heart/green)', 'green');
$A->CreateWordBase('_ORBIT.USERS.PERSONS','USER', 'People Users of this Domain', 'Person',      '', 'Persons Users Root  (Heart/green)', 'green');
$A->CreateWordBase('_ORBIT.PASSPHRASE','PASS',    'Pass Phrases for Users',      'PassPhrase',  '', 'PassPhrases Root  (Sacral/orange)', 'orange');
$A->CreateWordBase('_ORBIT.MSG','MSG',            'Orbit Translated Messages',   'Messages',    '', 'Orbit Translated Messages Root  (Knowledge/indigo)', 'indigo');
#*****************************************
#         END ORBIT CONFIGURATION        *
#*****************************************

print "Starting Akashic::ProcessWords() to build [$Domain].\n";

#
# Call ProcessWords to process the input TEXTFILES
#
if ($TEXTFILES =~ /^ALL$/i) {
  #
  # Process ALL of the data for LANGS/ENG, LOCS, DOMS
  #

  # TEXTFILES
  #
  # Process the Textfiles to the LANGS/ENG root
  $A->ProcessWords("../data/TEXTFILES/*.txt", '_ROOT', 0, 0);
  $A->SortRootDataFiles('_ROOT');

  #
  # Show the summary statistics
  #
  $A->ShowStatistics();


} elsif ($TEXTFILES =~ /^LITE$/i) {
  #
  # LITE Processing of the data for testing LANGS/ENG, LOCS, DOMS
  #

  # WORDS
  #
  # Process the Textfiles to the LANGS/ENG root
  $A->ProcessWords("../data/TEXTFILES/Anim*.txt", '_ROOT', 0, 0);
  $A->SortRootDataFiles('_ROOT');

  #
  # Show the summary statistics
  #
  $A->ShowStatistics();

} elsif ($TEXTFILES =~ /^BUILD$/i) {
  #
  # Build ONLY - No Processing
  #
  print 'Build Complete!  Check output for details.';

  # Show the summary statistics
  $A->ShowStatistics();

} elsif ($TEXTFILES =~ /^STDIN$/i) {
  #
  # Standard Input Processing
  #
  # Process the Text to the Domain Root, sort as we go
  # - Show Statistics and Sort indexes along the way
  $A->ProcessWords("", $Root, 1, 1);

  # Show the summary statistics
  $A->ShowStatistics();

} else {

  # Manual processing of data files
  # Process the Textfiles to the Root specified
  # - Show Statistics and Sort indexes along the way
  $A->ProcessWords($TEXTFILES, $Root, 1, 1);
}

# Show End Times
my $enddate = localtime();
my $endtime = time();
my $HMS     = $A->TimeDiffHMS($starttime, $endtime);
print "\n--------------------------------------------------\n";
print "Build Akashic Start:  $startdate\n";
print "Build Akashic End  :  $enddate\n";
print "--------------------------------------------------\n";
print "TIME : $HMS\n";
print "--------------------------------------------------\n";

print "############################################################\n";

exit 0;

################################################################################
# BuildUsage - Show usage information
################################################################################
sub BuildUsage
{
  print "\nUsage: $0   <Akashic_Domain_Directory>   [BUILD / ALL / LITE]\n";
  print "       $0   <Akashic_Domain_Directory>   [<TextFile>/\"<TextFile(s)>\"/STDIN]   [<ROOT>]\n\n";

  print " Purpose:\n";
  print "   Build the Akashic ROOT trees for earth.love and load the data files\n\n";

  print "   ex)\n";
  print "       perl BUILD_earthlove.pl /LOVE/earth.love_DEV \"../TEXTFILES/Air*\" MYROOT\n\n";

  print " Parameters:\n";
  print "   <Akashic_Domain_Directory:>\n";
  print "     /LOVE/earth.love_DEV\n";
  print "     c:\LOVE\earth.love_DEV\n\n";

  print " First Calling Style:   - ROOT is encoded in procedures\n";
  print "     BUILD     - Only Build Structure\n";
  print "     ALL       - Process ALL TEXTFILES, LOCATIONS, DOMAINS from ../data/\n";
  print "     LITE      - Process a sample of TEXTFILES, LOCATIONS, DOMAINS, NAMES from ../data/\n\n";

  print " Second Calling Style:   - ROOT is specified as third parameter (watch the quotes around filenames with wildcards)\n";
  print "     <TextFile>/\"<TextFile(s)>\"/STDIN - Quoted string of files with wildcards passed to ProcessWords for processing (?* Wildcards accepted)\n";
  print "       STDIN   - Process standard input to Domain <ROOT> if specified (Defaults to Domain Level Root: _ROOT)\n";
  print "     <ROOT>    - Root Directory under Domain to process textfiles or STDIN into\n";

  exit 1;
}
