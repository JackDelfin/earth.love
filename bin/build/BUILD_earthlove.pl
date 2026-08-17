#!/usr/bin/perl
# Version 1.0.1.0      06-June-2021
#*******************************************************************************
#
# BUILD_earthlove.pl   <Akashic_Domain_Directory>   [BUILD / ALL / LITE / TEXTFILES / LOCATIONS / DOMAINS / NAMES]
# BUILD_earthlove.pl   <Akashic_Domain_Directory>   [<TextFile>/"<TextFile(s)>"/STDIN]   [<ROOT>]
#
# Purpose:
#   Build the Akashic ROOT trees for earth.love and load the data files
#
#   ex)
#       perl BUILD_earthlove.pl c:/LOVE/earth.love_DEV "../TEXTFILES/Air*" LANGS/ENG
#
# Parameters:
#   <Akashic_Domain_Directory:>
#     /LOVE/earth.love_DEV
#     /LOVE/earth.love_TEST
#     /LOVE/earth.love_PROD
#     c:\LOVE\earth.love_DEV
#     c:\LOVE\earth.love_TEST
#     c:\LOVE\earth.love_PROD
#
# First Calling Style:   - ROOT is encoded in procedures
#     BUILD     - Only Build Structure
#     ALL       - Process ALL TEXTFILES, LOCATIONS, DOMAINS from ../data/
#     LITE      - Process a sample of TEXTFILES, LOCATIONS, DOMAINS, NAMES from ../data/
#     TEXTFILES - process ALL TEXTFILES only
#     LOCATIONS - process ALL LOCATIONS only
#     DOMAINS   - process ALL DOMAINS only
#     NAMES     - process ALL NAMES only
#
# Second Calling Style:   - ROOT is specified as third parameter (watch the quotes around filenames with wildcards)
#     <TextFile>/"<TextFile(s)>"/STDIN - Quoted string of files with wildcards passed to ProcessWords for processing (?* Wildcards accepted)
#       STDIN   - Process standard input to Domain <ROOT> if specified (Defaults to Domain Level Root: _ROOT)
#     <ROOT>    - Root Directory under Domain to process textfiles or STDIN into
#
#
# History:
#   2021.06.16 earth.love oK Added additional Roots
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
use File::Copy;

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
$A->CreateWordBase('_ORBIT.USERS','USER',         'Users of this Domain',        'Users',       '', 'Users Root  (Heart/green)', 'green');
$A->CreateWordBase('_ORBIT.USERS.PERSONS','USER', 'People Users of this Domain', 'Person',      '', 'Persons Users Root  (Heart/green)', 'green');
$A->CreateWordBase('_ORBIT.MSG.CODE','MSG',       'Orbit Base Code Messages',    'Messages',    '', 'Orbit Base Code Messages Root  (Knowledge/indigo)', 'indigo');
$A->CreateWordBase('_ORBIT.MSG.ENG','MSG',        'Orbit English Translated Messages',   'Messages',       '', 'Orbit English Translated Messages Root  (Knowledge/indigo)', 'indigo');
$A->CreateWordBase('_ORBIT.MSG.LKT','MSG',        'Orbit Lakota Translated Messages',    'Messages',       '', 'Orbit Lakota Translated Messages Root  (Knowledge/indigo)', 'indigo');
$A->CreateWordBase('_ORBIT.MSG.ITA','MSG',        'Orbit Italian Translated Messages',   'Messages',       '', 'Orbit Italian Translated Messages Root  (Knowledge/indigo)', 'indigo');
$A->CreateWordBase('_ORBIT.MSG.SPA','MSG',        'Orbit Spanish Translated Messages',   'Messages',       '', 'Orbit Spanish Translated Messages Root  (Knowledge/indigo)', 'indigo');
$A->CreateWordBase('_ORBIT.MSG.GER','MSG',        'Orbit German Translated Messages',    'Messages',       '', 'Orbit German Translated Messages Root  (Knowledge/indigo)', 'indigo');
$A->CreateWordBase('_ORBIT.MSG.FRE','MSG',        'Orbit French Translated Messages',    'Messages',       '', 'Orbit French Translated Messages Root  (Knowledge/indigo)', 'indigo');
#*****************************************
#         END ORBIT CONFIGURATION        *
#*****************************************

#*****************************************
#*****************************************
#*****************************************

