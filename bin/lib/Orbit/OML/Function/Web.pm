#!/usr/bin/perl
# Version 7.0.2.0      23-Jan-2025
#*****************************************************************************************
#*
#* Orbit::OML::Function::Web - Version 7
#*
#*  Package Name    :   Orbit::OML:Function::Web
#*
#*  Description     :   Implements Orbit Markup Language (OML) for WEB Functions
#*
#*****************************************************************************************
# History:
#   2025.01.23 earth.love oK Version 7
#*****************************************************************************************
# Copyright 2025 Kevin Runner / Runchero Federation / PISA
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
#*****************************************************************************************
# OML Functions Supported
#*****************************************************************************************
# LoadWebFunctions
#   - Load the Web OML Functions into the _OML_FUNCTIONS subroutine reference array
#
# DISTANCE
# BEARING
#*****************************************************************************************
package Orbit;   # Continuation of Orbit package

use strict;
use warnings;
use utf8;
use feature ':5.16';


#-----------------------------------------------------------------------------
# LoadWebFunctions
#   - Load the Web OML Functions into the _OML_FUNCTIONS subroutine reference array
#
sub Orbit::LoadWebFunctions
{
  my ( $O ) = @_;
  $O->{_OML_FUNCTIONS}->{'COUNTRY'}    = sub { $O->omlCOUNTRY(), };
  $O->{_OML_FUNCTIONS}->{'HOSTNAME'}   = sub { $O->omlHOSTNAME(), };
  $O->{_OML_FUNCTIONS}->{'CURL'}       = sub { $O->omlCURL(), };
} #LoadWebFunctions
# Alias - Function Group Web 13
*LoadFunctionGroup12 = \&LoadWebFunctions;


#-----------------------------------------------------------------------------
#-- Check for the DISTANCE function - #DISTANCE[<lat,long>][<lat,long>][km]#
#--
sub Orbit::omlDISTANCE
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $U = $self->{_Utils};
  use Core::Web;
  use Core::Math::Round;
  #-- Get the coordinates
  my $a1 = $self->GetArgParse(1, @FunArgs);
  my $a2 = $self->GetArgParse(2, @FunArgs);
  my $a3 = $self->GetArgParse(3, @FunArgs);
  # Get the distance
  my $V = $U->round($U->Get_Distance($a1, $a2, $a3),2);
  # Free up our local Function Argument copy
  undef @FunArgs;
  return $V;
}


#-----------------------------------------------------------------------------
#-- Check for the BEARING function - #BEARING[<lat,long>][<lat,long>][directional]#
#-- - returns the bearing (direction)
sub Orbit::omlBEARING
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $U = $self->{_Utils};
  my $V = "";
  use Core::Distance;
  use Core::Math::Round;
  #-- Get the coordinates
  my $a1 = $self->GetArgParse(1, @FunArgs);
  my $a2 = $self->GetArgParse(2, @FunArgs);
  my $a3 = $self->GetArgParse(3, @FunArgs);
  # Get the Bearing
  if ($a3 ne '1') {
    $V = $U->round($U->Get_Bearing($a1, $a2),2);
  } else {
    $V = $U->Get_Bearing($a1, $a2, $a3);
  }

  # Free up our local Function Argument copy
  undef @FunArgs;
  return $V;
}


#******************************************************************************************
# Return true to show package was loaded with
# use Orbit::OML::Function::Web;
#******************************************************************************************
1;


#END Orbit::OML:Function::Web Package
