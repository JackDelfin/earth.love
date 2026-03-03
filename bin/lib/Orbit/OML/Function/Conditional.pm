#!/usr/bin/perl
# Version 7.0.0.0      17-Jun-2021
#*****************************************************************************************
#*
#* Orbit::OML::Function::Conditional - Version 7
#*
#*  Package Name    :   Orbit::OML:Function::Conditional
#*
#*  Description     :   Implements Orbit Markup Language (OML) for CONDITIONAL Functions
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
# LoadConditionalFunctions
#   - Load the Conditional OML Functions into the _OML_FUNCTIONS subroutine reference array
#
# EVAL
# AND
# OR
# IN           INLIKE
# NOTIN        NOTINLIKE
# NOTEXISTS    ISNULL      NULL
# LIKE
# ILIKE
#*****************************************************************************************
package Orbit;   # Continuation of Orbit package

use strict;
use warnings;
use utf8;
use feature ':5.16';


#-----------------------------------------------------------------------------
# LoadConditionalFunctions
#   - Load the Conditional OML Functions into the _OML_FUNCTIONS subroutine reference array
#
sub Orbit::LoadConditionalFunctions
{
  my ( $O ) = @_;
  $O->{_OML_FUNCTIONS}->{'EVAL'}        = sub { $O->omlEVAL(), };
  $O->{_OML_FUNCTIONS}->{'AND'}         = sub { $O->omlAND(), };
  $O->{_OML_FUNCTIONS}->{'OR'}          = sub { $O->omlOR(), };
  $O->{_OML_FUNCTIONS}->{'IN'}          = sub { $O->omlIN(), };
  $O->{_OML_FUNCTIONS}->{'INLIKE'}      = sub { $O->omlIN(), };
  $O->{_OML_FUNCTIONS}->{'NOTIN'}       = sub { $O->omlIN(), };
  $O->{_OML_FUNCTIONS}->{'NOTINLIKE'}   = sub { $O->omlIN(), };
  $O->{_OML_FUNCTIONS}->{'NOTEXISTS'}   = sub { $O->omlNOTEXISTS(), };
  $O->{_OML_FUNCTIONS}->{'ISNULL'}      = sub { $O->omlNOTEXISTS(), };
  $O->{_OML_FUNCTIONS}->{'NULL'}        = sub { $O->omlNOTEXISTS(), };
  $O->{_OML_FUNCTIONS}->{'LIKE'}        = sub { $O->omlLIKE(), };
  $O->{_OML_FUNCTIONS}->{'ILIKE'}       = sub { $O->omlLIKE(), };
} #LoadConditionalFunctions
# Alias - Function Group Conditional 01
*LoadFunctionGroup01 = \&LoadConditionalFunctions;


#-----------------------------------------------------------------------------
#-- Check for the EVAL function - #EVAL[<text>][then][else]#
#-- Returns 1 if the expression is true, 0 otherwise
#-- [condition].[then].[else]   - evaluates the boolean expression and returns boolean 1 or 0; null evaluates to 0
sub Orbit::omlEVAL
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $V = "";
  #-- Get the next argument
  my $a1= $self->GetArgNoParse(1, @FunArgs);
  if ($self->IsArg(2, @FunArgs)) { #--then
    if ($self->Eval($a1)) {
      #-- Expression was true, so value is the <then> part of the expression
      $V = $self->GetArgParse(2, @FunArgs); #--then
    } else {
      #-- Expression was false, so value is the <else> part of the expression
      $V = $self->GetArgParse(3, @FunArgs);
    }
  } else {   #-- no) {/else - use standard functionality
    if ($self->Eval($a1)) {
      $V = '1';
    } else {
      $V = '0';
    }
  }

  # Free up our local Function Argument copy
  undef @FunArgs;
  return $V;
}


