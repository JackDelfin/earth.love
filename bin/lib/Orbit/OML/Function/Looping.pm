#!/usr/bin/perl
# Version 7.0.0.0      17-Jun-2021
#*****************************************************************************************
#*
#* Orbit::OML::Function::Looping - Version 7
#*
#*  Package Name    :   Orbit::OML:Function::Looping
#*
#*  Description     :   Implements Orbit Markup Language (OML) for LOOPING Functions
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
# LoadLoopingFunctions
#   - Load the Looping OML Functions into the _OML_FUNCTIONS subroutine reference array
#
# REPEAT
# WHILE
# COMMALIST
# PIPELIST
#*****************************************************************************************
package Orbit;   # Continuation of Orbit package

use strict;
use warnings;
use utf8;
use feature ':5.16';


#-----------------------------------------------------------------------------
# LoadLoopingFunctions
#   - Load the Looping OML Functions into the _OML_FUNCTIONS subroutine reference array
#
sub Orbit::LoadLoopingFunctions
{
  my ( $O ) = @_;
  $O->{_OML_FUNCTIONS}->{'REPEAT'}      = sub { $O->omlREPEAT(), };
  $O->{_OML_FUNCTIONS}->{'WHILE'}       = sub { $O->omlWHILE(), };
  $O->{_OML_FUNCTIONS}->{'COMMALIST'}   = sub { $O->omlCOMMALIST(), };
  $O->{_OML_FUNCTIONS}->{'PIPELIST'}    = sub { $O->omlPIPELIST(), };
} #LoadLoopingFunctions
# Alias - Function Group Looping 08
*LoadFunctionGroup08 = \&LoadLoopingFunctions;


#-----------------------------------------------------------------------------
#-- Check for the REPEAT function - #REPEAT[<times>][<text>]#
#-- Repeatedly displays the <text> <times> number of times.
sub Orbit::omlREPEAT
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $bFlush   = $self->{_bFlush};
  my $U = $self->{_Utils};
  my $V = "";
  #-- Get the number of times to repeat
  my $a1 = $self->GetArgParse(1, @FunArgs);
  #-- Get the text to repeat - don't parse it since it may contain context sensitive functions
  my $a2 = $self->GetArgNoParse(2, @FunArgs);  #-- Text
  if ($self->IsArg(2, @FunArgs)) {
    #-- Convert the number of times to a number
    my $N = $U->NVL($U->GetNumber($a1,1),0);
    if ($N > 0) {
      for (my $i=0; $i<$N; $i++) {
        # Parse the second argument and a ppend this "repeat" result to the acculumating fv_value
        $V .= $self->Parse($a2, $bFlush);
      }
    }
  } else {
    $V = $self->GetFunctionError('REPEAT');
  }
  # Free up our local Function Argument copy
  undef @FunArgs;
  return $V;
}


#-----------------------------------------------------------------------------
#-- Check for the WHILE function - #WHILE[<expression>][<text>][<maxtimes>]#
#-- Repeatedly displays the <text> while <expression> is TRUE, but not more
#-- than <maxtimes> number of times.
sub Orbit::omlWHILE
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $bFlush   = $self->{_bFlush};
  my $V = "";
  my $U = $self->{_Utils};
  my $na3      = 0;
  #-- Get the expression argument
  my $a1 = $self->GetArgNoParse(1, @FunArgs);  #-- Expression
  if ($a1 ne '') {
    #-- Get the text to repeat - don't parse it since it may contain context sensitive functions
    my $a2 = $self->GetArgNoParse(2, @FunArgs);  #-- Text
    if ($a2 ne '') {
      #-- copy text so we don't need to keep extracting it
      my $a4 = $a2;
      #-- Get the number of times to repeat
      my $a3 = $self->GetArgParse(3, @FunArgs);
      if ($a3 ne '') {
        #-- Convert the number of times to a number
        $na3 = $U->NVL($U->GetNumber($a3,1),0);
      } else {
        $na3 = 5000;  #-- Default <maxtimes>
      }
      #-- continue looping until expression is false, or maxtimes is reached
      my $I = 1;
      while (1) {
        last if (!$self->Eval($a1)
               || $I > $na3);
        #-- parse $a2 in place
        $a2 = $self->Parse($a2, $bFlush);
        #-- append it to $V) { reset it to unparsed string
        $V = $V.$a2;
        $a2 = $a4;
        #-- increment loop index
        $I = $I + 1;
      }
    }
  }
  # Free up our local Function Argument copy
  undef @FunArgs;
  return $V;
}


#-----------------------------------------------------------------------------
#-- Check for the COMMALIST function - #COMMALIST[<val1>][<val2>]...[<valn>]#
#-- Return a comma-separated list of all non-NULL arguments in the list
#--
sub Orbit::omlCOMMALIST
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $V = "";
  my $a1 = "";
  my $I = 1;
  while (1) {
    #-- Get the next argument
    $a1 = $self->GetArgParse($I, @FunArgs);
    #-- leave if there are no more arguments or the argument count exceeds 500
    last if   ( !$self->IsArg($I, @FunArgs)
              || $I > 500);
    if ($a1 ne "") {
      $V = $V.','.$a1;
    }
    #-- increment the index
    $I = $I + 1;
  }
  #-- strip out the initial pipe
  if ($V ne "") {
    $V = substr($V, 1);
  }
  # Free up our local Function Argument copy
  undef @FunArgs;
  return $V;
}


#-----------------------------------------------------------------------------
#-- Check for the PIPELIST function - #PIPELIST[<val1>][<val2>]...[<valn>]#
#-- Return a pipe (|) separated list of all non-NULL arguments in the list
#--
sub Orbit::omlPIPELIST
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $V = "";
  my $a1 = "";
  my $I = 1;
  while (1) {
    #-- Get the next argument
    $a1 = $self->GetArgParse($I, @FunArgs);
    #-- leave if there are no more arguments or the argument count exceeds 500
    last if   ( !$self->IsArg($I, @FunArgs)
              || $I > 500);
    if ($a1 ne "") {
      $V = $V.'|'.$a1;
    }
    #-- increment the index
    $I = $I + 1;
  }
  #-- strip out the initial pipe
  if ($V ne "") {
    $V = substr($V, 1);
  }
  # Free up our local Function Argument copy
  undef @FunArgs;
  return $V;
}


#******************************************************************************************
# Return true to show package was loaded with
# use Orbit::OML::Function::Looping;
#******************************************************************************************
1;


#END Orbit::OML:Function::Looping Package
