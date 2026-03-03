#!/usr/bin/perl
# Version 7.0.0.0      17-Jun-2021
#*****************************************************************************************
#*
#* Orbit::OML::Function::Data - Version 7
#*
#*  Package Name    :   Orbit::OML:Function::Data
#*
#*  Description     :   Implements Orbit Markup Language (OML) for DATA Functions
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
# LoadDataFunctions
#   - Load the Data OML Functions into the _OML_FUNCTIONS subroutine reference array
#
# DATA
# DATAFILE   FILE   GETFILE
# DATAFIELD  FIELD  GETFIELD  FIELDMSG
#*****************************************************************************************
package Orbit;   # Continuation of Orbit package

use strict;
use warnings;
use utf8;
use feature ':5.16';


#-----------------------------------------------------------------------------
# LoadDataFunctions
#   - Load the Data OML Functions into the _OML_FUNCTIONS subroutine reference array
#
sub Orbit::LoadDataFunctions
{
  my ( $O ) = @_;
  $O->{_OML_FUNCTIONS}->{'DATA'}      = sub { $O->omlDATA(), };
  
  $O->{_OML_FUNCTIONS}->{'DATAFILE'}  = sub { $O->omlDATAFILE(), };
  $O->{_OML_FUNCTIONS}->{'FILE'}      = sub { $O->omlDATAFILE(), };
  $O->{_OML_FUNCTIONS}->{'GETFILE'}   = sub { $O->omlDATAFILE(), };
  
  $O->{_OML_FUNCTIONS}->{'DATAFIELD'} = sub { $O->omlDATAFIELD(), };
  $O->{_OML_FUNCTIONS}->{'FIELD'}     = sub { $O->omlDATAFIELD(), };
  $O->{_OML_FUNCTIONS}->{'GETFIELD'}  = sub { $O->omlDATAFIELD(), };
  $O->{_OML_FUNCTIONS}->{'FIELDMSG'}  = sub { $O->omlDATAFIELD(), };

} #LoadDataFunctions
# Alias - Function Group Data 70
*LoadFunctionGroup70 = \&LoadDataFunctions;


#-----------------------------------------------------------------------------
#-- Check for the DATA function - #DATA[Root][Word/Phrase/Path][DataFile].[Search][StartRow][MaxRows].[header][repeat_body].[footer].[Sort].[silent]
#-- - read and show data file, using #1# #2# #3# etc for variables, separated by "sep", default "|";
#--   silent (1) shows no header/footer if no data found
#--
sub Orbit::omlDATA
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $bFlush   = $self->{_bFlush};
  my $V = "";
  my $U = $self->{_Utils};
  #-- Get the argument
  my $root     = $self->GetArgParse(1, @FunArgs);   #ROOT
  my $word     = $self->GetArgParse(2, @FunArgs);   #WORD/PHRASE/PATH
  my $datafile = $self->GetArgParse(3, @FunArgs);   #DATAFILE
  my $Search   = $self->GetArgParse(4, @FunArgs);
  my $StartRow = $self->GetArgParse(5, @FunArgs);
  my $MaxRows  = $self->GetArgParse(6, @FunArgs);
  $StartRow = 1 if (!$self->IsNumber($StartRow));
  $MaxRows = -1 if (!$self->IsNumber($MaxRows));
  # Get 1 more than the max rows specified to show Next link
  $MaxRows++ if ($MaxRows > 0);

  my $a1    = $self->GetArgNoParse(7, @FunArgs);   #header
  my $a2    = $self->GetArgNoParse(8, @FunArgs);   #repeat_body
  my $a3    = $self->GetArgNoParse(9, @FunArgs);   #footer
  my $a4    = $self->GetArgParse(10, @FunArgs);   #sep
  my $bSilent  = $self->GetArgParse(11, @FunArgs);   #silent

  # Get the data from the Akashic structure
  my @data;
  @data = $self->{_Akashic}->GetWordData($root, $word, $datafile, $Search, $StartRow, $MaxRows);

  # Reset MaxRows if modified above
  $MaxRows-- if ($MaxRows > 1);

  my $bData = 0;
  $bData = 1 if (@data > 0);

  #
  # Parse the silent arg if it contains token
  #
  $bSilent = $self->Eval($bSilent);

  # Print the header if we have data
  if ($bData || !$bSilent) {
    # Add the header
    $V .= $self->Parse($a1."\n", $bFlush);   # Parse after data is loaded
  }

  # Process the data
  if ($bData) {
    #
    # Set data PREV/NEXT tokens
    #
    if ($MaxRows >= 1) {
      my $start = 1;
      # Set NEXT record
      if (@data > $MaxRows) {
        $start = $StartRow + $MaxRows;
        $self->Set_Token($datafile.'_NEXT', $start);
        # Remove the extra row we added
        delete($data[$MaxRows]);
      }
      # Set PREVious record
      if ($StartRow > 1) {
        $start = $StartRow - $MaxRows;
        $start = 1 if ($start < 1);
        $self->Set_Token($datafile.'_PREV', $start);
      }
    } #if MaxRows

    # Loop through the data
    # Show the keys/values SORTED from the data array
    # {$a <=> $b} to use numeric sort
    foreach my $rec (sort {$a <=> $b} (keys @data)) {
      # show raw data if we don't have a header, body, or footer
      if ($a1 eq "" && $a2 eq "" && $a3 eq "") {
        $V .= $data[$rec]."\n";
      } else {
        # Set #1# to value from data record for replacement
        $self->Set_Token('1', $data[$rec]);
        # Add the data
        $V .= $self->Parse($a2."\n", $bFlush);
      }
    }

    # Free data memory
    undef @data;
  } #if bData

  # Print the footer if we have data
  if ($bData || !$bSilent) {
    # Add the footer
    $V .= $self->Parse($a3."\n", $bFlush);
  }
  # Add Token Statistic for DATA
  $self->AddStat("_Function Call: DATA") if ($self->GetLogStat());

  #
  # Free up our local Function Argument copy
  #
  undef @FunArgs;

  return $V;
} #omlDATA

