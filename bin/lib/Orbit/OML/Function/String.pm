#!/usr/bin/perl
# Version 7.0.0.0      17-Jun-2021
#*****************************************************************************************
#*
#* Orbit::OML::Function::String - Version 7
#*
#*  Package Name    :   Orbit::OML:Function::String
#*
#*  Description     :   Implements Orbit Markup Language (OML) for STRING Functions
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
# LoadStringFunctions
#   - Load the String OML Functions into the _OML_FUNCTIONS subroutine reference array
#
# REPLACE   REPLACEALL   IREPLACE   IREPLACEALL
# FORMAT
# SUBSTR    SUBSTR0
# INSTR     INDEX
# TRANSLATE
# RPAD      LPAD
# RTRIM     LTRIM    TRIM
# APPEND
#*****************************************************************************************
package Orbit;   # Continuation of Orbit package

use strict;
use warnings;
use utf8;
use feature ':5.16';


#-----------------------------------------------------------------------------
# LoadStringFunctions
#   - Load the String OML Functions into the _OML_FUNCTIONS subroutine reference array
#
sub Orbit::LoadStringFunctions
{
  my ( $O ) = @_;
  $O->{_OML_FUNCTIONS}->{'REPLACE'}     = sub { $O->omlREPLACE(), };
  $O->{_OML_FUNCTIONS}->{'REPLACEALL'}  = sub { $O->omlREPLACEALL(), };
  $O->{_OML_FUNCTIONS}->{'IREPLACE'}    = sub { $O->omlIREPLACE(), };
  $O->{_OML_FUNCTIONS}->{'IREPLACEALL'} = sub { $O->omlIREPLACEALL(), };
  $O->{_OML_FUNCTIONS}->{'FORMAT'}      = sub { $O->omlFORMAT(), };
  $O->{_OML_FUNCTIONS}->{'SUBSTR'}      = sub { $O->omlSUBSTR(), };
  $O->{_OML_FUNCTIONS}->{'SUBSTR0'}     = sub { $O->omlSUBSTR0(), };
  $O->{_OML_FUNCTIONS}->{'INSTR'}       = sub { $O->omlINSTR(), };
  $O->{_OML_FUNCTIONS}->{'INDEX'}       = sub { $O->omlINDEX(), };
  $O->{_OML_FUNCTIONS}->{'TRANSLATE'}   = sub { $O->omlTRANSLATE(), };
  $O->{_OML_FUNCTIONS}->{'RPAD'}        = sub { $O->omlRPAD(), };
  $O->{_OML_FUNCTIONS}->{'LPAD'}        = sub { $O->omlLPAD(), };
  $O->{_OML_FUNCTIONS}->{'RTRIM'}       = sub { $O->omlRTRIM(), };
  $O->{_OML_FUNCTIONS}->{'LTRIM'}       = sub { $O->omlLTRIM(), };
  $O->{_OML_FUNCTIONS}->{'TRIM'}        = sub { $O->omlTRIM(), };
  $O->{_OML_FUNCTIONS}->{'APPEND'}      = sub { $O->omlAPPEND(), };
} #LoadStringFunctions
# Alias - Function Group String 03
*LoadFunctionGroup03 = \&LoadStringFunctions;


#-----------------------------------------------------------------------------
#-- Check for the REPLACE function - #REPLACE[<text>][<find>][<replace>]#
#-- Replaces first occurance ONLY
sub Orbit::omlREPLACE
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $U = $self->{_Utils};
  #-- Get the base text ($V)
  my $V = $self->GetArgParse(1, @FunArgs);
  my $a1 = $self->GetArgParse(2, @FunArgs);  #-- Find Text
  if ($self->IsArg(2, @FunArgs)) {
    my $a2 = $self->GetArgParse(3, @FunArgs);  #-- Replace Text
    $V = $U->Replace($V, $a1, $a2);
  } else {
    $V = $self->GetFunctionError('REPLACE');
  }
  # Free up our local Function Argument copy
  undef @FunArgs;
  return $V;
}


