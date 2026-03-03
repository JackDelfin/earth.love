#!/usr/bin/perl
# Version 1.0.1.0      06-June-2021
#*******************************************************************************
#
# REFRESH_akashic.pl
#
#     <Akashic_Domain_Directory>   ["<ROOT>*"]   ["<word/phrase/path>*"]   ["<datafile(s)>*"]   [DaysBack]
#
# Refreshes the index data in the Akashic Domain Directory for the
# ROOT(s) specified (blank is default for All roots in ROOTS.dat)
#
# ex) perl REFRESH_akashic.pl /LOVE/earth.love_DEV "LANGS/*" "" 7
#
#*******************************************************************************
# Parameters:
#
#   <Akashic_Domain_Directory:>
#         /LOVE/earth.love_DEV
#         /LOVE/earth.love_TEST
#         /LOVE/earth.love_PROD
#         c:\LOVE\earth.love_DEV
#
#   "<ROOT>*"
#         - Root Directory under Domain.
#           Default "" is ALL Roots.
#
#   "<word/phrase/path>*"
#         - word, phrase, or path to specifically update.
#           Default "*" is ALL objects.
#           If a CATegory is specified, all items below will also be refreshed.
#           Categories are defined by a CAT.dat file (as default).
#
#   "<datafile(s)>*"
#         - List of datafiles under Root _TREES to search for
#           when refreshing cached data
#           Default "" is ALL Datafiles:
#             "index,words,phrases,paths,dates,def,links"
#
#   DaysBack
#         - Check for changed data this many Days Back.
#           Default "" is all data.
#
#*******************************************************************************
# History:
#   2021.06.07 earth.love oK Updated
#   2021.06.06 earth.love oK Updated
#   2021.04.30 earth.love oK Created
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
my $Root = shift;
my $Word = shift;
my $Datafile = shift;
my $DaysBack = shift;

# Initialize variables
$Domain = "" if (!defined($Domain));
$Root = "" if (!defined($Root));
$Word = "" if (!defined($Word));
$Datafile = "" if (!defined($Datafile));
$DaysBack = "" if (!defined($DaysBack));

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
  RefreshUsage();
}

# Check if the Domain is a valid directory
if (!-d $Domain) {
  print "ERROR: Akashic Domain Directory [$Domain] does not exist!\n";
  RefreshUsage();
}

#
# Create new Akashic class and initialize
#
my $A = Akashic->new();

# Check initialization
RefreshUsage() if (!$A->getInitialized());

#
# Set the Akashic Domain variable and in the environment
#
$A->SetVar('DomainDir', $Domain);
$ENV{'EARTH_LOVE'} = $Domain;

print "############################################################\n";

print "Starting Akashic::SortRootDataFiles() to refresh indexes.\n";
print "--------------------------------------------------------------------------------\n";
print "  Domain:[$Domain] Root:[$Root] Words:[$Word] Data:[$Datafile] Days:[$DaysBack]\n";
print "--------------------------------------------------------------------------------\n";

# Show Start Time
my $startdate = localtime();
my $starttime = time();
print "Start: $startdate\n";

#
# Refresh the roots
#
$A->SortRootDataFiles($Root, $Word, $Datafile, $DaysBack);

# Show End Times
my $enddate = localtime();
my $endtime = time();
my $HMS     = $A->TimeDiffHMS($starttime, $endtime);
print "\n--------------------------------------------------\n";
print "Refresh Sort Start:  $startdate\n";
print "Refresh Sort End  :  $enddate\n";
print "--------------------------------------------------\n";
print "TIME : $HMS\n";
print "--------------------------------------------------\n";

print "############################################################\n";

exit 0;

################################################################################
# RefreshUsage - REFRESH_akashic.pl - Show usage information
################################################################################
sub RefreshUsage
{
  print "\nUsage: $0 <Akashic_Domain_Directory> [\"<ROOT>*\"] [\"<word/phrase/path>*\"] [\"<datafile(s)>*\"] [DaysBack]\n\n";

  print " Purpose:\n";
  print "   Refreshes the index data in the Akashic Domain Directory for the\n";
  print "   ROOT(s) specified (blank is default for All roots in ROOTS.dat)\n\n";

  print "   ex)\n";
  print "       perl $0 /LOVE/earth.love_DEV \"LANGS/\\*\"\n\n";

  print " Parameters:\n";
  print "   <Akashic_Domain_Directory:>\n";
  print "       /LOVE/earth.love_DEV\n";
  print "       c:\LOVE\earth.love_DEV\n\n";

  print "   \"<ROOT>*\"\n";
  print "       - Root Directory under Domain\n";
  print "         Default \"\" is ALL Roots.\n\n";

  print "   \"<word/phrase/path>*\"\n";
  print "       - word, phrase, or path to specifically update.\n";
  print "         Default \"\" is ALL objects.\n";
  print "         If a CATegory is specified, all items below will also be refreshed.\n";
  print "         Categories are defined by a CAT.dat file (as default).\n\n";

  print "   \"<datafile(s)>*\"\n";
  print "       - List of datafiles under Root _TREES to search for\n";
  print "         when refreshing cached data\n";
  print "         Default \"\" is ALL Datafiles:\n";
  print "           \"index,words,phrases,paths,dates,def,links\"\n\n";

  print "   DaysBack\n";
  print "       - Check for changed data this many Days Back.\n";
  print "         Default \"\" is all data.\n";

  exit 1;
}
