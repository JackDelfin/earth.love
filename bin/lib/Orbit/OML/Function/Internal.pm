#!/usr/bin/perl
# Version 7.0.0.0      17-Jun-2021
#*****************************************************************************************
#*
#* Orbit::OML::Function::Internal - Version 7
#*
#*  Package Name    :   Orbit::OML:Function::Internal
#*
#*  Description     :   Implements Orbit Markup Language (OML) for INTERNAL Functions
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
# LoadInternalFunctions
#   - Load the Internal OML Functions into the _OML_FUNCTIONS subroutine reference array
#
# DELETE
# BACKUPEXT
# NUMFORMAT
# CACHE
# UNCACHE
# DEBUG
# SHOWCOMMENTS
# MSGTRANSLATE
# MSGINSERT
# LOGSTATS
# SHOWSTATS
# LICENSE
# VERSION
#*****************************************************************************************
package Orbit;   # Continuation of Orbit package

use strict;
use warnings;
use utf8;
use feature ':5.16';


#-----------------------------------------------------------------------------
# LoadInternalFunctions
#   - Load the Internal OML Functions into the _OML_FUNCTIONS subroutine reference array
#
sub Orbit::LoadInternalFunctions
{
  my ( $O ) = @_;
  $O->{_OML_FUNCTIONS}->{'DELETE'}        = sub { $O->omlDELETE(), };
  $O->{_OML_FUNCTIONS}->{'BACKUPEXT'}     = sub { $O->omlBACKUPEXT(), };
  $O->{_OML_FUNCTIONS}->{'NUMFORMAT'}   = sub { $O->omlNUMFORMAT(), };
  $O->{_OML_FUNCTIONS}->{'CACHE'}         = sub { $O->omlCACHE(), };
  $O->{_OML_FUNCTIONS}->{'UNCACHE'}       = sub { $O->omlUNCACHE(), };
  $O->{_OML_FUNCTIONS}->{'DEBUG'}         = sub { $O->omlDEBUG(), };
  $O->{_OML_FUNCTIONS}->{'SHOWCOMMENTS'}  = sub { $O->omlSHOWCOMMENTS(), };
  $O->{_OML_FUNCTIONS}->{'MSGTRANSLATE'}  = sub { $O->omlMSGTRANSLATE(), };
  $O->{_OML_FUNCTIONS}->{'MSGINSERT'}     = sub { $O->omlMSGINSERT(), };
  $O->{_OML_FUNCTIONS}->{'LOGSTATS'}      = sub { $O->omlLOGSTATS(), };
  $O->{_OML_FUNCTIONS}->{'SHOWSTATS'}     = sub { $O->omlSHOWSTATS(), };
  $O->{_OML_FUNCTIONS}->{'LICENSE'}       = sub { $O->omlLICENSE(), };
  $O->{_OML_FUNCTIONS}->{'VERSION'}       = sub { $O->omlVERSION(), };
} #LoadInternalFunctions
# Alias - Function Group Internal 09
*LoadFunctionGroup09 = \&LoadInternalFunctions;


#-----------------------------------------------------------------------------
#-- Check for the DELETE function - #DELETE[token]...[token]#
#-- - Delete all of the TOKENs to free up memory.  Useful for large buffers in certain tokens.
#--
sub Orbit::omlDELETE
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $a1 = "";
  # Loop through all arguments to restore
  for (my $I=1; $I <= @FunArgs; $I++) {
    #-- Get the next argument
    $a1 = $self->GetArgNoParse($I, @FunArgs);
    if ($a1 ne "") {
      $self->DeleteToken($a1);
    }
  }

  # Free up our local Function Argument copy
  undef @FunArgs;
  return "";
} #omlDELETE


#-----------------------------------------------------------------------------
#-- Check for the BACKUPEXT function - #BACKUPEXT[BackupExt]#
#-- Set the default Token Backup Extension for all future calls of BACKUP and RESTORE
sub Orbit::omlBACKUPEXT
{
  my ($self) = @_;
  my $a1 = $self->GetArguments();
  # Reset internal token backup extension
  $self->{_BackupExt} = $a1 if ($a1 ne "");
  return "";   # Action function - no return value
} #omlBACKUPEXT


#-----------------------------------------------------------------------------
#-- Check for the NUMFORMAT function - #NUMFORMAT[Thousands_Sep][Decimal_Sep][Currency_Symbol]#
#-- - Set the Thousands, Decimal, Currency formats for use in FORMAT
#--
sub Orbit::omlNUMFORMAT
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $U = $self->{_Utils};
  my $V = "";   # no return from this function
  #-- Get the base text ($a1)
  my $a1 = $self->GetArgParse(1, @FunArgs);
  my $a2 = $self->GetArgParse(2, @FunArgs);
  my $a3 = $self->GetArgParse(3, @FunArgs);
  #-- Set number format
  $U->SetNumberFormat($a1, $a2, $a3);

  # Free up our local Function Argument copy
  undef @FunArgs;
  return $V;
} #omlNUMFORMAT