#-----------------------------------------------------------------------------
#-- Check for the REPLACEALL function - #REPLACEALL[<text>][<find>][<replace>]#
#--
sub Orbit::omlREPLACEALL
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $U = $self->{_Utils};
  #-- Get the base text ($V)
  my $V = $self->GetArgParse(1, @FunArgs);
  my $a1 = $self->GetArgParse(2, @FunArgs);  #-- Find Text
  if ($self->IsArg(2, @FunArgs)) {
    my $a2 = $self->GetArgParse(3, @FunArgs);  #-- Replace Text
    $V = $U->ReplaceAll($V, $a1, $a2);
  } else {
    $V = $self->GetFunctionError('REPLACEALL');
  }
  # Free up our local Function Argument copy
  undef @FunArgs;
  return $V;
}


#-----------------------------------------------------------------------------
#-- Check for the IREPLACE function - #IREPLACE[<text>][<find>][<replace>]#
#-- Perform a case Insensitive Replace
sub Orbit::omlIREPLACE
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $U = $self->{_Utils};
  #-- Get the base text ($V)
  my $V = $self->GetArgParse(1, @FunArgs);
  my $a1 = $self->GetArgParse(2, @FunArgs);  #-- Find Text
  if ($a1 ne '') {
    my $a2 = $self->GetArgParse(3, @FunArgs);  #-- Replace Text
    $V = $U->iReplace($V, $a1, $a2);
  } else {
    $V = $self->GetFunctionError('IREPLACE');
  }
  # Free up our local Function Argument copy
  undef @FunArgs;
  return $V;
}


#-----------------------------------------------------------------------------
#-- Check for the IREPLACEALL function - #IREPLACEALL[<text>][<find>][<replace>]#
#-- Perform a case Insensitive Replace
sub Orbit::omlIREPLACEALL
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $U = $self->{_Utils};
  #-- Get the base text ($V)
  my $V = $self->GetArgParse(1, @FunArgs);
  my $a1 = $self->GetArgParse(2, @FunArgs);  #-- Find Text
  if ($a1 ne '') {
    my $a2 = $self->GetArgParse(3, @FunArgs);  #-- Replace Text
    $V = $U->iReplaceAll($V, $a1, $a2);
  } else {
    $V = $self->GetFunctionError('IREPLACEALL');
  }

  # Free up our local Function Argument copy
  undef @FunArgs;
  return $V;
}


#-----------------------------------------------------------------------------
#-- Check for the FORMAT function - 2 Formats
#-- - #FORMAT[<date>][<in_format>][<out_format>]#
#-- - #FORMAT[<number>][<format>]#  ,.00
#--
sub Orbit::omlFORMAT
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $U = $self->{_Utils};
  my $V = "";
  #-- Get the base text ($a1)
  my $a1 = $self->GetArgParse(1, @FunArgs);
  my $a2 = $self->GetArgParse(2, @FunArgs);
  if ($self->IsArg(2, @FunArgs)) {
    #-- have a second parameter - check for the 3rd
    my $a3 = $self->GetArgParse(3, @FunArgs);
    if ($a3 ne '') {
      #-- Date format
      $V = $U->DateToChar($a1, $a2, $a3);
    } else {
      #-- number format
      $V = $U->NumberToChar($a1, $a2);
    }
  } else {
    #-- default to number format if no format specified
    $V = $U->NumberToChar($a1);
  }

  # Free up our local Function Argument copy
  undef @FunArgs;
  return $V;
}


#-----------------------------------------------------------------------------
#-- Check for the SUBSTR function - #SUBSTR[<text>][<begin>].[<length>]#
#-- - 1-based substr (Oracle)
#-- - Gets a substring from [text] beginning at [start] and getting [length] chars.  1-based substr (Oracle) - returns 0 if not found
sub Orbit::omlSUBSTR
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $U = $self->{_Utils};
  #-- Get the base text ($V)
  my $V = $self->GetArgParse(1, @FunArgs);
  my $a1 = $self->GetArgParse(2, @FunArgs);  #-- begin
  if ($self->IsArg(2, @FunArgs)) {
    my $na1 = $U->NVL($U->GetNumber($a1,1), 1);
    $na1--;
    # Check for 3rd argument to make the correct call
    if ($self->IsArg(3, @FunArgs)) {
      my $a2 = $self->GetArgParse(3, @FunArgs);
      my $na2 = $U->GetNumber($a2,1);
      $V = substr($V, $na1, $na2);
    } else {
      $V = substr($V, $na1);
    }
  } else {
    $V = $self->GetFunctionError('SUBSTR');
  }
  # Free up our local Function Argument copy
  undef @FunArgs;
  return $V;
}


