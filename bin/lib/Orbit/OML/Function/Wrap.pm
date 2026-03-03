#!/usr/bin/perl
# Version 7.0.0.0      17-Jun-2021
#*****************************************************************************************
#*
#* Orbit::OML::Function::Wrap - Version 7
#*
#*  Package Name    :   Orbit::OML:Function::Wrap
#*
#*  Description     :   Implements Orbit Markup Language (OML) for WRAP Functions
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
# LoadWrapFunctions
#   - Load the Wrap OML Functions into the _OML_FUNCTIONS subroutine reference array
#
# ROWS
# WRAP
# WRAPTOKEN
# STRIPTEXT
#*****************************************************************************************
package Orbit;   # Continuation of Orbit package

use strict;
use warnings;
use utf8;
use feature ':5.16';


#-----------------------------------------------------------------------------
# LoadWrapFunctions
#   - Load the Wrap OML Functions into the _OML_FUNCTIONS subroutine reference array
#
sub Orbit::LoadWrapFunctions
{
  my ( $O ) = @_;
  $O->{_OML_FUNCTIONS}->{'ROWS'}        = sub { $O->omlROWS(), };
  $O->{_OML_FUNCTIONS}->{'WRAP'}        = sub { $O->omlWRAP(), };
  $O->{_OML_FUNCTIONS}->{'WRAPTOKEN'}   = sub { $O->omlWRAPTOKEN(), };
  $O->{_OML_FUNCTIONS}->{'STRIPTEXT'}   = sub { $O->omlSTRIPTEXT(), };
} #LoadWrapFunctions
# Alias - Function Group Wrap 11
*LoadFunctionGroup11 = \&LoadWrapFunctions;


#-----------------------------------------------------------------------------
#-- Check for the ROWS function - #ROWS[<text>][<max_linesize>][<min_rows>][<max_rows>]#
#--
sub Orbit::omlROWS
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $U = $self->{_Utils};
  use Orbit::Utils::Wrap;
  use Core::Math::Least;
  #-- Get the first argument
  my $a1 = $self->GetArgParse(1, @FunArgs);
  #-- Get the next argument - max linesize
  my $a2 = $self->GetArgParse(2, @FunArgs);
  # Call Count Rows to get the count
  my $N = $self->Count_Rows($a1, $U->GetNumber($a2,1));
  my $a3 = $self->GetArgParse(3, @FunArgs);
  #-- Get the greatest value of min_rows or the number of rows returned above
  if ($self->IsArg(3, @FunArgs)) {
    my $na1 = $U->NVL($U->GetNumber($a3,1),0);
    $N = $U->greatest($N, $na1);
  }
  $a3 = $self->GetArgParse(4, @FunArgs);
  #-- Get the least value of max_rows or the number of rows returned above
  if ($a3 ne '') {
    my $na1 = $U->NVL($U->GetNumber($a3,1),0);
    $N = $U->least($N, $na1);
  }
  # Free up our local Function Argument copy
  undef @FunArgs;
  return $N;
}


#-----------------------------------------------------------------------------
#-- Check for the WRAP function - #WRAP[<text>][<maxlength>][<wb_chars>][<$lb_chars>]#
#--
sub Orbit::omlWRAP
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $U = $self->{_Utils};
  use Orbit::Utils::Wrap;
  #-- Get the first argument (text value)
  my $V = $self->GetArgParse(1, @FunArgs);
  my $a2 = $self->GetArgParse(2, @FunArgs);
  my $na2 = $U->GetNumber($a2,1);
  my $a3 = $self->GetArgParse(3, @FunArgs);
  my $a4 = $self->GetArgParse(4, @FunArgs);
  #-- Return the wrapped token value
  $V = $self->Wrap_Text($V, $na2, $a3, $a4);
  # Free up our local Function Argument copy
  undef @FunArgs;
  return $V;
}


#-----------------------------------------------------------------------------
#-- Check for the WRAPTOKEN function - #WRAPTOKEN[<token_name>][<maxlength>][<wb_chars>][<$lb_chars>]#
#--
sub Orbit::omlWRAPTOKEN
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $U = $self->{_Utils};
  use Orbit::Utils::Wrap;
  #-- Get the first argument (token name)
  my $a1 = $self->GetArgParse(1, @FunArgs);
  my $a2 = $self->GetArgParse(2, @FunArgs);
  my $na2 = $U->GetNumber($a2,1);
  my $a3 = $self->GetArgParse(3, @FunArgs);
  my $a4 = $self->GetArgParse(4, @FunArgs);
  #-- Get the token value
  my $V = $self->Get_Token($a1);
  #-- Wrap the token value and save the results back to the token
  $V = $self->Wrap_Text($V, $na2, $a3, $a4);
  # Free up our local Function Argument copy
  undef @FunArgs;
  return $V;
}


#-----------------------------------------------------------------------------
#-- Check for the STRIPTEXT function - #STRIPTEXT[<text>][<begin_text>][<end_text>][<replace_text>][<match_pairs>][KeepRawText]#
#--
sub Orbit::omlSTRIPTEXT
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $U = $self->{_Utils};
  #-- Get the base text ($V)
  my $V = $self->GetArgParse(1, @FunArgs);
  if ($self->IsArg(1, @FunArgs)) {
    my $a1 = $self->GetArgParse(2, @FunArgs);  #-- Begin Text
    my $a2 = $self->GetArgParse(3, @FunArgs);  #-- End Text
    my $a3 = $self->GetArgParse(4, @FunArgs);  #-- Replace Text
    my $a4 = $self->GetArgParse(5, @FunArgs);
    my $KeepRawText = $self->GetArgParse(6, @FunArgs);
    $KeepRawText = 0 if ($KeepRawText ne '1');
    my $na4 = $U->GetNumber($a4, 1);  #-- Match Pairs
    #-- Call StripText_Long; use default argument values
    $V = $self->StripText($V, $U->NVL($a1, '<!---'),
                                          $U->NVL($a2, '--->'),
                                          $a3,
                                          $U->NVL($na4, 0),
                                          $KeepRawText);
  } else {
    $V = $self->GetFunctionError('STRIPTEXT');
  }
  # Free up our local Function Argument copy
  undef @FunArgs;
  return $V;
}


#******************************************************************************************
# Return true to show package was loaded with
# use Orbit::OML::Function::Wrap;
#******************************************************************************************
1;


#END Orbit::OML:Function::Wrap Package
