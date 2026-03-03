#!/usr/bin/perl
# Version 7.0.0.0      17-Jun-2021
#*******************************************************************************
#
# ShowPage.pl [PAGE_TEMPLATE] [ROOT] [OBJECT] [MENU] [WORD]
#
# ShowPage Command Line Input: -h for help
#
# PAGE_TEMPLATE overrides default template for the page
#
#*******************************************************************************
# History:
#   2021.06.17 earth.love oK Version 7 additions - direct OML function call
#   2021.06.16 earth.love oK Created
#*******************************************************************************
# Copyright 2021 Kevin Runner / Runchero Federation / PISA
#*******************************************************************************
# License: AGPLv3+: GNU Affero General Public License Version 3 or later
#*******************************************************************************
# This file is part of Orbit for Perl.
#
# Orbit for Perl is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Orbit for Perl is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with Orbit for Perl.  If not, see <https://www.gnu.org/licenses/>.
#*******************************************************************************
use strict;
use warnings;
use utf8;
use feature ':5.16';

# Use current directory to pick up other packages
use lib qw( ./lib ../lib );
# Version 7
use Orbit::Orbit7;
# Initialize Orbit, the big oh $O
my $O = Orbit->new();

#
# Define the primary parameters for Akashic earth.love pages
# Get the input parameters from command line or CGI

my $pPage     = shift;   # &p= &page=
my $pRoot     = shift;   # &r= &root=
my $pObject   = shift;   # &o= &object=
my $pMenu     = shift;   # &m= &menu=
my $pWord     = shift;   # &w= &word=

# Show usage for -h
ShowPageUsage() if (defined($pPage) && $pPage =~ /^-h.*/i);

# Initialize and see if parameters are coming from CGI
$O->SetParamTokens('p', 'page',   'PAGE',   $pPage)   if (defined($pPage) && $pPage ne "");
$O->SetParamTokens('r', 'root',   'ROOT',   $pRoot)   if (defined($pRoot) && $pRoot ne "");
$O->SetParamTokens('o', 'object', 'OBJECT', $pObject) if (defined($pObject) && $pObject ne "");
$O->SetParamTokens('m', 'menu',   'MENU',   $pMenu)   if (defined($pMenu) && $pMenu ne "");
$O->SetParamTokens('w', 'word',   'WORD',   $pWord)   if (defined($pWord) && $pWord ne "");

#
# Show the OML page
#
$O->ShowPage();

#********************
# EXAMPLES
#********************
#
# Testing and Debugging
# Show all the Tokens in the Orbit Hash
#
# $O->ShowTokenTable() if ($O->GetDebug() >= 20);

#
# Running from Command Line
# - Assign ShowPage output to a variable
#
# $O->SetCommandLineOn();
# $O->SetPrintOutputOff();
# my $pageOUT = $O->ShowPage($pPage);
# print $pageOUT;

#********************
# END EXAMPLES
#********************


exit 0;


################################################################################
#
# ShowPageUsage()
#
################################################################################
sub ShowPageUsage
{
  print "\n $0 [PAGE_TEMPLATE] [ROOT] [OBJECT] [MENU] [WORD]\n\n";

  print "  ShowPage Command Line Input\n\n";

  print "  PAGE_TEMPLATE overrides default template for the page\n\n";

  exit 1;
}