#-----------------------------------------------------------------------------
#-- Check for the SUBSTR0 function - #SUBSTR0[<text>][<begin>].[<length>]#
#-- - 0-based substr (Perl)
#-- - Same as SUBSTR, but 0-based (Perl) - returns -1 if not found, 0 for beginning of string
sub Orbit::omlSUBSTR0
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $U = $self->{_Utils};
  #-- Get the base text ($V)
  my $V = $self->GetArgParse(1, @FunArgs);
  my $a1 = $self->GetArgParse(2, @FunArgs);  #-- begin
  if ($self->IsArg(2, @FunArgs)) {
    my $na1 = $U->NVL($U->GetNumber($a1,1), 1);
    # Check for 3rd argument to make the correct call
    if ($self->IsArg(3, @FunArgs)) {
      my $a2 = $self->GetArgParse(3, @FunArgs);
      my $na2 = $U->GetNumber($a2,1);
      $V = substr($V, $na1, $na2);
    } else {
      $V = substr($V, $na1);
    }
  } else {
    $V = $self->GetFunctionError('SUBSTR0');
  }
  # Free up our local Function Argument copy
  undef @FunArgs;
  return $V;
}


#-----------------------------------------------------------------------------
#-- Check for the INSTR function - #INSTR[<text>][<find>][<begin>][<occurrence>]# - NOT SUPPORTED with occurrence
#-- Check for the INSTR function - #INSTR[<text>][<find>][<begin>]#
#-- 1-based offset, returns 0 if string not found, similar to Oracle "instr"
#--
sub Orbit::omlINSTR
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $U = $self->{_Utils};
  #-- Get the base text ($V)
  my $V = $self->GetArgParse(1, @FunArgs);
  my $a1 = $self->GetArgParse(2, @FunArgs); #-- find
  if ($self->IsArg(2, @FunArgs)) {
    my $a2 = $self->GetArgParse(3, @FunArgs); #-- begin
    my $na2 = $U->NVL($U->GetNumber($a2,1), 1);
    $na2--;
    $V = index($V, $a1, $na2);
    # Increase the offset for INSTR conversion
    $V++;
  } else {
    $V = $self->GetFunctionError('INSTR');
  }
  # Free up our local Function Argument copy
  undef @FunArgs;
  return $V;
}


#-----------------------------------------------------------------------------
#-- Check for the INDEX function - #INDEX[<text>][<find>][<begin>]#
#-- 0-based offset, returns -1 if string not found, similar to Perl "index"
#--
sub Orbit::omlINDEX
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $U = $self->{_Utils};
  #-- Get the base text ($V)
  my $V = $self->GetArgParse(1, @FunArgs);
  my $a1 = $self->GetArgParse(2, @FunArgs); #-- find
  if ($self->IsArg(2, @FunArgs)) {
    my $a2 = $self->GetArgParse(3, @FunArgs); #-- begin
    my $na2 = $U->NVL($U->GetNumber($a2,1), 1);
    $V = index($V, $a1, $na2);
  } else {
    $V = $self->GetFunctionError('INDEX');
  }
  # Free up our local Function Argument copy
  undef @FunArgs;
  return $V;
}


#-----------------------------------------------------------------------------
#-- Check for the TRANSLATE function - #TRANSLATE[<text>][<from>][<to>]#
#--
sub Orbit::omlTRANSLATE
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $U = $self->{_Utils};
  #-- Get the base text ($V)
  my $V = $self->GetArgParse(1, @FunArgs);
  my $a1 = $self->GetArgParse(2, @FunArgs); #-- from
  if ($self->IsArg(3, @FunArgs)) {
    my $a2 = $self->GetArgParse(3, @FunArgs); #-- to
    $V = $U->translate($V, $a1, $a2);
  } else {
    $V = $self->GetFunctionError('TRANSLATE');
  }
  # Free up our local Function Argument copy
  undef @FunArgs;
  return $V;
}


