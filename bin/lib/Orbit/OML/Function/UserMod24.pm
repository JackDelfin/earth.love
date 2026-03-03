#!/usr/bin/perl
# Version 7.0.0.0      1-Jul-2021
#*****************************************************************************************
#*
#* Orbit::OML::Function::UserMod24
#*
#* - Implements Orbit Markup Language (OML) for UserMod24 Functions
#* - These are User defined functions.
#* - Example code is setup below... Enjoy!
#*
#*****************************************************************************************
# History:
#   2021.07.01 earth.love oK Created
#*****************************************************************************************
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
#*****************************************************************************************
# OML Functions Supported
#*****************************************************************************************
# LoadFunctionGroup24
#   - Load the UserMod24 OML Functions
#
# FUNCTION1
# FUNCTION2
#*****************************************************************************************
package Orbit;   # Continuation of Orbit package

use strict;
use warnings;
use utf8;
use feature ':5.16';


#-----------------------------------------------------------------------------
# LoadFunctionGroup24
#   - Load the UserMod24 OML Functions
#
sub Orbit::LoadFunctionGroup24
{
  my ( $O ) = @_;
  # Specify the OML Functions enclosed here
  # Perhaps choose a specific prefix to avoid conflict with other user functions
  # EXAMPLE OML FUNCTION
  #$O->{_OML_FUNCTIONS}->{'FUNCTION24'} = sub { $O->omlFUNCTION24(), };
  #$O->{_OML_FUNCTIONS}->{'FUNCTION24B'} = sub { $O->omlFUNCTION24B(), };

  # EXAMPLE TOKEN MODIFIER - token modifiers are in LOWERcase
  #$O->{_TOKEN_MODIFIERS}->{'func24'}    = sub { $O->modFUNC24(), };

} #LoadFunctionGroup24


#-----------------------------------------------------------------------------
#-- Example:
#-----------------------------------------------------------------------------
#-- omlFUNCTION24
#--   - Description
#--
#-- Call: #FUNCTION24[arg1][arg2][arg3]#
#-----------------------------------------------------------------------------
#sub Orbit::omlFUNCTION24
#{
#  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
#  my @FunArgs = $self->GetFunctionArgsArray();
  # Uncomment out below if needed
  #my $OneArg   = $self->GetArguments();   # Get one argument only as text
  #my $Token    = $self->{_Token};         # Get Token Name (certain functions)
  #my $Function = $self->{_Function};      # Get Function name (certain functions, usually for aliases or overloads)
  #my $bFlush   = $self->{_bFlush};
#  my $U = $self->{_Utils};
#  my $V = "";   # Return value

  #***************************************
  # START USER CODE
  #***************************************
  #
  #


  # FUNCTION IMPLEMENTATION
 # $V = "My Function";


  #
  #
  #***************************************
  # END USER CODE
  #***************************************

  # Free up our local Function Argument copy
#  undef @FunArgs;
#  return $V;
#} #omlFUNCTION24

#-----------------------------------------------------------------------------
#-- Example: User Defined TOKEN MODIFIER
#-----------------------------------------------------------------------------
#-- modFUNC24
#--   - Description
#--
#-- Call: #token.FUNC24#
#-----------------------------------------------------------------------------
#sub Orbit::modFUNC24 {
#  my ( $O ) = @_;
#  $O->{_TokVal} = "My Token Modifier";
#} #modFUNC24

#******************************************************************************************
# Return true to show package was loaded with
# use Orbit::OML::Function::UserMod24;
#******************************************************************************************
1;


#END Orbit::OML:Function::UserMod24