#*****************************************
#     BEGIN EARTH.LOVE CONFIGURATION     *
#*****************************************
#
# Create the Language (LANGS) Root subdirectories for storing words, phrases, and paths
#
$A->CreateWordBase('LANGS','LANG',   'Languages', 'Langs', 'Languages Root  (Heart/green)', 'green');
$A->CreateWordBase('LANGS.ENG','',   'English',              '', 'English Language', 'green');

# Only do other ROOTS for ALL or BUILD
if ($TEXTFILES =~ /^.*ALL.*$/i
  ||$TEXTFILES =~ /^.*BUILD.*$/i
  ) {
  # Create the index if not present
  if (!-d $A->GetVar('RootDir').'index.html') {
    copy('_TEMPLATES/INDEX.oml', $A->GetVar('DomainDir').'index.html');
  }

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

#
# Create the Local Community Roots
#
#       COMMS
#       PLANS
# GUILDS       JOBS
# COUNCILS     NEEDS
# RESOURCES    TRADES
# ORGS
# NEWS
#      SPIRITS
#    REFLECTIONS
#       IDEAS
#        KEYS
# BOOKS        LOCS
# DOMS         FOOD
# CATS         SOURCES
# TOOLS
#       NAMES
#       LANGS
#      PERSONS
#       SELF
#       HOMES
#---------------------
#       _ROOT
#---------------------
#         /\
#        /  \
#       /    \

$A->CreateWordBase('NAMES','NAME',    'Names',                '',         'Names Root  (Root/red)', 'red');
$A->CreateWordBase('LOCS','LOC',      'Locations',            '',         'Locations Root  (Sacral/orange)', 'orange');
$A->CreateWordBase('DOMS','DOM',      'Domains of Knowledge', 'Domains',  'Domains of Knowledge Root  (Third Eye/indigo)', 'indigo');

# Only do other ROOTS for ALL or BUILD
if ($TEXTFILES =~ /^.*ALL.*$/i
  ||$TEXTFILES =~ /^.*BUILD.*$/i
  ) {
  $A->CreateWordBase('PERSONS','PERSON',  'People', 'Persons', 'Persons Root  (Root/red)', 'red');
  $A->CreateWordBase('SELF','',           'Self',   '', 'Self Root  (Root/red)', 'red');

  # HOMES - COMMS - FAMS
  $A->CreateWordBase('HOMES','HOME',            'Homes',            'Homes',        'Homes Root  (Root/red)', 'red');
  $A->CreateWordBase('HOMES.COMMS','HOME',      'Community Homes',  'Our Homes',    'Community Homes Root  (Root/red)', 'red');
  $A->CreateWordBase('HOMES.COMMS.FAMS','HOME', 'Family Homes',     'Family Homes', 'Family Homes Root  (Root/red)', 'red');
  
  $A->CreateWordBase('FOOD','FOOD',             'Food','', 'Food Root  (Sacral/orange)', 'orange');
  $A->CreateWordBase('FOOD.SOURCES','FOOD',     'Food Sources','', 'Food Sources Root  (Sacral/orange)', 'orange');
  
  # SOURCES - WEACRES
  $A->CreateWordBase('SOURCES','SOURCE',                  'Sources',                         'Sources',   'Sources Root  (Sacral/orange)', 'orange');
  $A->CreateWordBase('SOURCES.EARTH','SOURCE',            'Mother Earth Sources',            'WEACRES',   'Mother Earth Sources of Natural ReSources Root  (Sacral/orange)', 'orange');
  $A->CreateWordBase('SOURCES.EARTH.WATER','SOURCE',      'Earth Water Sources',             'Water',     'Earth Water Sources Root  (Root/red)', 'red');
  $A->CreateWordBase('SOURCES.EARTH.ENERGY','SOURCE',     'Earth Energy Sources',            'Energy',    'Earth Energy Sources Root  (Sacral/orange)', 'orange');
  $A->CreateWordBase('SOURCES.EARTH.ANIMALS','SOURCE',    'Earth Animal Sources',            'Animals',   'Earth Animal Sources Root  (Solar Plexus/yellow)', 'yellow');
  $A->CreateWordBase('SOURCES.EARTH.COMMS','SOURCE',      'Earth Community Sources',         'Community', 'Earth Community Sources Root  (Heart/green)', 'green');
  $A->CreateWordBase('SOURCES.EARTH.RESOURCES','SOURCE',  'Earth Resource Sources',          'Resources', 'Earth Resource Sources Root  (Throat/blue)', 'blue');
  $A->CreateWordBase('SOURCES.EARTH.EARTH','SOURCE',      'Planet Mother Earth Land Sources','Earth',     'Planet Mother Earth Land Sources Root  (Third Eye/indigo)', 'indigo');
  $A->CreateWordBase('SOURCES.EARTH.SUSTAIN','SOURCE',    'Earth Sustainability Sources',    'Sustain',   'Earth Sustainability Sources Root  (Crown/violet)', 'violet');

  # JOBS - COMMS - FAMS
  $A->CreateWordBase('JOBS','JOB',            'Projects Directory', 'Jobs',        'Directory of Planetary Jobs (Projects) Root  (Solar Plexus/yellow)', 'yellow');
  $A->CreateWordBase('JOBS.COMMS','JOB',      'Community Projects', 'Our Jobs',    'Community Jobs (Projects) Root  (Solar Plexus/yellow)', 'yellow');
  $A->CreateWordBase('JOBS.COMMS.FAMS','JOB', 'Family Projects',    'Family Jobs', 'Family Jobs (Projects) Root  (Solar Plexus/yellow)', 'yellow');
  
  # NEEDS - COMMS - FAMS
  $A->CreateWordBase('NEEDS','NEED',            'Planetary Resource Needs', 'Needs',        'Planetary Resource Needs Root  (Solar Plexus/yellow)', 'yellow');
  $A->CreateWordBase('NEEDS.COMMS','NEED',      'Community Resource Needs', 'Our Needs',    'Community Resource Needs Root  (Solar Plexus/yellow)', 'yellow');
  $A->CreateWordBase('NEEDS.COMMS.FAMS','NEED', 'Family Resource Needs',    'Family Needs', 'Family Resource Needs Root  (Solar Plexus/yellow)', 'yellow');
  
  # TRADES - COMMS - FAMS
  $A->CreateWordBase('TRADES','TRADE',            'Trades & Commerce',            'Trades',        'Planetary Trades (Commerce) Root  (Solar Plexus/yellow)', 'yellow');
  $A->CreateWordBase('TRADES.COMMS','TRADE',      'Community Trades & Commerce',  'Our Trades',    'Community Trades (Commerce) Root  (Solar Plexus/yellow)', 'yellow');
  $A->CreateWordBase('TRADES.COMMS.FAMS','TRADE', 'Family Trades',                'Family Trades', 'Family Trades (Commerce) Root  (Solar Plexus/yellow)', 'yellow');

  # COMMS
  $A->CreateWordBase('COMMS','COMM',        'Communities',     '',      'Communities Root  (Heart/green)', 'green');

  # PLANS - COMMS - FAMS
  $A->CreateWordBase('PLANS','PLAN',           'Directory of Whole Earth Community Plans', 'Plans',        'Plans Root  (Heart/green); PLANS lead to JOBS (PROJECTS)', 'indigo');
  $A->CreateWordBase('PLANS.COMMS','PLAN',     'Community Plans',                          'Our Plans',    'Community Plans Root  (Heart/green); Community PLANS lead to JOBS', 'green');
  $A->CreateWordBase('PLANS.COMMS.FAM','PLAN', 'Family Plans',                             'Family Plans', 'Family Plans Root  (Heart/green); Community PLANS lead to JOBS', 'green');

  # FEDS - COMMS
  $A->CreateWordBase('FEDS','FED',          'Earth Federations',     'Federations', 'Planet Earth Federations and Confederations Root  (Heart/green)', 'green');
  $A->CreateWordBase('FEDS.COMMS','FED',    'Community Federations', 'Federations', 'Community Federations and Confederations Root  (Heart/green)', 'green');

  # FAMS - COMMS - JOBS
  $A->CreateWordBase('FAMS','FAM',          'Earth Family Directory',                        'Earth Families', 'Families on Planet Earth Directory Root  (Heart/green)', 'green');
  $A->CreateWordBase('FAMS.COMMS','FAM',    'Community Families',                            'Families',       'Community Families Root  (Heart/green)', 'green');
  $A->CreateWordBase('FAMS.JOBS','FAM',     'Catalog of Whole Earth Family Projects (Jobs)', 'Families',       'Whole Planet Earth Family Projects Catalog Root  (Solar Plexus/yellow)', 'yellow');

  # GUILDS - FEDS - COMMS - JOBS
  $A->CreateWordBase('GUILDS','GUILD',            'Directory of Guilds & Groups', 'Guilds',            'Planetary Guilds & Groups Directory Root  (Throat/blue)', 'blue');
  $A->CreateWordBase('GUILDS.JOBS','GUILD',       'Planetary Guild Projects',     'Guild Jobs',        'Guild Jobs (Projects) Directory Root  (Solar Plexus/yellow)', 'yellow');
  $A->CreateWordBase('GUILDS.FEDS','GUILD',       'Guild Federations',            'Guild Federations', 'Guild Federations Directory Root  (Heart/green)', 'green');
  $A->CreateWordBase('GUILDS.FEDS.JOBS','GUILD',  'Guild Federation Jobs',        'Federation Jobs',   'Guild Federation Projects (Jobs) Root  (Solar Plexus/yellow)', 'yellow');
  $A->CreateWordBase('GUILDS.COMMS','GUILD',      'Community Guilds',             'Guilds',            'Community Guilds Root  (Heart/green)', 'green');
  $A->CreateWordBase('GUILDS.COMMS.JOBS','GUILD', 'Community Guild Jobs',         'Guild Jobs',        'Community Guild Jobs Root  (Solar Plexus/yellow)', 'yellow');

  $A->CreateWordBase('COUNCILS','COUNCIL',   'Councils & Governance', 'Councils',      'Councils Root  (Throat/blue)', 'blue');

  # RESOURCES - COMMS - FAMS - JOBS
  $A->CreateWordBase('RESOURCES','RESOURCE',            'Planetary Resources',           'Resources',            'Planetary Resources Root  (Throat/blue)', 'blue');
  $A->CreateWordBase('RESOURCES.JOBS','RESOURCE',       'Planetary Project Resources',   'Job Resources',        'Planetary Project Resources (Projects) Directory Root  (Solar Plexus/yellow)', 'yellow');
  $A->CreateWordBase('RESOURCES.FEDS','RESOURCE',       'Federation Resources',          'Fed Resources',        'Federation Resources Root  (Heart/green)', 'green');
  $A->CreateWordBase('RESOURCES.FEDS.JOBS','RESOURCE',  'Federation Project Resources',  'Fed Job Resources',    'Federation Project Resrouces (Jobs) Root  (Solar Plexus/yellow)', 'yellow');
  $A->CreateWordBase('RESOURCES.COMMS','RESOURCE',      'Community Resources',           'Our Resources',        'Community Resources Root  (Heart/green)', 'green');
  $A->CreateWordBase('RESOURCES.COMMS.JOBS','RESOURCE', 'Community Project Resources',   'Our Job Resources',    'Community Project Resources (Job) Root  (Solar Plexus/yellow)', 'yellow');
  $A->CreateWordBase('RESOURCES.COMMS.FAMS','RESOURCE', 'Family Resources',              'Family Resources',     'Family Resources Root  (Heart/green)', 'green');
  $A->CreateWordBase('RESOURCES.COMMS.FAMS.JOBS','RESOURCE', 'Family Project Resources', 'Family Job Resources', 'Family Project (Job) Resources Root  (Solar Plexus/yellow)', 'yellow');
  # Create SURVEYS Root
  $A->CreateWordBase('SURVEYS','SURVEY',        'Surveys',     'Surveys',      'Surveys Root  (Throat/Blue)', 'blue');

  # ORGS - COMMS - FAMS
  $A->CreateWordBase('ORGS','ORG',            'Organizations',            'Organizations',   'Planetary Organizations Root  (Throat/blue)', 'blue');
  $A->CreateWordBase('ORGS.FEDS','ORG',       'Federation Organizations', 'Federation Orgs', 'Federation Organizations Root  (Throat/blue)', 'blue');
  $A->CreateWordBase('ORGS.COMMS','ORG',      'Community Organizations',  'Local Biz',       'Community Organizations Root  (Throat/blue)', 'blue');
  $A->CreateWordBase('ORGS.COMMS.FAMS','ORG', 'Family Organizations',     'Family Biz',      'Family Organizations Root  (Throat/blue)', 'blue');

  # NEWS - COMMS - FAMS
  $A->CreateWordBase('NEWS','REPORT',            'Planetary News',  'News',            'Planetary News Root  (Throat/blue)', 'blue');
  $A->CreateWordBase('NEWS.FEDS','REPORT',       'Federation News', 'Federation News', 'Federation News Root  (Throat/blue)', 'blue');
  $A->CreateWordBase('NEWS.COMMS','REPORT',      'Community News',  'Our News',        'Community News Root  (Throat/blue)', 'blue');
  $A->CreateWordBase('NEWS.COMMS.FAMS','REPORT', 'Family News',     'Family News',     'Family News Root  (Throat/blue)', 'blue');

  # BOOKS - LIBRA - TOOLS - FEDS - COMMS - FAMS
  $A->CreateWordBase('BOOKS','BOOK',            'Books of Knowledge',  'Knowledge',       'Books of Knowledge Root  (Third Eye/indigo)', 'indigo');
  $A->CreateWordBase('LIBRA','BOOK',            'Libraries',           'Library',         'Directory of Planetary Libraries Root  (Third Eye/indigo)', 'indigo');
  $A->CreateWordBase('LIBRA.BOOKS','BOOK',      'Library Items',       'Books',           'Directory of Library Items (Books) Root  (Third Eye/indigo)', 'indigo');
  $A->CreateWordBase('LIBRA.TOOLS','BOOK',      'Tool Libraries',      'Library',         'Directory of Planetary Tool Libraries Root  (Third Eye/indigo)', 'indigo');
  $A->CreateWordBase('LIBRA.FEDS','BOOK',       'Federation Libraries', 'Fed Library',    'Federation Libraries Root  (Throat/blue)', 'blue');
  $A->CreateWordBase('LIBRA.COMMS','BOOK',      'Community Libraries',  'Our Library',    'Community Libraries Root  (Throat/blue)', 'blue');
  $A->CreateWordBase('LIBRA.COMMS.FAMS','BOOK', 'Family Libraries',     'Family Library', 'Family Libraries Root  (Throat/blue)', 'blue');

  $A->CreateWordBase('CATS','CAT',       'Categories',            'Catalogs',    'Categories & Catalogs Root  (Third Eye/indigo)', 'indigo');

  # TOOLS - COMMS - FAMS
  $A->CreateWordBase('TOOLS','TOOL',     'Tools Knowledge',       'Tools',       'Tools Root  (Third Eye/indigo)', 'indigo');


  $A->CreateWordBase('SPIRITS','SPIRIT',         'Spirituality',  'Connection',  'Spirits Root  (Crown/violet)', 'violet');
  $A->CreateWordBase('REFLECTIONS','REFLECTION', 'Reflections',   'Reflect',     'Reflections Root  (Crown/violet)', 'violet');
  $A->CreateWordBase('IDEAS','IDEA',             'Ideas',         '',            'Ideas Root  (Crown/violet)', 'violet');
  $A->CreateWordBase('KEYS','KEY',               'Access Keys',   'Keys',        'Ideas Root  (Crown/violet)', 'violet');
} #ALL
#*****************************************
# END EARTH.LOVE CONFIGURATION
#*****************************************

print "Starting Akashic::ProcessWords() to build [$Domain].\n";

#
# Call ProcessWords to process the input TEXTFILES
#
if ($TEXTFILES =~ /^ALL$/i) {
  #
  # Process ALL of the data for LANGS.ENG, LOCS, DOMS
  #

  # TEXTFILES
  #
  # Process the Textfiles to the LANGS.ENG root
  # - Don't sort while adding
  $A->ProcessWords("../data/TEXTFILES/*.txt", 'LANGS.ENG', 0, 0);
  #$A->ProcessWords("../data/TEXTFILES_ITA/*.txt", 'LANGS.ITA', 0, 0);
  $A->SortRootDataFiles('LANGS');

  # LOCATIONS
  #
  # Process the Locations to the LOCS root
  # - Don't sort while adding
  $A->ProcessWords("../data/LOCATIONS/*.txt", 'LOCS', 0, 0);
  $A->SortRootDataFiles('LOCS');

  # DOMAINS
  #
  # Process the Domains to the DOMS root
  # - Don't sort while adding
  $A->ProcessWords("../data/DOMAINS/*.txt", 'DOMS', 0, 0);
  $A->SortRootDataFiles('DOMS');

  # NAMES
  #
  # Process First Names to the NAMES root
  # - Don't sort while adding
  $A->ProcessWords("../data/NAMES/*.txt", 'NAMES', 0, 0);
  $A->SortRootDataFiles('NAMES');

  #
  # Show the summary statistics
  #
  $A->ShowStatistics();

} elsif ($TEXTFILES =~ /^TEXTFILES$/i) {
  # TEXTFILES
  #
  # Process the Textfiles to the LANGS.ENG root
  # - Don't sort while adding
  $A->ProcessWords("../data/TEXTFILES/*.txt", 'LANGS.ENG', 1, 0);
  #$A->ProcessWords("../data/TEXTFILES_ITA/*.txt", 'LANGS.ITA', 1, 0);
  $A->SortRootDataFiles('LANGS.ENG');

} elsif ($TEXTFILES =~ /^LOCATIONS$/i) {
  # LOCATIONS
  #
  # Process the Locations to the LOCS root
  # - Don't sort while adding
  $A->ProcessWords("../data/LOCATIONS/*.txt", 'LOCS', 1, 0);
  $A->SortRootDataFiles('LOCS');

} elsif ($TEXTFILES =~ /^DOMAINS$/i) {
  # DOMAINS
  #
  # Process the Domains to the DOMS root
  # - Don't sort while adding
  $A->ProcessWords("../data/DOMAINS/*.txt", 'DOMS', 1, 0);
  $A->SortRootDataFiles('DOMS');

} elsif ($TEXTFILES =~ /^NAMES$/i) {
  # NAMES
  #
  # Process First Names to the NAMES root
  # - Don't sort while adding
  $A->ProcessWords("../data/NAMES/*.txt", 'NAMES', 1, 0);
  $A->SortRootDataFiles('NAMES');

} elsif ($TEXTFILES =~ /^LITE$/i) {
  #
  # LITE Processing of the data for testing LANGS.ENG, LOCS, DOMS
  #

  # WORDS
  #
  # Process the Textfiles to the LANGS.ENG root
  $A->ProcessWords("../data/TEXTFILES/Animals.txt", 'LANGS.ENG', 0, 0);
  $A->ProcessWords("../data/TEXTFILES/Mammals.txt", 'LANGS.ENG', 0, 0);
  $A->ProcessWords("../data/TEXTFILES/Elements.txt", 'LANGS.ENG', 0, 0);
  $A->SortRootDataFiles('LANGS.ENG');

  # LOCATIONS
  #
  # Process the Locations to the LOCS root
  $A->ProcessWords("../data/LOCATIONS/Nat*.txt", 'LOCS', 0, 0);
  $A->SortRootDataFiles('LOCS');

  # DOMAINS
  #
  # Process the Domains to the DOMS root
  $A->ProcessWords("../data/DOMAINS/Com*Sites.txt", 'DOMS', 0, 0);
  $A->SortRootDataFiles('DOMS');

  # NAMES
  #
  # Process First Names to the NAMES root
  $A->ProcessWords("../data/NAMES/LITE/*.txt", 'NAMES', 0, 0);
  $A->SortRootDataFiles('NAMES');

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
print "Build earth.love Start:  $startdate\n";
print "Build earth.love End  :  $enddate\n";
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
  print "\nUsage: $0   <Akashic_Domain_Directory>   [BUILD / ALL / LITE / TEXTFILES / LOCATIONS / DOMAINS / NAMES]\n";
  print "or     $0   <Akashic_Domain_Directory>   [<TextFile>/\"<TextFile(s)>\"/STDIN]   [<ROOT>]\n\n";

  print " Purpose:\n";
  print "   Build the Akashic ROOT trees for earth.love and load the data files\n\n";

  print "   ex)\n";
  print "       perl BUILD_earthlove.pl /LOVE/earth.love_DEV \"../TEXTFILES/Air*\" LANGS.ENG\n\n";

  print " Parameters:\n";
  print "   <Akashic_Domain_Directory:>\n";
  print "     /LOVE/earth.love_DEV\n";
  print "     c:\LOVE\earth.love_DEV\n\n";

  print " First Calling Style:   - ROOT is encoded in procedures\n";
  print "     BUILD     - Only Build Structure\n";
  print "     ALL       - Process ALL TEXTFILES, LOCATIONS, DOMAINS from ../data/\n";
  print "     LITE      - Process a sample of TEXTFILES, LOCATIONS, DOMAINS, NAMES from ../data/\n";
  print "     TEXTFILES - process ALL TEXTFILES only\n";
  print "     LOCATIONS - process ALL LOCATIONS only\n";
  print "     DOMAINS   - process ALL DOMAINS only\n";
  print "     NAMES     - process ALL NAMES only\n\n";

  print " Second Calling Style:   - ROOT is specified as third parameter (watch the quotes around filenames with wildcards)\n";
  print "     <TextFile>/\"<TextFile(s)>\"/STDIN - Quoted string of files with wildcards passed to ProcessWords for processing (?* Wildcards accepted)\n";
  print "       STDIN   - Process standard input to Domain <ROOT> if specified (Defaults to Domain Level Root: _ROOT)\n";
  print "     <ROOT>    - Root Directory under Domain to process textfiles or STDIN into\n";

  exit 1;
}
