#!/usr/bin/perl
# Version 1.0.1.0      09-Jun-2021
#*******************************************************************************
#
# Orbit::Akashic::Del.pm
#
# Orbit configuration for Akashic Data Processing
#
#   ProcessDelete
#
#*******************************************************************************
# History:
#   2021.06.09 earth.love oK Created
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
# Load the Akashic core and Utilities, and Earth addons
#
use Akashic::Write;


################################################################################
#
# ProcessDelete()
#
# - Process Akashic Delete transactions
#
################################################################################
sub Orbit::ProcessDelete
{
  my ( $self ) = @_;
  my $O = $self;
  my $A = $O->{_Akashic};
  my $U = $A->{_Utils};
  my $page = $O->Get_Token('PAGE');
  $page    = 'el_del' if ($page eq "");

  # Buffer the print output for Akashic package
  $self->BufUprint(1);

  # Set the page to display
  $O->Set_Token('PAGE', $page);
  return $page;
} #ProcessDelete


#******************************************************************************************
# Return true to show package was loaded with
# use Orbit::Akashic::Del;
#******************************************************************************************
1;

#END Orbit::Akashic::Del;