#-----------------------------------------------------------------------------
#-- Check for the DATAFILE / FILE / GETFILE function - #GetFILE[Root][Word/Phrase/Path][DataFile].[Search][StartRow][MaxRows]#
#-- - Get the full text from the datafile without parsing - can be used to assign to token and show raw text with token.HTML
#-- Aliases: FILE GETFILE
sub Orbit::omlDATAFILE
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $U = $self->{_Utils};
  #-- Get the root / word / datafile arguments
  my $root     = $self->GetArgParse(1, @FunArgs);   #ROOT
  my $word     = $self->GetArgParse(2, @FunArgs);   #WORD/PHRASE/PATH
  my $datafile = $self->GetArgParse(3, @FunArgs);   #DATAFILE
  my $Search   = $self->GetArgParse(4, @FunArgs);
  my $StartRow = $self->GetArgParse(5, @FunArgs);
  my $MaxRows  = $self->GetArgParse(6, @FunArgs);
  $StartRow = 1 if (!$self->IsNumber($StartRow));
  $MaxRows = -1 if (!$self->IsNumber($MaxRows));
  # Get 1 more than the max rows specified to show Next link
  #$MaxRows++ if ($MaxRows > 0);

  # Get the field from the Akashic datafile
  my $V = $self->{_Akashic}->GetWordText($root, $word, $datafile, $Search, $StartRow, $MaxRows);

  # Add Token Statistic for DATA
  $self->AddStat("_Function Call: DATA") if ($self->GetLogStat());

  #
  # Free up our local Function Argument copy
  #
  undef @FunArgs;

  return $V;
} #omlDATAFILE

#-----------------------------------------------------------------------------
#-- Check for the DATAFIELD / FIELD / GETFIELD function
#-- #DataFIELD[Root][Word/Phrase/Path][DataFile(s) space separated][pre][post]#
#-- - Get the first record from the datafiles specified, setting tokens for each datafile like #preDATAFILEpost#
#-- Aliases: FIELD GETFIELD FIELDMSG
sub Orbit::omlDATAFIELD
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  # Get Function name (certain functions, usually for aliases or overloads)
  my $Function = $self->{_Function};
  my $U = $self->{_Utils};
  #-- Get the root / word / datafile arguments
  my $root      = $self->GetArgParse(1, @FunArgs);   #ROOT
  my $word      = $self->GetArgParse(2, @FunArgs);   #WORD/PHRASE/PATH
  my $datafiles = $U->upper($U->trim($self->GetArgParse(3, @FunArgs)));   #DATAFILE
  my $pre="";
  my $post="";
  my $V = "";
  
  # Check for multiple datafiles specified
  if (index($datafiles, ' ') == -1) {
    # Single datafile name
    # Get the field from the Akashic datafile
    $V = $self->{_Akashic}->GetWordField($root, $word, $datafiles);
    # Get the message text for the value retrieved for multiple languages
    # Check for FIELDMSG or any other variants with MSG in Function name
    $V = $self->GetMessageText( $V ) if ($Function =~ /.*MSG.*/);
    # Register the Token
    if ($self->IsArg(4, @FunArgs)) {
      $pre  = $self->GetArgParse(4, @FunArgs);   #pre token registration, ie _root_
      $post = $self->GetArgParse(5, @FunArgs);   #post token registration, ie _
      $self->Set_Token($pre.$datafiles.$post, $V);
    }
  } else {
    if ($self->IsArg(4, @FunArgs)) {
      $pre  = $self->GetArgParse(4, @FunArgs);   #pre token registration, ie _root_
      $post = $self->GetArgParse(5, @FunArgs);   #post token registration, ie _
    }
    my @DATAFILES = split(' ', $datafiles);
    foreach my $df (@DATAFILES) {
      # Get the field from the Akashic datafile
      $V = $self->{_Akashic}->GetWordField($root, $word, $df);
      # Get the message text for the value retrieved for multiple languages
      # Check for FIELDMSG or any other variants with MSG in Function name
      $V = $self->GetMessageText( $V ) if ($Function =~ /.*MSG.*/);
      # Register the Token
      $self->Set_Token($pre.$df.$post, $V);
    }
    undef @DATAFILES;
    $V = "";   # Return null for multiple field loads
  }

  # Add Token Statistic for DATAFIELD
  $self->AddStat("_Function Call: DATAFIELD") if ($self->GetLogStat());

  #
  # Free up our local Function Argument copy
  #
  undef @FunArgs;

  return $V;
} #omlDATAFIELD


#******************************************************************************************
# Return true to show package was loaded with
# use Orbit::OML::Function::Data;
#******************************************************************************************
1;


#END Orbit::OML:Function::Data Package
