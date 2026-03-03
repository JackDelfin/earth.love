#!/usr/bin/perl
# Version 1.0.1.0      01-Jun-2021
#*******************************************************************************
#
# Orbit::myConfig.pm
#
# User configuration for Orbit
#
#-------------------------------------------------------------------------------
# Sub-routines Included:
#-------------------------------------------------------------------------------
#
# UserConfigurations()
#   - Load the User Configurations
#   - This should be called prior to Orbit::ShowPage
#
#*******************************************************************************
# History:
#   2021.05.30 earth.love oK Created
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
package Orbit;

use strict;
use warnings;

#
# Include the Orbit/Akashic connection
#
use Orbit::Akashic;


################################################################################
#
# UserConfigurations()
#
# - Load the User Configurations
#
################################################################################
sub Orbit::UserConfigurations
{
  my ( $self ) = @_;
  ########################################
  # User Configurable Runtime parameters
  ########################################

  #
  # Set Template Directories
  #
  # If no location is specified, the default template paths will be searched.

  # earth.love default TEMPLATES
  #LEGACY
  #if (-d '/LOVE/earth.love/_TEMPLATES/') {
  #  $self->SetTemplateDir('/LOVE/earth.love/_TEMPLATES/');
  #}

  # Development / Command-Line:
  #LEGACY
  #$self->SetTemplateDir('./_TEMPLATES/');            # _TEMPLATES off current directory always take precedence
  #$self->SetTemplateDir('./_TEMPLATES/#_ROOT_#/');   # Root Library of Templates
  
  # Production
  $self->SetTemplateDir('#_ROOTDIR_#/_TEMPLATES/');         # Root Specific Templates
  $self->SetTemplateDir('#_DOMAINDIR_#/_ROOT/_TEMPLATES/'); # Domain Specific Templates
  $self->SetTemplateDir('#_DOMAINDIR_#/_TEMPLATES/');       # Default Templates
  
  # Future Functionality - Words have their own Template Directory
  #$self->SetTemplateDir('#_WORDDIR_#/_TEMPLATES/');
  #$self->SetTemplateDir('#_WORDDIR_#/');
  
  #
  # BATCH PROCESSING SWITCHES
  #
  #$self->SetBatchMode(0);
  #   - Set the _bBatchMode flag to indicate a batch process is running
  #   - This disables SHOWSTATS and LOGSTATS OML Functions within pages
  #   - The token _STATIC_ is set to 1 so you can use
  #     the #DOTDOT# Token to get the relative path to the Domain Root.
  #$self->SetCommandLineOn;     # Set the Output type to Command Line for debugging - don't show HTTP header
  #$self->SetCommandLineOff;    # Set the Command Line Off - show HTTP header
  #$self->SetPrintOutputOn;     # Set the Output On for normal operation
  #$self->SetPrintOutputOff;    # Set the Output Off for Show_Page - Show_Page will exit without displaying anything
                                # - useful for buffering output in _Output
  #$self->SetStaticPage('EL_SHOW_STATIC');     # Sets the Static Page Variable within Orbit for Batch Processing
  #$self->SetStaticHost('http://earth.love');  # Sets the Static Host Variable within Orbit for Batch Processing
  #$self->SetStaticHost('http://localhost');   # TESTING
  $self->SetStaticContext('/o/');             # Sets the Static Context Prefix Variable (cgi-bin) within Orbit for Batch Processing
  
  #
  # OML COMMENTS - Turn OML Comments On/Off programatically
  #
  #$self->SetShowCommentsOn;    # Set the Show OML Comments control ON
  #$self->SetShowCommentsOff;   # Set the Show OML Comments control OFF
  
  #
  # CACHE OUTPUT
  #
  #$self->SetCacheOutput(1);    # Set the Cache Output On or Off for a page generation
  
  #
  # DEBUG SWITCHES
  #
  #$self->SetDebugOn;           # Set the Debug mode ON at the specified debug level (max 20 = most detailed)
  #$self->SetDebugOff;          # Set the Debug mode OFF

  ########################################
  # END: User Configurable parameters
  ########################################

  #***************************************
  # Initialize the Akashic data structure
  #***************************************
  #
  $self->initOrbitAkashic();

  # Create new CoreUtils if not assigned in Akashic (shared nature of CoreUtils)
  $self->{_Utils} = CoreUtils->new() if (!defined($self->{_Utils}));

  # Turn off statistics by default for Orbit - keep package defaults
  #$O->SetShowStats(0);   # For batch processing Show Stats or not
  #$O->SetLogStats(0);    # Log some cool page and word statistics
  #$O->SetShowOutput(1);  # Print or Buffer

  return 1;
} #UserConfigurations


#******************************************************************************************
# Return true to show package was loaded with
# use Orbit::myConfig.pm;
#******************************************************************************************
1;

#END Orbit::myConfig.pm;
