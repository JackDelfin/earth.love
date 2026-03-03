#!/usr/bin/perl
# Version 7.0.0.0      17-Jun-2021
#*****************************************************************************************
#*
#* Orbit::OML::Function::Math - Version 7
#*
#*  Package Name    :   Orbit::OML:Function::Math
#*
#*  Description     :   Implements Orbit Markup Language (OML) for MATH Functions
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
# LoadMathFunctions
#   - Load the Math OML Functions into the _OML_FUNCTIONS subroutine reference array
#
# ROUND
# TRUNC
# SIGN
# ABS
# MOD
# ADD
# SUBTRACT   SUB
# MULTIPLY   MULT
# DIVIDE     DIV
# MIN
# MAX
# AVG
# RAND RANDOM
# FIBONACCI
#*****************************************************************************************
package Orbit;   # Continuation of Orbit package

use strict;
use warnings;
use utf8;
use feature ':5.16';


#-----------------------------------------------------------------------------
# LoadMathFunctions
#   - Load the Math OML Functions into the _OML_FUNCTIONS subroutine reference array
#
sub Orbit::LoadMathFunctions
{
  my ( $O ) = @_;
  $O->{_OML_FUNCTIONS}->{'ROUND'}       = sub { $O->omlROUND(), };
  $O->{_OML_FUNCTIONS}->{'TRUNC'}       = sub { $O->omlTRUNC(), };
  $O->{_OML_FUNCTIONS}->{'SIGN'}        = sub { $O->omlSIGN(), };
  $O->{_OML_FUNCTIONS}->{'ABS'}         = sub { $O->omlABS(), };
  $O->{_OML_FUNCTIONS}->{'MOD'}         = sub { $O->omlMOD(), };
  $O->{_OML_FUNCTIONS}->{'ADD'}         = sub { $O->omlADD(), };
  $O->{_OML_FUNCTIONS}->{'SUB'}         = sub { $O->omlSUB(), };
  $O->{_OML_FUNCTIONS}->{'SUBTRACT'}    = sub { $O->omlSUB(), };
  $O->{_OML_FUNCTIONS}->{'MULT'}        = sub { $O->omlMULT(), };
  $O->{_OML_FUNCTIONS}->{'MULTIPLY'}    = sub { $O->omlMULT(), };
  $O->{_OML_FUNCTIONS}->{'DIV'}         = sub { $O->omlDIV(), };
  $O->{_OML_FUNCTIONS}->{'DIVIDE'}      = sub { $O->omlDIV(), };
  $O->{_OML_FUNCTIONS}->{'MIN'}         = sub { $O->omlMIN(), };
  $O->{_OML_FUNCTIONS}->{'MAX'}         = sub { $O->omlMAX(), };
  $O->{_OML_FUNCTIONS}->{'AVG'}         = sub { $O->omlAVG(), };
  $O->{_OML_FUNCTIONS}->{'RAND'}        = sub { $O->omlRAND(), };
  $O->{_OML_FUNCTIONS}->{'RANDOM'}      = sub { $O->omlRAND(), };
  $O->{_OML_FUNCTIONS}->{'FIBONACCI'}   = sub { $O->omlFIBONACCI(), };
} #LoadMathFunctions
# Alias - Function Group Math 04
*LoadFunctionGroup04 = \&LoadMathFunctions;


#-----------------------------------------------------------------------------
#-- Check for the ROUND function - #ROUND[<number>][<decimals>]#
#--
sub Orbit::omlROUND
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $U = $self->{_Utils};
  use Core::Math::Round;
  #-- Get the base text ($V)
  my $V = $self->GetArgParse(1, @FunArgs);
  my $N = $U->GetNumber($V,1);
  my $a1 = $self->GetArgParse(2, @FunArgs);
  my $na1 = $U->NVL($U->GetNumber($a1,1), 0);
  $V = $U->round($N, $na1);

  # Free up our local Function Argument copy
  undef @FunArgs;
  return $V;
}


#-----------------------------------------------------------------------------
#-- Check for the TRUNC function - #TRUNC[<number>][<decimals>]#
#--
sub Orbit::omlTRUNC
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $U = $self->{_Utils};
  use Core::Math::Round;
  #-- Get the base text ($V)
  my $V = $self->GetArgParse(1, @FunArgs);
  my $N = $U->GetNumber($V,1);
  my $a1 = $self->GetArgParse(2, @FunArgs);
  my $na1 = $U->NVL($U->GetNumber($a1,1), 0);
  $V = $U->trunc($N, $na1);
  # Free up our local Function Argument copy
  undef @FunArgs;
  return $V;
}