#-----------------------------------------------------------------------------
#-- Check for the CACHE function #CACHE[<tname>][<tname2>][<tname3>]...[<tnamen>]#
#-- Set the token cache flag to 1 for specified token names tname1, 2, 3... n
#-- (MJ 12/02/2002)
#--
sub Orbit::omlCACHE
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $V = "";
  my $a1 = "";
  my $ln_raw_flag    = 0;
  my $ln_cache_flag  = 0;
  my $I = 1;
  while (1) {
    #-- Get the next argument
    $a1 = $self->GetArgParse($I, @FunArgs);
    #-- leave if there are no more arguments or the argument count exceeds 5000
    last if    (!$self->IsArg($I, @FunArgs)
              || $I > 5000);
    #-- Get all of the token record fields
    ($V, $ln_raw_flag, $ln_cache_flag) = $self->GetTokenRec($a1);
    #-- Set the cache flag to 1 (if it isn't 1 already)
    if ($ln_cache_flag != 1) {
      $self->Set_Token($a1, $V, $ln_raw_flag, 1);
    }
    #-- increment the index
    $I = $I + 1;
  }
  #-- this token function is merely a orbit-engine directive; always returns NULL
  $V = '';
  # Free up our local Function Argument copy
  undef @FunArgs;
  return $V;
} #omlCACHE


#-----------------------------------------------------------------------------
#-- Check for the UNCACHE function #UNCACHE[<tname>][<tname2>][<tname3>]...[<tnamen>]#
#-- Set the token cache flag to 0 for specified token names tname1, 2, 3... n
#-- (MJ 12/04/2002)
#--
sub Orbit::omlUNCACHE
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $V = "";
  my $a1 = "";
  my $ln_raw_flag    = 0;
  my $ln_cache_flag  = 0;
  my $I = 1;
  while (1) {
    #-- Get the next argument
    $a1 = $self->GetArgParse($I, @FunArgs);
    #-- leave if there are no more arguments or the argument count exceeds 5000
    last if    (!$self->IsArg($I, @FunArgs)
              || $I > 5000);
    #-- Get all of the token record fields
    ($V, $ln_raw_flag, $ln_cache_flag) = $self->GetTokenRec($a1);
    #-- Set the cache flag to 0 (if it isn't 0 already)
    if ($ln_cache_flag != 0) {
      $self->Set_Token($a1, $V, $ln_raw_flag, 0);
    }
    #-- increment the index
    $I = $I + 1;
  }
  #-- this token function is merely a orbit-engine directive; always returns NULL
  $V = '';
  # Free up our local Function Argument copy
  undef @FunArgs;
  return $V;
} #omlUNCACHE


#-----------------------------------------------------------------------------
#-- Check for the DEBUG function - #DEBUG[<raw_text_flag>][SearchPhrase]#
#-- if raw_text_flag = 0, show the contents of the token table in HTML table format
#-- otherwise show contents in raw format (1) without decoration - one per line
#--
sub Orbit::omlDEBUG
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  #-- Get the next argument
  my $a1 = $self->GetArgParse(1, @FunArgs);
  $a1 = '0' if ($a1 ne '1');
  my $a2 = $self->GetArgParse(2, @FunArgs);
  #-- 1 = show token table in RAW format not in a <table>
  #-- 0 = show token table in HTML <table> format
  #-- Show the Token Table
  my $V = $self->ShowTokenTable($a1, $a2, 0);   # 0 - NoPrint, buffer only

  # Free up our local Function Argument copy
  undef @FunArgs;
  return $V;
} #omlDEBUG


#-----------------------------------------------------------------------------
#-- Check for the SHOWCOMMENTS function - #SHOWCOMMENTS[1/0]# - Show the OML comments in the pages, in escaped format
#-- - Turn on/off Statistics - Level 0-9
#--
sub Orbit::omlSHOWCOMMENTS
{
  my ($self) = @_;
  my $a1 = $self->GetArguments();
  $a1 = '0' if ($a1 ne '1');
  $self->SetShowCommentsOn  if ($a1 eq '1');
  $self->SetShowCommentsOff if ($a1 eq '0');
  # Set for reference in page
  $self->Set_Token('SHOWCOMMENTS', $a1);
  return "";
} #omlSHOWCOMMENTS


