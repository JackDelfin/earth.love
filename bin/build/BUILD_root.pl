#!/usr/bin/perl
# Version 1.0.0.0      22-Nov-2024
#*******************************************************************************
#
# BUILD_root.pl   <Web_Domain>   [<ROOTWORD>]   ["Root Description"]
#
# Purpose:
#   Build the Akashic ROOT structure for the domain specified (_ROOT by default)
#   NOTE: The _ROOT _ORBIT and LANGS roots will be created if they don't exist
#
#   ex)
#       perl BUILD_root.pl doms.earth _ROOT "Default Root Directory"
#
# Parameters:
#   <Web_Domain>
#     - Domain will be searched in /etc/apache2/sites-available
#       to get the DocumentRoot
#     - _WEB will be stripped off to get the DomainDir
#   <ROOTWORD>
#     - If <DomainDir>/_ROOT does not exist, it will be created first
#     - If ROOTWORD is not specified, _ROOT will be used
#       and built off of the DocumentRoot
#     - If ROOTWORD is "LANGS", all supported Languages will be built for the domain
#   ["Root Description"]
#     - Friendly name for the ROOTWORD
#
# History:
#   2024.11.22 earth.love oK Created
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
use File::Copy;

my $Domain = shift;
my $Root = shift;
my $RootDesc = shift;

my $DomainDir = "";

# Initialize variables
$Domain = "" if (!defined($Domain));
$Root = "_ROOT" if (!defined($Root) || $Root eq "");
$Root =~ tr/[a-z]/[A-Z]/;   # Uppercase per convention
$RootDesc = "$Root" if (!defined($RootDesc) || $RootDesc eq "");

#
# Load the Akashic subroutines
#
use lib qw( ./lib ../lib );
use Akashic::Process;

#
# Check for Akashic Domain Directory as input
#
if (!defined($Domain) || $Domain eq "") {
  print "ERROR: The Domain Name must be specified as a parameter!\n";
  BuildUsage();
}

# Get DocumentRoot from /etc/apache2/sites-available
my $DomainConfig = "/etc/apache2/sites-available/$Domain".".conf";
if (-e $DomainConfig) {
  $DomainDir = `grep -ie "^[ \t]*DocumentRoot" $DomainConfig`;
  chomp($DomainDir);
  $DomainDir =~ s/^[ \t]*DocumentRoot[ \t]*//;  # Remove DocumentRoot from string
  $DomainDir =~ s/_WEB$//;    # Remove _WEB from end of string
  # Check if the DomainDir is a valid directory (DO NOT CREATE AUTOMATICALLY)
  if (-d $DomainDir) {
    print "DomainDir: $DomainDir\n";
  } else {
    print "ERROR: Akashic Domain Directory [$DomainDir] does not exist for $Domain!  This must be created first.\n";
    BuildUsage();
  }
} else {
  print "ERROR: The Domain configuration was not found:\n";
  print "       $DomainConfig\n";
  BuildUsage();
}

#
# Create new Akashic class - do not initialize (0)
#
my $A = Akashic->new(0);

#
# Set the Akashic Domain variable and in the environment
#
$A->SetVar('DomainDir', $DomainDir);
$ENV{'EARTH_LOVE'} = $DomainDir;

# Show Start Time and get time in seconds
#my $startdate = localtime();
#my $starttime = time();
#print "Build Start: $startdate\n";

#print "############################################################\n";

# Make the Domain Root WordBase
$A->CreateWordBase('_ROOT','ROOT', 'Domain Root');   # Create Domain Wordbase _ROOT (cumulative of all roots)

# Initialize the environment (after the Main Root _ROOT is created)
$A->InitAkashic();

# Check initialization
BuildUsage() if (!$A->getInitialized());

#*****************************************
#        BEGIN ORBIT CONFIGURATION       *
#*****************************************
$A->CreateWordBase('_ORBIT.USERS','USER',         'Users of this Domain',        'Users',       '', 'Users Root  (Heart/green)', 'green');
$A->CreateWordBase('_ORBIT.USERS.PERSONS','USER', 'People Users of this Domain', 'Person',      '', 'Persons Users Root  (Heart/green)', 'green');
$A->CreateWordBase('_ORBIT.PASSPHRASE','PASS',    'Pass Phrases for Users',      'PassPhrase',  '', 'PassPhrases Root  (Sacral/orange)', 'orange');
$A->CreateWordBase('_ORBIT.MSG.CODE','MSG',       'Orbit Base Code Messages',    'Messages',    '', 'Orbit Base Code Messages Root  (Knowledge/indigo)', 'indigo');
$A->CreateWordBase('_ORBIT.MSG.ENG','MSG',        'Orbit English Translated Messages',   'Messages',       '', 'Orbit English Translated Messages Root  (Knowledge/indigo)', 'indigo');
#*****************************************
#         END ORBIT CONFIGURATION        *
#*****************************************

#*****************************************
#*****************************************
#*****************************************

