#!/usr/bin/perl
# Version 7.0.0.0      17-Jun-2021
#*****************************************************************************************
#*
#* Orbit::OML::Function::Date - Version 7
#*
#*  Package Name    :   Orbit::OML:Function::Date
#*
#*  Description     :   Implements Orbit Markup Language (OML) for DATE Functions
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
# LoadDateFunctions
#   - Load the Date OML Functions into the _OML_FUNCTIONS subroutine reference array
#
# TIMER
# STOPTIMER
# DATE
# TIME
# SYSDATE   GMTSYSDATE
# TIMESTAMP
# TRANSACTIONID
#*****************************************************************************************
package Orbit;   # Continuation of Orbit package

use strict;
use warnings;
use utf8;
use feature ':5.16';


#-----------------------------------------------------------------------------
# LoadDateFunctions
#   - Load the Date OML Functions into the _OML_FUNCTIONS subroutine reference array
#
sub Orbit::LoadDateFunctions
{
  my ( $O ) = @_;
  $O->{_OML_FUNCTIONS}->{'TIMER'}         = sub { $O->omlTIMER(), };
  $O->{_OML_FUNCTIONS}->{'STOPTIMER'}     = sub { $O->omlSTOPTIMER(), };
  $O->{_OML_FUNCTIONS}->{'DATE'}          = sub { $O->omlDATE(), };
  $O->{_OML_FUNCTIONS}->{'TIME'}          = sub { $O->omlTIME(), };
  $O->{_OML_FUNCTIONS}->{'SYSDATE'}       = sub { $O->omlSYSDATE(), };
  $O->{_OML_FUNCTIONS}->{'GMTSYSDATE'}    = sub { $O->omlSYSDATE(), };
  $O->{_OML_FUNCTIONS}->{'TIMESTAMP'}     = sub { $O->omlTIMESTAMP(), };
  $O->{_OML_FUNCTIONS}->{'TRANSACTIONID'} = sub { $O->omlTRANSACTIONID(), };
} #LoadDateFunctions
# Alias - Function Group Date 05
*LoadFunctionGroup05 = \&LoadDateFunctions;


#-----------------------------------------------------------------------------
#-- Check for the TIMER function - #TIMER[]#
#-- - Set and return the PAGE_TIME token for elapsed milliseconds (ms)
#--
sub Orbit::omlTIMER
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  # Get the end time and compute elapsed time
  use Time::HiRes qw(time);
  # Log the end time in ms and set Token PAGE_TIMER for difference
  my $Time = time;
  $self->{_iEndTime} = int($Time*1000);
  my $Diff = $self->{_iEndTime} - $self->{_iStartTime};
  $self->Set_Token('PAGE_TIME', $Diff."ms");
  # Free up our local Function Argument copy
  undef @FunArgs;
  return $Diff."ms";
}


#-----------------------------------------------------------------------------
#-- Check for the STOPTIMER function - #STOPTIMER[]#
#-- - Return the elapsed milliseconds (ms) since the last STOPTIMER or TIMER
#--
sub Orbit::omlSTOPTIMER
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  # Get the time and compute elapsed time since last iEndTime
  use Time::HiRes qw(time);
  # Log the end time in ms
  my $Time = time;
  my $now = int($Time*1000);

  # Set end time if not set yet for this page
  if ($self->{_iEndTime} == 0
    ||$self->{_iEndTime} < $self->{_iStartTime}
      ) {
    $self->{_iEndTime} = $self->{_iStartTime};
  }
  
  my $Diff = $now - $self->{_iEndTime};
  $self->{_iEndTime} = $now;
  # Free up our local Function Argument copy
  undef @FunArgs;
  return $Diff."ms";
}


#-----------------------------------------------------------------------------
#-- Check for the DATE function - #DATE[format][timezone][bGMT(0/1)]#
#-- - Returns the current DATE ONLY with decorations based on timezone,
#-- - in GMT (1) or server time (0)
#-- - Date format masks: YYYY.YY.MM DD Y1/M1/D1 MON MONTH DAY DY (mixed case applies)
sub Orbit::omlDATE
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $U = $self->{_Utils};
  use Core::Dates;
  my $a1 = $self->GetArgParse(1, @FunArgs);
  my $a2 = $self->GetArgParse(2, @FunArgs);
  my $a3 = $self->GetArgParse(3, @FunArgs);
  my $V = $U->Get_Date($a1, $a2, $a3);
  # Free up our local Function Argument copy
  undef @FunArgs;
  return $V;
}


#-----------------------------------------------------------------------------
#-- Check for the TIME function - #TIME[format][timezone][bGMT(0/1)]#
#-- - Returns the current DATE ONLY with decorations based on timezone,
#-- - in GMT (1) or server time (0)
#-- - Time format masks: HH24 H24 HH:MI:SS H1:MIN:SEC S1 AM PM HOUR Hour (mixed case applies)
#--
sub Orbit::omlTIME
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $U = $self->{_Utils};
  use Core::Dates;
  my $a1 = $self->GetArgParse(1, @FunArgs);
  my $a2 = $self->GetArgParse(2, @FunArgs);
  my $a3 = $self->GetArgParse(3, @FunArgs);
  my $V = $U->Get_Time($a1, $a2, $a3);
  # Free up our local Function Argument copy
  undef @FunArgs;
  return $V;
}


#-----------------------------------------------------------------------------
#-- Check for the SYSDATE function - #SYSDATE[<format>]#
#-- Check for the GMTSYSDATE function - #GMTSYSDATE[<format>]#
#-- Aliases: GMTSYSDATE
sub Orbit::omlSYSDATE
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $Function = $self->{_Function};   # Get Function name (certain functions, usually for aliases or overloads)
  my $U = $self->{_Utils};
  my $V = "";
  use Core::Timestamp;
  use Core::Dates;
  #-- Get the base text ($V)
  my $a1 = $self->GetArgParse(1, @FunArgs);
  if ($Function eq 'GMTSYSDATE') {
    if ($a1 ne "") {
      $V = $U->Get_Date($a1, "", 1);   # GMT
    } else {
      $V = $U->gmt_sysdate();
    }
  } else {
    if ($a1 ne "") {
      $V = $U->Get_Date($a1, "", 0);   # Local
    } else {
      $V = $U->sysdate();
    }
  }
  # Free up our local Function Argument copy
  undef @FunArgs;
  return $V;
}


#-----------------------------------------------------------------------------
#-- Check for the TIMESTAMP function - #TIMESTAMP[DateTimeSep]#
#-- Returns the full date and time with no decorations, optional DateTimeSep (like _.)
#--
sub Orbit::omlTIMESTAMP
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $U = $self->{_Utils};
  use Core::Timestamp;
  my $a1 = $self->GetArgParse(1, @FunArgs);
  my $V = $U->Timestamp($a1);
  # Free up our local Function Argument copy
  undef @FunArgs;
  return $V;
}


#-----------------------------------------------------------------------------
#-- Check for the TRANSACTIONID function - #TRANSACTIONID[]#
#--
sub Orbit::omlTRANSACTIONID
{
  my ($self) = @_;
  #-- Return the next Transaction ID
  return $self->TransactionID();
}


#******************************************************************************************
# Return true to show package was loaded with
# use Orbit::OML::Function::Date;
#******************************************************************************************
1;


#END Orbit::OML:Function::Date Package