#-----------------------------------------------------------------------------
#-- Check for the AND function - #AND[<val1>][<val2>]...[<valn>]#
#-- Returns 1 if all of the expressions (vals) are true, 0 otherwise
#-- NOTE: NULL arguments are TRUE expressions
#--
sub Orbit::omlAND
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  # default response to 1
  my $V = '1';
  my $lEval = "";
  my $a1 = "";
  
  # search through each Arg and if any is false, return 0
  for (my $I=1; $I <= @FunArgs; $I++) {
    #
    #-- Get the next argument
    #
    $a1 = $self->GetArgNoParse($I, @FunArgs);

    # Check for empty argument (default: FALSE in AND function)
    if ($a1 ne "") {
      $lEval = $self->Eval($a1);
      if ($lEval eq '0') {
        $V = '0';
        last;
      }
    } else {
      # an empty arg is FALSE (pre-Parse)
      $V = '0';
      last;
    }
  }
  # Free up our local Function Argument copy
  undef @FunArgs;
  return $V;
}


#-----------------------------------------------------------------------------
#-- Check for the OR function - #OR[<val1>][<val2>]...[<valn>]#
#-- Returns 1 if ANY of the expressions (vals) is true, 0 otherwise
#-- NOTE: NULL arguments are TRUE expressions
#--
sub Orbit::omlOR
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  # default response to 0
  my $V = '0';
  my $I = 1;
  my $lEval = "";
  my $a1 = "";
  while (1) {
    #-- Get the next argument
    $a1 = $self->GetArgNoParse($I, @FunArgs);
    #-- leave if there are no more arguments or the argument count exceeds 5000
    last if (!$self->IsArg($I, @FunArgs)
             || $I > 5000);
    #-- leave if the expression is TRUE - return 1
    $lEval = $self->Eval($a1);
    if ($lEval eq '1') {
      $V = '1';
      last;
    }
    #-- increment the index
    $I = $I + 1;
  }

  # Free up our local Function Argument copy
  undef @FunArgs;
  return $V;
}


#-----------------------------------------------------------------------------
#-- Check for the IN / INLIKE function - #IN[<text>][<val1>][<val2>]...[<valn>]#
#--   (MJ 2003/05/01 #-- also support NOTIN and NOTINLIKE functions)
#-- Aliases: INLIKE NOTIN NOTINLIKE
sub Orbit::omlIN
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $Function = $self->{_Function};   # Get Function name (certain functions, usually for aliases or overloads)
  my $U = $self->{_Utils};
  my $V = "";
  use Core::Like;
  my $lb_like = 0;
  #-- Get the base text ($a1)
  my $a1 = $self->GetArgParse(1, @FunArgs);
  my $a2 = "";
  my $a3 = "";
  #-- set return values 1/0 for IN% / NOTIN% functions
  if (!($Function =~ /NOT.*/)) {
    $V = '0'; #-- "found" return value (default)
    $a3 = '1'; #-- "not found" return value
  } else {
    $V = '1'; #-- "found" return value (default)
    $a3 = '0'; #-- "not found" return value
  }
  #-- set LIKE boolean to true or false
  $lb_like = ($Function =~ /.*LIKE/);
  my $I = 2;
  while (1) {
    #-- Get the next argument
    $a2 = $self->GetArgParse($I, @FunArgs);
    #-- leave if we have a not null or there are no more arguments or the argument count exceeds 5000
    last if    (!$self->IsArg($I, @FunArgs)
              || $I > 5000);
    if (!$lb_like) {
      #-- check for standard IN or INLIKE
      if ($a2 eq $a1) {
        $V = $a3; #-- "found" return value
        last;
      }
    } else {
      #-- check for INLIKE function
      #-- check for standard IN or INLIKE
      if (  $U->like($a2, $a1)
         || $U->like($a1, $a2)
         || ($a1 eq "" && $a2 eq "")
        ) {
        $V = $a3; #-- "found" return value
        last;
      }
    }
    #-- increment the index
    $I = $I + 1;
  }
  # Free up our local Function Argument copy
  undef @FunArgs;
  return $V;
}