#*****************************************
#     BEGIN DomainDir CONFIGURATION     *
#*****************************************
#
# Create the Language (LANGS) Root subdirectories for storing words, phrases, and paths
#
$A->CreateWordBase('LANGS','LANG',   'Languages', 'Langs', 'Languages Root  (Heart/green)', 'green');
$A->CreateWordBase('LANGS.ENG','',   'English',              '', 'English Language', 'green');

# Create Additional Language ROOTS if ROOTWORD is "LANGS"
if ($Root eq "LANGS") {
  $A->CreateWordBase('LANGS.AMH','', 'Amharic',              '', 'Amharic Language', 'green');
  $A->CreateWordBase('LANGS.ARA','', 'Arabic',               '', 'Arabic Language', 'green');
  $A->CreateWordBase('LANGS.BPO','', 'Brazilian Portuguese', '', 'Brazilian Porgugese Language', 'green');
  $A->CreateWordBase('LANGS.GBE','', 'British English',      '', 'British English Language', 'green');
  $A->CreateWordBase('LANGS.FRE','', 'French',               '', 'Frency Language', 'green');
  $A->CreateWordBase('LANGS.GER','', 'German',               '', 'German Language', 'green');
  $A->CreateWordBase('LANGS.GRE','', 'Greek',                '', 'Greek Language', 'green');
  $A->CreateWordBase('LANGS.HEB','', 'Hebrew',               '', 'Hebrew Language', 'green');
  $A->CreateWordBase('LANGS.HIN','', 'Hindi',                '', 'Hindi Language', 'green');
  $A->CreateWordBase('LANGS.ITA','', 'Italian',              '', 'Italian Language', 'green');
  $A->CreateWordBase('LANGS.JPN','', 'Japanese',             '', 'Japanese Language', 'green');
  $A->CreateWordBase('LANGS.KOR','', 'Korean',               '', 'Korean Language', 'green');
  $A->CreateWordBase('LANGS.LAN','', 'Latin',                '', 'Latin Language', 'green');
  $A->CreateWordBase('LANGS.LKT','', 'Lakota',               '', 'Lakota Language', 'green');
  $A->CreateWordBase('LANGS.POL','', 'Polish',               '', 'Polish Language', 'green');
  $A->CreateWordBase('LANGS.POR','', 'Portuguese',           '', 'Purtugese Language', 'green');
  $A->CreateWordBase('LANGS.ROM','', 'Romanian',             '', 'Romanian Language', 'green');
  $A->CreateWordBase('LANGS.RUS','', 'Russian',              '', 'Russian Language', 'green');
  $A->CreateWordBase('LANGS.SER','', 'Serbian',              '', 'Serbian Language', 'green');
  $A->CreateWordBase('LANGS.SIG','', 'Sign',                 '', 'Sign Language', 'green');
  $A->CreateWordBase('LANGS.SYM','SYM', 'Symbols',           '', 'Symbols Language', 'green');
  $A->CreateWordBase('LANGS.CHI','', 'Simplified Chinese',   '', 'Simplified Chinese Language', 'green');
  $A->CreateWordBase('LANGS.SPA','', 'Spanish',              '', 'Spanish Language', 'green');
  $A->CreateWordBase('LANGS.THA','', 'Thai',                 '', 'Thai Language', 'green');
  $A->CreateWordBase('LANGS.ZHT','', 'Traditional Chinese',  '', 'Traditional Chinese Language', 'green');
  $A->CreateWordBase('LANGS.TUR','', 'Turkish',              '', 'Turkish Language', 'green');
  $A->CreateWordBase('LANGS.UKR','', 'Ukrainian',            '', 'Ukrainian Language', 'green');
  $A->CreateWordBase('LANGS.VIT','', 'Vietnamese',           '', 'Vietnamese Language', 'green');
} #ALL

# Create the specified root if provided
if ($Root ne "" && $Root ne "_ROOT") {
  $A->CreateWordBase($Root,'', $RootDesc, '','','');
}

#*****************************************
# END DomainDir CONFIGURATION
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
# BuildUsage - Show usage information
################################################################################
sub BuildUsage
{
  print "\nUsage: $0   <Web_Domain>   [<ROOTWORD>]   [\"Root Description\"]\n";

  print " Purpose:\n";
  print "   Build the Akashic ROOT structure for the domain specified (_ROOT by default)\n";
  print "   NOTE: The _ROOT _ORBIT and LANGS roots will be created if they don't exist\n\n";

  print "   ex)\n";
  print "       perl BUILD_root.pl doms.earth _ROOT \"Default Root Directory\"\n\n";

  print " Parameters:\n";
  print "   <Web_Domain>\n";
  print "     - Domain will be searched in /etc/apache2/sites-available\n";
  print "       to get the DocumentRoot\n";
  print "     - _WEB will be stripped off to get the DomainDir\n";
  print "   <ROOTWORD>\n";
  print "     - If <DomainDir>/_ROOT does not exist, it will be created first\n";
  print "     - If ROOTWORD is not specified, _ROOT will be used\n";
  print "       and built off of the DocumentRoot\n";
  print "     - If ROOTWORD is \"LANGS\", all supported Languages will be built for the domain\n";
  print "   [\"Root Description\"]\n";
  print "     - Friendly name for the ROOTWORD\n";

  exit 1;
}
