#!/usr/bin/perl
# Version 7.0.0.0      17-Jun-2021
#*****************************************************************************************
#*
#* Orbit::OML::Function::Numeric - Version 7
#*
#*  Package Name    :   Orbit::OML:Function::Numeric
#*
#*  Description     :   Implements Orbit Markup Language (OML) for NUMERIC Functions
#*
#*****************************************************************************************
# History:
#   2021.06.17 earth.love oK Version 7
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
# LoadNumericFunctions
#   - Load the Numeric OML Functions into the _OML_FUNCTIONS subroutine reference array
#
# GREATERTHAN    GT
# LESSTHAN       LT
# GREATEREQUAL   GE
# LESSEQUAL      LE
# BETWEEN
#*****************************************************************************************
package Orbit;   # Continuation of Orbit package

use strict;
use warnings;
use utf8;
use feature ':5.16';


#-----------------------------------------------------------------------------
# LoadNumericFunctions
#   - Load the Numeric OML Functions into the _OML_FUNCTIONS subroutine reference array
#
sub Orbit::LoadNumericFunctions
{
  my ( $O ) = @_;
  $O->{_OML_FUNCTIONS}->{'GT'}          = sub { $O->omlGT(), };
  $O->{_OML_FUNCTIONS}->{'GREATERTHAN'} = sub { $O->omlGT(), };
  $O->{_OML_FUNCTIONS}->{'LT'}          = sub { $O->omlLT(), };
  $O->{_OML_FUNCTIONS}->{'LESSTHAN'}    = sub { $O->omlLT(), };
  $O->{_OML_FUNCTIONS}->{'GE'}          = sub { $O->omlGE(), };
  $O->{_OML_FUNCTIONS}->{'GREATEREQUAL'}= sub { $O->omlGE(), };
  $O->{_OML_FUNCTIONS}->{'LE'}          = sub { $O->omlLE(), };
  $O->{_OML_FUNCTIONS}->{'LESSEQUAL'}   = sub { $O->omlLE(), };
  $O->{_OML_FUNCTIONS}->{'BETWEEN'}     = sub { $O->omlBETWEEN(), };
} #LoadNumericFunctions
# Alias - Function Group Numeric 02
*LoadFunctionGroup02 = \&LoadNumericFunctions;


#-----------------------------------------------------------------------------
#-- Check for the GREATERTHAN / GT function - #GREATERTHAN[val1][val2][then][else]#
#-- Aliases: GREATERTHAN
sub Orbit::omlGT
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $U = $self->{_Utils};
  #-- Get the base text ($V)
  my $V = $self->GetArgParse(1, @FunArgs);
  my $a1 = $self->GetArgParse(2, @FunArgs); #--val2
  if ($self->IsArg(2, @FunArgs)) {
    #-- get the <then> condition
    #-- See if val1 and val2 are numeric
    my $N = $U->GetNumber($V,1);
    my $na1 = $U->GetNumber($a1,1);
    if ($N ne "" && $na1 ne "") {
      #-- Do a numeric based comparison
      #-- see if the <then> was specified
      if ($self->IsArg(3, @FunArgs)) {   #--then
        #-- See if the <val1> is greater than <val2>
        if ($N > $na1) {
          #-- Expression was true, so value is the <then> part of the expression
          $V = $self->GetArgParse(3, @FunArgs); #--then
        } else {
          #-- Expression was false, so value is the <else> part of the expression
          $V = $self->GetArgParse(4, @FunArgs);
        }
      } else {   #-- no) {/else - use standard functionality
        #-- Do a numeric based comparison
        if ($N > $na1) {
          $V = '1';
        } else {
          $V = '0';
        }
      }
    } else {
      #-- Do a text based comparison
      #-- see if the <then> was specified
      if ($self->IsArg(3, @FunArgs)) {
        #-- See if the <val1> is greater than <val2>
        if ($V > $a1) {
          #-- Expression was true, so value is the <then> part of the expression
          $V = $self->GetArgParse(3, @FunArgs); #--then
        } else {
          #-- Expression was false, so value is the <else> part of the expression
          $V = $self->GetArgParse(4, @FunArgs);
        }
      } else {   #-- no) {/else - use standard functionality
        #-- Do a text based comparison
        if ($V > $a1) {
          $V = '1';
        } else {
          $V = '0';
        }
      }
    }
  } else {
    $V = $self->GetFunctionError('GREATERTHAN');
  }
  # Free up our local Function Argument copy
  undef @FunArgs;
  return $V;
}