#-----------------------------------------------------------------------------
#-- Check for the SIGN function - #SIGN[<number>]#
#--
sub Orbit::omlSIGN
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $U = $self->{_Utils};
  use Core::Math;
  #-- Get the base text ($V)
  my $V = $self->GetArgParse(1, @FunArgs);
  my $N = $U->GetNumber($V,1);
  $V = $U->sign($N);
  # Free up our local Function Argument copy
  undef @FunArgs;
  return $V;
}


#-----------------------------------------------------------------------------
#-- Check for the ABS function - #ABS[<number>]#
#--
sub Orbit::omlABS
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $U = $self->{_Utils};
  #-- Get the base text ($V)
  my $V = $self->GetArgParse(1, @FunArgs);
  my $N = $U->GetNumber($V,1);
  $V = abs($N);
  # Free up our local Function Argument copy
  undef @FunArgs;
  return $V;
}


#-----------------------------------------------------------------------------
#-- Check for the MOD function - #MOD[<m>][<n>]#
#--
sub Orbit::omlMOD
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $U = $self->{_Utils};
  use Core::Math;
  #-- Get the base text ($V)
  my $V = $self->GetArgParse(1, @FunArgs);
  my $N = $U->GetNumber($V,1);
  my $a1 = $self->GetArgParse(2, @FunArgs);
  if ($self->IsArg(2, @FunArgs)) {
    my $na1 = $U->NVL($U->GetNumber($a1,1), 0);
    if ($na1 == 0) {
      #-- don't divide by 0
      $V = '';
    } else {
      $V = $U->mod($N, $na1);
    }
  } else {
    $V = $self->GetFunctionError('MOD');
  }
  # Free up our local Function Argument copy
  undef @FunArgs;
  return $V;
}


#-----------------------------------------------------------------------------
#-- Check for the ADD function - #ADD[<a>][<b>]...[<n>]#
#--
sub Orbit::omlADD
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $U = $self->{_Utils};
  #-- Get the first argument
  my $N = '';
  my $V = $self->GetArgParse(1, @FunArgs);
  $N = $U->GetNumber($V,1);
  my $na1 = 0;
  my $I = 2;
  my $a1 = "";
  while (1) {
    #-- Get the next argument
    $a1 = $self->GetArgParse($I, @FunArgs);
    #-- leave if no more arguments or the argument count exceeds 500
    last if   (!$self->IsArg($I, @FunArgs)
              || $I > 500);
    $na1 = $U->GetNumber($a1,1);
    #-- ADD the values
    if ($N ne "" && $na1 ne "") {
      $N = $N + $na1;
    } else {
      $N = '';   # non number found, so return blank for operation
      last;
    }
    #-- increment the index
    $I = $I + 1;
  }
  $V = $N;
  # Free up our local Function Argument copy
  undef @FunArgs;
  return $V;
}


#-----------------------------------------------------------------------------
#-- Check for the SUBTRACT function - #SUB[<a>][<b>]...[<n>]#
#-- Aliases: SUBTRACT
sub Orbit::omlSUB
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $U = $self->{_Utils};
  #-- Get the first argument
  my $N = '';
  my $V = $self->GetArgParse(1, @FunArgs);
  my $a1 = "";
  $N = $U->GetNumber($V,1);
  my $na1 = 0;
  my $I = 2;
  while (1) {
    #-- Get the next argument
    $a1 = $self->GetArgParse($I, @FunArgs);
    #-- leave if no more arguments or the argument count exceeds 500
    last if    (!$self->IsArg($I, @FunArgs)
              || $I > 500);
    $na1 = $U->GetNumber($a1,1);
    #-- SUBTRACT the values
    if ($N ne "" && $na1 ne "") {
      $N = $N - $na1;
    } else {
      $N = '';   # non number found, so return blank for operation
      last;
    }
    #-- increment the index
    $I = $I + 1;
  }
  $V = $N;
  # Free up our local Function Argument copy
  undef @FunArgs;
  return $V;
}


#-----------------------------------------------------------------------------
#-- Check for the MULTIPLY function - #MULT[<a>][<b>]...[<n>]#
#-- Aliases: MULTIPLY
sub Orbit::omlMULT
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $U = $self->{_Utils};
  #-- Get the first argument
  my $N = '';
  my $V = $self->GetArgParse(1, @FunArgs);
  my $a1 = "";
  $N = $U->GetNumber($V,1);
  my $na1 = 0;
  # Make sure number exists
  if ($N ne '') {
    my $I = 2;
    while (1) {
      #-- Get the next argument
      $a1 = $self->GetArgParse($I, @FunArgs);
      #-- leave if no more arguments or the argument count exceeds 500
      last if    (!$self->IsArg($I, @FunArgs)
                || $I > 500);
      $na1 = $U->GetNumber($a1,1);
      # Make sure number exists
      if ($na1 ne '') {
        #-- MULTIPLY the values
        $N = $N * $na1;
      } else {
        $N = '';   # non number found, so return blank for operation
        last;
      }
      #-- increment the index
      $I = $I + 1;
    }
  }
  $V = $N;
  # Free up our local Function Argument copy
  undef @FunArgs;
  return $V;
}