#-----------------------------------------------------------------------------
#-- Check for the NOTEXISTS or ISNULL or NULL function - #NOTEXISTS[<text>][then][else]#
#-- Returns 1 if ANY of the expressions (vals) is true, 0 otherwise
#-- Aliases: ISNULL NULL
sub Orbit::omlNOTEXISTS
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $V = "";
  #-- Get the next argument
  my $a1 = $self->GetArgParse(1, @FunArgs);
  if ($self->IsArg(2, @FunArgs)) { #--then
    if ($a1 eq "") {
      #-- Expression was true, so value is the <then> part of the expression
      $V = $self->GetArgParse(2, @FunArgs); #--then
    } else {
      #-- Expression was false, so value is the <else> part of the expression
      $V = $self->GetArgParse(3, @FunArgs);
    }
  } else {   #-- use standard functionality
    if ($a1 eq "") {
      $V = '1';
    } else {
      $V = '0';
    }
  }
  # Free up our local Function Argument copy
  undef @FunArgs;
  return $V;
}


#-----------------------------------------------------------------------------
#-- Check for the LIKE function - #LIKE[<text>][<compare_pattern>][then][else]#
#--
sub Orbit::omlLIKE
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $U = $self->{_Utils};
  use Core::Like;
  #-- Get the base text ($V)
  my $V = $self->GetArgParse(1, @FunArgs);
  my $a1 = $self->GetArgParse(2, @FunArgs); #--pattern
  if ($self->IsArg(2, @FunArgs)) {
    if ($self->IsArg(3, @FunArgs)) {
      #-- use) {/else clauses if we found the <then>
      if (  $U->like($V, $a1)
         || $U->like($a1, $V)
         ) {
        #-- Expression was true, so value is the <then> part of the expression
        $V = $self->GetArgParse(3, @FunArgs); #--then
      } else {
        #-- Expression was false, so value is the <else> part of the expression
        $V = $self->GetArgParse(4, @FunArgs);
      }
    } else {   #-- no else - use standard functionality
      if (  $U->like($V, $a1)
         || $U->like($a1, $V)
         ) {
        $V = '1';
      } else {
        $V = '0';
      }
    }
  } else {
    $V = $self->GetFunctionError('LIKE');
  }
  # Free up our local Function Argument copy
  undef @FunArgs;
  return $V;
}


#-----------------------------------------------------------------------------
#-- Check for the ILIKE function - #ILIKE[<text>][<compare_pattern>][then][else]#
#--
sub Orbit::omlILIKE
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $U = $self->{_Utils};
  use Core::Like;
  #-- Get the base text ($V)
  my $V = $self->GetArgParse(1, @FunArgs);
  my $a1 = $self->GetArgParse(2, @FunArgs); #--pattern
  if ($self->IsArg(2, @FunArgs)) {
    if ($self->IsArg(3, @FunArgs)) {
      #-- use) {/else clauses if we found the <then>
      if (  $U->ilike($V, $a1)
         || $U->ilike($a1, $V)
         ) {
        #-- Expression was true, so value is the <then> part of the expression
        $V = $self->GetArgParse(3, @FunArgs); #--then
      } else {
        #-- Expression was false, so value is the <else> part of the expression
        $V = $self->GetArgParse(4, @FunArgs);
      }
    } else {   #-- no else - use standard functionality
      if (  $U->ilike($V, $a1)
         || $U->ilike($a1, $V)
         ) {
        $V = '1';
      } else {
        $V = '0';
      }
    }
  } else {
    $V = $self->GetFunctionError('ILIKE');
  }
  # Free up our local Function Argument copy
  undef @FunArgs;
  return $V;
}


#******************************************************************************************
# Return true to show package was loaded with
# use Orbit::OML::Function::Conditional;
#******************************************************************************************
1;


#END Orbit::OML:Function::Conditional Package