#-----------------------------------------------------------------------------
#-- Check for the LESSTHAN / LT function - #LESSTHAN[val1][val2][then][else]#
#-- Aliases: LESSTHAN
sub Orbit::omlLT
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $U = $self->{_Utils};
  #-- Get the base text ($V)
  my $V = $self->GetArgParse(1, @FunArgs);
  my $a1 = $self->GetArgParse(2, @FunArgs); #--val2
  if ($self->IsArg(2, @FunArgs)) {
    #-- get the <then> condition
    #-- See if val1 and val2 are numeric
    my $N = $U->GetNumber($V,1);
    my $na1 = $U->GetNumber($a1,1);
    if ($N ne "" and $na1 ne "") {
      #-- Do a numeric based comparison
      #-- see if the <then> was specified
      if ($self->IsArg(3, @FunArgs)) {   #--then
        #-- See if the <val1> is less than <val2>
        if ($N < $na1) {
          #-- Expression was true, so value is the <then> part of the expression
          $V = $self->GetArgParse(3, @FunArgs); #--then
        } else {
          #-- Expression was false, so value is the <else> part of the expression
          $V = $self->GetArgParse(4, @FunArgs);
        }
      } else {   #-- no) {/else - use standard functionality
        #-- Do a numeric based comparison
        if ($N < $na1) {
          $V = '1';
        } else {
          $V = '0';
        }
      }
    } else {
      #-- Do a text based comparison
      #-- see if the <then> was specified
      if ($self->IsArg(2, @FunArgs)) {
        #-- See if the <val1> is less than <val2>
        if ($V < $a1) {
          #-- Expression was true, so value is the <then> part of the expression
          $V = $self->GetArgParse(3, @FunArgs); #--then
        } else {
          #-- Expression was false, so value is the <else> part of the expression
          $V = $self->GetArgParse(4, @FunArgs);
        }
      } else {   #-- no) {/else - use standard functionality
        #-- Do a text based comparison
        if ($V < $a1) {
          $V = '1';
        } else {
          $V = '0';
        }
      }
    }
  } else {
    $V = $self->GetFunctionError('LESSTHAN');
  }
  # Free up our local Function Argument copy
  undef @FunArgs;
  return $V;
}


#-----------------------------------------------------------------------------
#-- Check for the GREATEREQUAL / GE function - #GREATEREQUAL[val1][val2][then][else]#
#-- Aliases: GREATEREQUAL
sub Orbit::omlGE
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $U = $self->{_Utils};
  #-- Get the base text ($V)
  my $V = $self->GetArgParse(1, @FunArgs);
  my $a1 = $self->GetArgParse(2, @FunArgs); #--val2
  if ($self->IsArg(2, @FunArgs)) {
    #-- get the <then> condition
    #-- See if val1 and val2 are numeric
    my $N = $U->GetNumber($V,1);
    my $na1 = $U->GetNumber($a1,1);
    if ($N ne "" and $na1 ne "") {
      #-- Do a numeric based comparison
      #-- see if the <then> was specified
      if ($self->IsArg(3, @FunArgs)) { #--then
        #-- See if the <val1> is greater than or equal <val2>
        if ($N >= $na1) {
          #-- Expression was true, so value is the <then> part of the expression
          $V = $self->GetArgParse(3, @FunArgs); #--then
        } else {
          #-- Expression was false, so value is the <else> part of the expression
          $V = $self->GetArgParse(4, @FunArgs);
        }
      } else {   #-- no) {/else - use standard functionality
        #-- Do a numeric based comparison
        if ($N >= $na1) {
          $V = '1';
        } else {
          $V = '0';
        }
      }
    } else {
      #-- Do a text based comparison
      #-- see if the <then> was specified
      if ($self->IsArg(2, @FunArgs)) {
        #-- See if the <val1> is greater than or equal <val2>
        if ($V >= $a1) {
          #-- Expression was true, so value is the <then> part of the expression
          $V = $self->GetArgParse(3, @FunArgs); #--then
        } else {
          #-- Expression was false, so value is the <else> part of the expression
          $V = $self->GetArgParse(4, @FunArgs);
        }
      } else {   #-- no) {/else - use standard functionality
        #-- Do a text based comparison
        if ($V >= $a1) {
          $V = '1';
        } else {
          $V = '0';
        }
      }
    }
  } else {
    $V = $self->GetFunctionError('GREATEREQUAL');
  }
  # Free up our local Function Argument copy
  undef @FunArgs;
  return $V;
}