#-----------------------------------------------------------------------------
#-- Check for the DIVIDE function - #DIV[<a>][<b>]...[<n>]#
#-- Aliases: DIVIDE
sub Orbit::omlDIV
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $U = $self->{_Utils};
  #-- Get the first argument
  my $N = '';
  my $V = $self->GetArgParse(1, @FunArgs);
  my $a1 = "";
  $N = $U->GetNumber($V,1);
  my $na1 = 0;
  my $I = 2;
  while (1) {
    #-- Get the next argument
    $a1 = $self->GetArgParse($I, @FunArgs);
    #-- leave if no more arguments or the argument count exceeds 500
    last if    (!$self->IsArg($I, @FunArgs)
              || $I > 500);
    $na1 = $U->GetNumber($a1,1);
    #-- DIVIDE the values
    if ($na1 ne '0' && $N ne "" && $na1 ne "") {
      $N = $N / $na1;
    } else {
      # Divide by 0
      $N = '';
      last;
    }
    #-- increment the index
    $I = $I + 1;
  }
  $V = $N;
  # Free up our local Function Argument copy
  undef @FunArgs;
  return $V;
}


#-----------------------------------------------------------------------------
#-- Check for the MIN function - #MIN[<a>][<b>]...[<n>]#
#--
sub Orbit::omlMIN
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $U = $self->{_Utils};
  #-- initialize loop variables
  my $N = '';
  my $V = '';
  my $a1 = "";
  my $na1 = 0;
  my $lb_numeric = 1;
  my $I = 1;
  #-- loop through all arguments
  while (1) {
    #-- Get the next argument
    $a1 = $self->GetArgParse($I, @FunArgs);
    #-- leave if no more arguments or the argument count exceeds 500
    last if    (!$self->IsArg($I, @FunArgs)
              || $I > 500);
    #-- only do numeric comparisons if text argument not yet found
    if ($lb_numeric) {
      $na1 = $U->GetNumber($a1,1);
      #-- switch to text based comparison if a non-numeric is found
      if ($na1 eq "" && $a1 ne "") {
        $lb_numeric = 0;
      #-- remember smaller of $N and $na1
      } elsif  (  $N eq ""
               || $N > $na1
               ) {
        $N = $na1;
      }
    }
    #-- always do text comparisons, in case text argument later found
    if (  $V eq ""
       || $V > $a1) {
      $V = $a1;
    }
    #-- increment the index
    $I = $I + 1;
  }
  #-- return numeric or text minimum as appropriate
  if ($lb_numeric) {
    $V = $N;
  }
  # Free up our local Function Argument copy
  undef @FunArgs;
  return $V;
}


#-----------------------------------------------------------------------------
#-- Check for the MAX function - #MAX[<a>][<b>]...[<n>]#
#--
sub Orbit::omlMAX
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $U = $self->{_Utils};
  #-- initialize loop variables
  my $N = '';
  my $V = '';
  my $na1 = 0;
  my $a1 = "";
  my $lb_numeric = 1;
  my $I = 1;
  #-- loop through all arguments
  while (1) {
    #-- Get the next argument
    $a1 = $self->GetArgParse($I, @FunArgs);
    #-- leave if no more arguments or the argument count exceeds 500
    last if    (!$self->IsArg($I, @FunArgs)
              || $I > 500);
    #-- only do numeric comparisons if text argument not yet found
    if ($lb_numeric) {
      $na1 = $U->GetNumber($a1,1);
      #-- switch to text based comparison if a non-numeric is found
      if ($na1 eq "" && $a1 ne "") {
        $lb_numeric = 0;
      #-- remember larger of $N and $na1
      } elsif (   $N eq ""
               || $N < $na1) {
        $N = $na1;
      }
    }
    #-- always do text comparisons, in case text argument later found
    if (  $V eq ""
       || $V < $a1) {
      $V = $a1;
    }
    #-- increment the index
    $I = $I + 1;
  }
  #-- return numeric or text maximum as appropriate
  if ($lb_numeric) {
    $V = $N;
  }
  # Free up our local Function Argument copy
  undef @FunArgs;
  return $V;
}


