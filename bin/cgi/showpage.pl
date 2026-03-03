#!/usr/bin/perl
# Version 6.1.6.0      30-May-2021
#*******************************************************************************
#
# ShowPage.pl <WORD/PHRASE/PATH>  [ROOT]  [DOMAIN]  [LANGUAGE]  [PAGE_TEMPLATE]  [OBJECT]
#
# ShowPage Command Line Input: -h for help
#
# Shows the page for the WORD/PHRASE/PATH under the ROOT directory in DOMAIN.
#
# Example Directory in Akashic structure:
#   /LOVE/earth.love/LANGS/ENG/_WORDS/i/n/d/e/x/index
#     - DOMAIN: earth.love
#     - ROOT  : LANGS/ENG
#     - WORD  : index
#
# PAGE_TEMPLATE overrides default template for the page
#
#*******************************************************************************
# URL Syntax:
#   http://localhost/cgi-bin/showpage.pl?word=CityName&root=LOCS&domain=earth.love&page=SHOWCITY
# Shorthand:          http://localhost/cgi-bin/showpage.pl?w=CityName&r=LOCS&d=earth.love&p=SHOWCITY
#*******************************************************************************
# History:
#   2021.05.30 earth.love oK Updated
#   2021.04.23 earth.love oK Created
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
use Orbit;
# Initialize Orbit, the big oh $O
my $O = Orbit->new();

#
# Define the primary parameters for Akashic earth.love pages
# Get the input parameters from command line or CGI
my $pWord     = shift;   # &w= &word=
# Show usage for -h
ShowPageUsage() if (defined($pWord) && $pWord =~ /^-h.*/i);
my $pRoot     = shift;   # &r= &root=
my $pDomain   = shift;   # &d= &domain=
my $pLang     = shift;   # &l= &lang=
my $pPage     = shift;   # &p= &page=
my $pObject   = shift;   # &o= &object=

# Initialize and see if parameters are coming from CGI
$O->SetParamTokens('d', 'domain', 'DOMAIN', $pDomain) if (defined($pDomain) && $pDomain ne "");
$O->SetParamTokens('l', 'lang',   'LANG',   $pLang)   if (defined($pLang) && $pLang ne "");   # process LANG before ROOT
$O->SetParamTokens('r', 'root',   'ROOT',   $pRoot)   if (defined($pRoot) && $pRoot ne "");
$O->SetParamTokens('w', 'word',   'WORD',   $pWord)   if (defined($pWord) && $pWord ne "");
$O->SetParamTokens('p', 'page',   'PAGE',   $pPage)   if (defined($pPage) && $pPage ne "");
$O->SetParamTokens('o', 'object', 'OBJECT', $pObject) if (defined($pObject) && $pObject ne "");

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
  print "\n $0 <WORD/PHRASE/PATH>  [ROOT]  [DOMAIN]  [LANGUAGE]  [PAGE_TEMPLATE]  [OBJECT]\n\n";

  print "  ShowPage Command Line Input\n\n";

  print "  Shows the page for the WORD/PHRASE/PATH under the ROOT directory in DOMAIN.\n\n";

  print "  Example Directory in Akashic structure:\n";
  print "    /LOVE/earth.love/LANGS/ENG/_WORDS/i/n/d/e/x/index\n";
  print "      - DOMAIN: earth.love\n";
  print "      - ROOT  : LANGS/ENG\n";
  print "      - WORD  : index\n\n";

  print "  PAGE_TEMPLATE overrides default template for the page\n\n";

  print "  Common ROOTs: COMMS, LOCS, JOBS, GUILDS, LANGS, ORGS, PERSONS, etc.\n";
  print "                  LANGS/ENG by default\n\n";

  exit 1;
}