#-----------------------------------------------------------------------------
#-- Check for the LESSEQUAL / LE function - #LESSEQUAL[val1][val2][then][else]#
#-- Aliases: LESSEQUAL
sub Orbit::omlLE
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $U = $self->{_Utils};
  #-- Get the base text ($V)
  my $V = $self->GetArgParse(1, @FunArgs);
  my $a1 = $self->GetArgParse(2, @FunArgs); #--val2
  if ($self->IsArg(2, @FunArgs)) {
    #-- get the <then> condition
    #-- See if val1 and val2 are numeric
    my $N = $U->GetNumber($V,1);
    my $na1 = $U->GetNumber($a1,1);
    if ($N ne "" and $na1 ne "") {
      #-- Do a numeric based comparison
      #-- see if the <then> was specified
      if ($self->IsArg(3, @FunArgs)) { #--then
        #-- See if the <val1> is less than or equal <val2>
        if ($N <= $na1) {
          #-- Expression was true, so value is the <then> part of the expression
          $V = $self->GetArgParse(3, @FunArgs); #--then
        } else {
          #-- Expression was false, so value is the <else> part of the expression
          $V = $self->GetArgParse(4, @FunArgs);
        }
      } else {   #-- no) {/else - use standard functionality
        #-- Do a numeric based comparison
        if ($N <= $na1) {
          $V = '1';
        } else {
          $V = '0';
        }
      }
    } else {
      #-- Do a text based comparison
      #-- see if the <then> was specified
      if ($self->IsArg(2, @FunArgs)) {
        #-- See if the <val1> is less than or equal <val2>
        if ($V <= $a1) {
          #-- Expression was true, so value is the <then> part of the expression
          $V = $self->GetArgParse(3, @FunArgs); #--then
        } else {
          #-- Expression was false, so value is the <else> part of the expression
          $V = $self->GetArgParse(4, @FunArgs);
        }
      } else {   #-- no) {/else - use standard functionality
        #-- Do a text based comparison
        if ($V <= $a1) {
          $V = '1';
        } else {
          $V = '0';
        }
      }
    }
  } else {
    $V = $self->GetFunctionError('LESSEQUAL');
  }
  # Free up our local Function Argument copy
  undef @FunArgs;
  return $V;
}


#-----------------------------------------------------------------------------
#-- Check for the BETWEEN function - #BETWEEN[compare][val1][val2].[then].[else]#
#-- - returns 1 if <compare> is between <val1> and <val2>
sub Orbit::omlBETWEEN
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $U = $self->{_Utils};
  my $V = "";
  my $na1      = 0;
  my $na2      = 0;
  my $na3      = 0;
  #-- Get the compare text ($a1)
  my $a1 = $self->GetArgParse(1, @FunArgs);
  my $a2 = $self->GetArgParse(2, @FunArgs);
  my $a3 = $self->GetArgParse(3, @FunArgs);
  if ($self->IsArg(3, @FunArgs)) {
    #-- try to get the <then> text
    #-- try to convert the parameters to numbers for numeric between compare
    if  ( $a1 ne ""
       || $a2 ne ""
       || $a3 ne "") {
      $na1 = $U->GetNumber($a1,1);
      $na2 = $U->GetNumber($a2,1);
      $na3 = $U->GetNumber($a3,1);
    }
    if (  ($na1 eq "" && $a1 ne "")
       || ($na2 eq "" && $a2 ne "")
       || ($na3 eq "" && $a3 ne "")
       ) {
      #-- Do a character comparison
      if ($self->IsArg(4, @FunArgs) == 1) { #--then
        #-- use the specified <then><else> text
        if ( $a1 ge $a2
          && $a1 le $a3
          ) {
          $V = $self->GetArgParse(4, @FunArgs); #--then
        } else {
          #-- get the else from the last parameter
          $V = $self->GetArgParse(5, @FunArgs);
        }
      } else {   #-- no) {/else - use standard functionality
        if ( $a1 ge $a2
          && $a1 le $a3
          ) {
          $V = '1';
        } else {
          $V = '0';
        }
      }
    } else {
      #-- Do a numeric comparison
      if ($self->IsArg(4, @FunArgs)) {
        #-- use the specified <then><else> text
        if ( $na1 >= $na2
          && $na1 <= $na3
          ) {
          $V = $self->GetArgParse(4, @FunArgs); #--then
        } else {
          #-- get the else from the last parameter
          $V = $self->GetArgParse(5, @FunArgs);
        }
      } else {   #-- no) {/else - use standard functionality
        if ($na1 >= $na2
          && $na1 <= $na3
          ) {
          $V = '1';
        } else {
          $V = '0';
        }
      }
    }
  } else {
    $V = $self->GetFunctionError('BETWEEN');
  }
  # Free up our local Function Argument copy
  undef @FunArgs;
  return $V;
}


#******************************************************************************************
# Return true to show package was loaded with
# use Orbit::OML::Function::Numeric;
#******************************************************************************************
1;


#END Orbit::OML:Function::Numeric Package