#-----------------------------------------------------------------------------
#-- Check for the AVG function - #AVG[<a>][<b>]...[<n>]#
#--
sub Orbit::omlAVG
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $U = $self->{_Utils};
  my $ln_count = 0;
  #-- Get the first argument
  my $N = '';
  my $V = $self->GetArgParse(1, @FunArgs);
  my $a1 = "";
  my $na1 = 0;
  if ($self->IsArg(1, @FunArgs)) {
    $N = $U->GetNumber($V,1);
    if ($N ne "") {
      $ln_count = 1;
    } else {
      $ln_count = 0;
    }
    my $I = 2;
    while (1) {
      #-- Get the next argument
      $a1 = $self->GetArgParse($I, @FunArgs);
      #-- leave if no more arguments or the argument count exceeds 500
      last if    (!$self->IsArg($I, @FunArgs)
                || $I > 500);
      $na1 = $U->GetNumber($a1,1);
      #-- If the first value eq "", immediately assign the next value
      if ($N eq "") {
        $N = $na1;
        if ($N ne "") {
          $ln_count = 1;
        } else {
          $ln_count = 0;
        }
      } else {
        if ($na1 ne "") {
          #-- ADD the values
          $N = $N + $na1;
          #-- Increment the non-null counter
          $ln_count = $ln_count + 1;
        }
      }
      #-- increment the index
      $I = $I + 1;
    }
  }
  #-- Only compute average if the number of non-null elements were > 0
  if ($ln_count > 0) {
    $V = ($N / $ln_count);
  } else {
    $V = '';
  }
  # Free up our local Function Argument copy
  undef @FunArgs;
  return $V;
}


#-----------------------------------------------------------------------------
#-- Check for the RANDOM function - #RANDOM[integer][offset][seed]#
#-- - Returns a random integer number between 1 and the number specified
#-- - Specify seed to seed the random number generator
#-- - Specify offset as 0 to return a 0 based random number: i.e. #RAND[10][][0]# returns 0-9
# RAND [num][offset][seed]
# - Returns a random integer number between 1 and the number specified;
# - num=0 will return a floating point decimal < 1 (i.e. 0.1234567);
# - offset (default 1) - specify 0 for a 0 based offset (0 to num-1) (ex. #RAND[10][][0]# returns 0-9)
#          - offset can also be used to return an random number at a higher range
#            (ex. #RAND[1000][][10000]# - returns 10000 to 10999)
# - seed - provides a starting seed number (integer) for the random generator;
sub Orbit::omlRAND
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $U = $self->{_Utils};
  #-- Get the arguments
  my $a1 = $self->GetArgParse(1, @FunArgs);
  my $a2 = $self->GetArgParse(2, @FunArgs);
  my $a3 = $self->GetArgParse(3, @FunArgs);
  # Check for valid args
  $a1 = 0 if (!$self->IsNumber($a1) || $a1 < 0); # integer num
  $a2 = 1 if (!$self->IsNumber($a2) || $a2 < 0); # offset
  $a3 = 0 if (!$self->IsNumber($a3) || $a3 < 1); # seed
  $a1 = int($a1); # trunc any decimals
  $a2 = int($a2);
  $a3 = int($a3);
  # Set the random seed if specified
  srand($a3) if ($a3 > 0);
  # Get the Random number
  my $V='';
  if ($a1 > 0) {
    $V = int(rand($a1))+$a2;
  } else {
    # Return floating point decimal if number input is 0
    $V = rand($a1)+$a2;
  }
  # Free up our local Function Argument copy
  undef @FunArgs;
  return $V;
}


#-----------------------------------------------------------------------------
#-- Check for the FIBONACCI function - #FIBONACCI[start_iteration][end_iteration][delim]#
#-- - Returns the Fibonacci sequence starting and ending at specified iterations, delimited by delim (def ,)
sub Orbit::omlFIBONACCI
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $U = $self->{_Utils};
  use Core::Fibonacci;
  #-- Get the arguments
  my $a1 = $self->GetArgParse(1, @FunArgs);
  my $a2 = $self->GetArgParse(2, @FunArgs);
  my $a3 = $self->GetArgParse(3, @FunArgs);
  # Check for valid args - must be positive and start < end, or else default
  $a1 = 1 if (!$self->IsNumber($a1) || $a1 < 0);
  $a2 = 7 if (!$self->IsNumber($a2) || $a2 < $a1);
  $a3 = ',' if ($a3 eq '');   # Default comma
  # Get the fibonacci sequence
  my $V = $U->Fibonacci( $a1, $a2, $a3 );
  # Free up our local Function Argument copy
  undef @FunArgs;
  return $V;
}


#******************************************************************************************
# Return true to show package was loaded with
# use Orbit::OML::Function::Math;
#******************************************************************************************
1;


#END Orbit::OML:Function::Math Package