#-----------------------------------------------------------------------------
#-- Check for the MSGTRANSLATE function - #MSGTRANSLATE[1/0]# - Show the OML comments in the pages, in escaped format
#-- - Turn on/off Statistics - Level 0-9
#--
sub Orbit::omlMSGTRANSLATE
{
  my ($self) = @_;
  my $a1 = $self->GetArguments();
  $a1 = '0' if ($a1 ne '1');
  $self->SetMSGTranslateOn  if ($a1 eq '1');
  $self->SetMSGTranslateOff if ($a1 eq '0');
  # Set for reference in page
  $self->Set_Token('MSGTRANSLATE', $a1);
  return "";
} #omlMSGTRANSLATE


#-----------------------------------------------------------------------------
#-- Check for the MSGINSERT function - #MSGINSERT[1/0]# - Show the OML comments in the pages, in escaped format
#-- - Turn on/off Statistics - Level 0-9
#--
sub Orbit::omlMSGINSERT
{
  my ($self) = @_;
  my $a1 = $self->GetArguments();
  $a1 = '0' if ($a1 ne '1');
  $self->SetMSGInsertOn  if ($a1 eq '1');
  $self->SetMSGInsertOff if ($a1 eq '0');
  # Set for reference in page
  $self->Set_Token('MSGINSERT', $a1);
  return "";
} #omlMSGINSERT


#-----------------------------------------------------------------------------
#-- Check for the LOGSTATS function - #LOGSTATS[0-9]#
#-- - Turn on/off Statistics - Level 0-9
#--
sub Orbit::omlLOGSTATS
{
  my ($self) = @_;
  # Don't allow changing LogStats level when running in batch mode (RefreshPageData)
  return "" if ($self->{_bBatchMode});

  my $a1 = $self->GetArguments();
  $a1 = '0' if (!$self->IsNumber($a1));
  $self->SetLogStats($a1);
  # Set for reference in page
  $self->Set_Token('LOGSTATS', $a1);

  return "";
} #omlLOGSTATS


#-----------------------------------------------------------------------------
#-- Check for the SHOWSTATS function - #SHOWSTATS[<bHTML>]#
#-- - Show the Orbit Run-time stats
#--
sub Orbit::omlSHOWSTATS
{
  my ($self) = @_;
  # Don't show statistics if running in batch mode (RefreshPageData)
  return "" if ($self->{_bBatchMode});
  
  my $a1 = $self->GetArguments();
  $a1 = '0' if ($a1 ne '1');
  my $bShowStatsBak = $self->GetShowStats();
  my $bShowOutputBak = $self->GetShowOutput();

  # Set Utils to Show Stats and buffer output
  $self->SetShowStats(1);
  $self->BufUprint(1);

  # Get the end time and compute elapsed time
  use Time::HiRes qw(time);
  # Log the end time in ms and set Token PAGE_TIMER for difference
  my $Time = time;
  $self->{_iEndTime} = int($Time*1000);
  my $Diff = $self->{_iEndTime} - $self->{_iStartTime};
  $self->Set_Token('PAGE_TIME', $Diff.'ms');
  # Add Stat for time
  $self->AddStat('_Page Time', $Diff.'ms' );

  # Show the stats and read output from buffer
  my $V = $self->ShowStats('Orbit Stats', 1, $a1);
  $V = $self->GetUprintBuf();   ### Do we still need this now - customize for Orbit
  # Reset the parametes
  $self->SetShowStats($bShowStatsBak);
  $self->SetShowOutput($bShowOutputBak);

  return $V;
} #omlSHOWSTATS


#-----------------------------------------------------------------------------
#-- Check for the License function
#-- - called like #LICENSE[]#
#--
sub Orbit::omlLICENSE
{
  my ($self) = @_;
  return 'License: AGPLv3+: GNU Affero General Public License Version 3 or later';
} #omlLICENSE

#-----------------------------------------------------------------------------
#-- Check for the VERSION function - Shows the Orbit core and OML Version info
#-- - called like #VERSION[<short_flag>]#
#--   <short_flag> = 1 - show terse or short ver info
#--
sub Orbit::omlVERSION
{
  my ($self) = @_;
  my $V = "kevin";
  my $a1 = $self->GetArguments();
  if ($a1 ne '1') {
    # Show Long Version Information
    $V = "Orbit Version: [".$self->{_VERSION}."] OML Version: [".$self->{_OML_VERSION}."}";
  } else {
    # Show Short Ver Info
    # Get Version without Date
    $a1 = substr($self->{_VERSION}, 0, index($self->{_VERSION}, ' '));
    # Get OML Version without Date
    my $a2 = substr($self->{_OML_VERSION}, 0, index($self->{_OML_VERSION}, ' '));
    # Show Msg
    $V = "Ver:[".$a1."] OML:[".$a2."}";
  }

  return $V;
} #omlVERSION


#******************************************************************************************
# Return true to show package was loaded with
# use Orbit::OML::Function::Internal;
#******************************************************************************************
1;


#END Orbit::OML:Function::Internal Package