#-----------------------------------------------------------------------------
#-- Check for the RPAD function - #RPAD[<text>][<length>][<char>]#
#--
sub Orbit::omlRPAD
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $U = $self->{_Utils};
  #-- Get the base text ($V)
  my $V = $self->GetArgParse(1, @FunArgs);
  my $a1 = $self->GetArgParse(2, @FunArgs); #-- length
  if ($self->IsArg(2, @FunArgs)) {
    my $na1 = $U->NVL($U->GetNumber($a1,1), 1);
    my $a2 = $self->GetArgParse(3, @FunArgs);
    $a2 = $U->NVL($a2, ' ');
    # RPAD
    $V = $U->rpad($V, $na1, $a2);
  } else {
    $V = $self->GetFunctionError('RPAD');
  }
  # Free up our local Function Argument copy
  undef @FunArgs;
  return $V;
}


#-----------------------------------------------------------------------------
#-- Check for the LPAD function - #LPAD[<text>][<length>][<char>]#
#--
sub Orbit::omlLPAD
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $U = $self->{_Utils};
  #-- Get the base text ($V)
  my $V = $self->GetArgParse(1, @FunArgs);
  my $a1 = $self->GetArgParse(2, @FunArgs); #-- length
  if ($self->IsArg(2, @FunArgs)) {
    my $na1 = $U->NVL($U->GetNumber($a1,1), 1);
    my $a2 = $self->GetArgParse(3, @FunArgs);
    $a2 = $U->NVL($a2, ' ');
    # LPAD
    $V = $U->lpad($V, $na1, $a2);
  } else {
    $V = $self->GetFunctionError('LPAD');
  }
  # Free up our local Function Argument copy
  undef @FunArgs;
  return $V;
}


#-----------------------------------------------------------------------------
#-- Check for the RTRIM function - #RTRIM[<text>][<char>]#
#--
sub Orbit::omlRTRIM
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $U = $self->{_Utils};
  #-- Get the base text ($V)
  my $V = $self->GetArgParse(1, @FunArgs);
  my $a1 = $self->GetArgParse(2, @FunArgs);
  # RTRIM
  $V = $U->rtrim($V, $a1);
  # Free up our local Function Argument copy
  undef @FunArgs;
  return $V;
}


#-----------------------------------------------------------------------------
#-- Check for the LTRIM function - #LTRIM[<text>][<char>]#
#--
sub Orbit::omlLTRIM
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $U = $self->{_Utils};
  #-- Get the base text ($V)
  my $V = $self->GetArgParse(1, @FunArgs);
  my $a1 = $self->GetArgParse(2, @FunArgs);
  # LTRIM
  $V = $U->ltrim($V, $a1);
  # Free up our local Function Argument copy
  undef @FunArgs;
  return $V;
}


#-----------------------------------------------------------------------------
#-- Check for the TRIM function - #TRIM[<text>][<char>]#
#--
sub Orbit::omlTRIM
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $U = $self->{_Utils};
  #-- Get the base text ($V)
  my $V = $self->GetArgParse(1, @FunArgs);
  my $a1 = $self->GetArgParse(2, @FunArgs);
  # TRIM
  $V = $U->trim($V, $a1);
  # Free up our local Function Argument copy
  undef @FunArgs;
  return $V;
}


#-----------------------------------------------------------------------------
#-- Check for the APPEND function - #APPEND[<text1>][<text2>][<linebreak>]#
#--
sub Orbit::omlAPPEND
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $V = $self->GetArgParse(1, @FunArgs);
  #-- Get the text to concatenate
  my $a1 = $self->GetArgParse(2, @FunArgs);
  if ($self->IsArg(2, @FunArgs)) {
    #-- Get the linebreak character
    my $a2 = $self->GetArgParse(3, @FunArgs);
    #-- only use linebreak if original text ne ""
    if ($V ne "") {
      $V = $V.$a2.$a1;
    } else {
      $V = $a1;
    }
  }
  # Free up our local Function Argument copy
  undef @FunArgs;
  return $V;
}


#******************************************************************************************
# Return true to show package was loaded with
# use Orbit::OML::Function::String;
#******************************************************************************************
1;


#END Orbit::OML:Function::String Package
