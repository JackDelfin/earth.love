#!/usr/bin/perl
# Version 1.0.1.0      01-Jun-2021
#*******************************************************************************
#
# Akashic:myConfig.pm
#
# This is the user configuration section for the Akashic data structure
# that supports earth.love
#
#-------------------------------------------------------------------------------
# Sub-routines Included:
#-------------------------------------------------------------------------------
#
# UserConfigurations()
#   - Load the User Configurations
#   - This is called automatically in InitEarthLove during new() class creation
#
#*******************************************************************************
# History:
#   2021.05.20 earth.love oK Updated
#   2021.04.16 earth.love oK Created
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
package Akashic;

use strict;
use warnings;


################################################################################
#
# UserConfigurations()
#
# - Load the User Configurations
#
################################################################################
sub Akashic::UserConfigurations
{
  my ( $self ) = @_;
  my $var = "";
  ########################################
  # User Configurable Runtime parameters
  # - Or set as the environment variable
  ########################################
  #
  # Set ouptput level when a word has already been processed
  # Environment Variable: ELWORDFOUNDTEXT
  #
  #$self->SetVar('gWordFoundText', 'SILENT'); # keep it silent if word exists (default)
  $self->SetVar('gWordFoundText', 'BRIEF');  # keep it brief (just a . for each word that exists)
  #$self->SetVar('gWordFoundText', 'EXISTS'); # Show the word with "exists." for confirmation
  #$self->SetVar('gWordFoundText', 'SHOW');   # Show the word ONLY

  #
  # Redefine WORDS home directory name
  # Environment Variable: ELWORDS
  #
  #$self->SetVar('WORDS',     "_WORDS");
  #$self->SetVar('PHRASES',   "_PHRASES");
  #$self->SetVar('PATHS',     "_PATHS");
  #
  #$self->SetVar('TREES',     "_TREES");
  #$self->SetVar('TEMPLATES', "_TEMPLATES");
  #$self->SetVar('DATES',     "_DATES");
  #
  #$self->SetVar('WORDS',     "_MYWORDS");     # The MY Directory
  #$self->SetVar('PHRASES',   "_MYPHRASES");   # The MY Directory
  #$self->SetVar('PATHS',     "_MYPATHS");     # The MY Directory

  #
  # Set the earth.love "traditional" Domain Directory if not defined
  #

  ####  TESTING ####
  if (!-d $self->GetVar('DomainDir')) {
    if (-d $ENV{'EARTH_LOVE'}) {
      $self->SetVar('DomainDir', $ENV{'EARTH_LOVE'});
    }
    # Set to traditional path if not defined
    if (!-d $self->GetVar('DomainDir')) {
      $self->SetVar('DomainDir', "/LOVE/earth.love/") if (-d "/LOVE/earth.love");
    }
  }

  #LEGACY
  #if (!-d $self->GetVar('DomainDir')) {
  #  $self->SetVar('DomainDir', "D:/LOVE/earth.love/") if (-d "d:/LOVE/earth.love");  # TEST
  #  $self->SetVar('DomainDir', "C:/LOVE/earth.love_TEST/") if (-d "c:/LOVE/earth.love_TEST");  # TEST
  #  $self->SetVar('DomainDir', "C:/LOVE/earth.love_DEV/") if (-d "d:/LOVE/earth.love_DEV");  # DEV
  #}
  ####  TESTING ####

  # UNIX / Linux / MacOS
  #$self->SetVar('DomainDir', "/LOVE/earth.love_DEV/");  # DEVELOPMENT
  #$self->SetVar('DomainDir', "/LOVE/earth.love_TEST/"); # TEST
  #$self->SetVar('DomainDir', "/LOVE/earth.love/");      # PRODUCTION
  # Windows
  #$self->SetVar('DomainDir', "e:/LOVE/earth.love_DEV/");  # DEVELOPMENT
  #$self->SetVar('DomainDir', "e:/LOVE/earth.love_TEST/"); # TEST
  #$self->SetVar('DomainDir', "e:/LOVE/earth.love/");      # PRODUCTION

  # Get the ROOT name under the Domain Dir - get from environment ELROOT if defined
  $var = $ENV{'ELROOT'};
  $var = 'LANGS/ENG' if (!defined($var) || $var eq "");
  $self->SetVar('Root', $var);

  # Get the TREE name connected to the ROOT
  $var = $ENV{'ELTREE'};
  $var = 'INDEX' if (!defined($var) || $var eq "");
  $self->SetVar('Tree', $var);

  #
  # Configure the category logging if Filename represents the category
  #
  #$self->SetVar('CatFile', "CAT.dat");
  $self->SetVar('Category', "#FILEBASE#");

  # LinePhrase
  # ------------
  #   If set to 1, treats each line of the TextFiles as a phrase, storing it as such.
  #   Conditions:
  #     Phrase is no more than 80 characters and contains only VALID word punctuation.
  #     Spaces will be changed to underscore (_) for storage in the earth.love WORDS Library
  $self->SetVar('LinePhrase', "1");

  #
  # Optimization Settings
  #
  #$self->SetVar('SortData',   '0');   # Turn off SortData - Don't sort index data as new items added
  #$self->SetVar('ShowStats',  '0');   # Turn off ShowStats - Don't show statistics for processing
  #$self->SetVar('LogStats',   '0');   # Turn off LogStats - Don't even log statistics
  #$self->SetVar('ShowOutput', '0');   # Turn off ShowOutput - Don't show processing messages

  ########################################
  # END: User Configurable parameters
  ########################################

  return 1;
} #UserConfigurations


#******************************************************************************************
# Return true to show package was loaded with
# use Akashic:myConfig;
#******************************************************************************************
1;

#END Akashic:myConfig;
