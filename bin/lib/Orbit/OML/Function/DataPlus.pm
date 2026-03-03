#!/usr/bin/perl
# Version 7.0.0.0      17-Jun-2021
#*****************************************************************************************
#*
#* Orbit::OML::Function::DataPlus - Version 7
#*
#*  Package Name    :   Orbit::OML:Function::DataPlus
#*
#*  Description     :   Implements Orbit Markup Language (OML) for DATAPLUS Functions
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
# LoadDataPlusFunctions()
#   - Load the Data Plus OML Functions into the _OML_FUNCTIONS subroutine reference array
#
# SetDotDotWPP <Root> <Word>
#   - Returns the relative ../ path off of the DomainDir based on the depth of the Root-Word
#   - Also sets the DOTDOT Token for use in pages, relatively speaking
#
# SetDotDot <Path>
#   - Returns the relative ../ path off of the DomainDir based on the Directory Path entered
#   - Also sets the DOTDOT Token for use in pages
#
# DATAOPEN
# DATAPATH
# DOTDOT
# DATACLOSE
# DATASEP
# DATASORT
# DATAHEADER
# DATASEARCH
# DATAREAD
# DATAFORMAT
# DATAREC    REC    RECORD
#*****************************************************************************************
package Orbit;   # Continuation of Orbit package

use strict;
use warnings;
use utf8;
use feature ':5.16';


#-----------------------------------------------------------------------------
#
# DATA PROCESSING FUNCTIONS USED LESS FREQUENTLY AT THE END
#
#-----------------------------------------------------------------------------

#-----------------------------------------------------------------------------
# LoadDataPlusFunctions
#   - Load the Data Plus OML Functions into the _OML_FUNCTIONS subroutine reference array
#
sub Orbit::LoadDataPlusFunctions
{
  my ( $O ) = @_;
  $O->{_OML_FUNCTIONS}->{'DATAOPEN'}    = sub { $O->omlDATAOPEN(), };
  $O->{_OML_FUNCTIONS}->{'DATAPATH'}    = sub { $O->omlDATAOPEN(), };
  $O->{_OML_FUNCTIONS}->{'DOTDOT'}      = sub { $O->omlDATAOPEN(), };
  
  $O->{_OML_FUNCTIONS}->{'DATACLOSE'}   = sub { $O->omlDATACLOSE(), };
  $O->{_OML_FUNCTIONS}->{'DATASEP'}     = sub { $O->omlDATASEP(), };
  $O->{_OML_FUNCTIONS}->{'DATASORT'}    = sub { $O->omlDATASORT(), };
  
  $O->{_OML_FUNCTIONS}->{'DATAHEADER'}  = sub { $O->omlDATAHEADER(), };
  $O->{_OML_FUNCTIONS}->{'DATASEARCH'}  = sub { $O->omlDATASEARCH(), };
  $O->{_OML_FUNCTIONS}->{'DATAREAD'}    = sub { $O->omlDATAREAD(), };
  $O->{_OML_FUNCTIONS}->{'DATAFORMAT'}  = sub { $O->omlDATAFORMAT(), };
  
  $O->{_OML_FUNCTIONS}->{'DATAREC'}     = sub { $O->omlDATAREC(), };
  $O->{_OML_FUNCTIONS}->{'REC'}         = sub { $O->omlDATAREC(), };
  $O->{_OML_FUNCTIONS}->{'RECORD'}      = sub { $O->omlDATAREC(), };

} #LoadDataPlusFunctions
# Alias - Function Group Data Plus 71
*LoadFunctionGroup71 = \&LoadDataPlusFunctions;


#******************************************************************************************
# SetDotDotWPP <Root> <Word>
#
#   - Returns the relative ../ path off of the DomainDir based on the depth of the Root-Word
#   - Also sets the DOTDOT Token for use in pages, relatively speaking
#******************************************************************************************/
sub Orbit::SetDotDotWPP
{
  my ($self, $Root, $Word) = @_;
  my $A = $self->{_Akashic};
  $Root = $A->StandardizeRoot($Root);
  #
  # Set the DOTDOT Token
  #
  # Get the Relative Word Directory
  my $RelWordDir = $Root.'/'.$A->GetTextDir($Root, $Word, 1);
  # Count the number of / directory levels
  my $RelTmp = $RelWordDir;
  $RelTmp =~ s/\///g;
  my $DotDotCnt = length($RelWordDir) - length($RelTmp);
  my $DotDots = './';
  for (my $i=0; $i<$DotDotCnt; $i++) {
    $DotDots .= '../';
  }
  # Set the DotDot Token
  $self->Set_Token('DOTDOT', $DotDots);
  return $DotDots;
} #SetDotDotWPP


#******************************************************************************************
# SetDotDot <Path>
#
#   - Returns the relative ../ path off of the DomainDir based on the Directory Path entered
#   - Also sets the DOTDOT Token for use in pages
#******************************************************************************************/
sub Orbit::SetDotDot
{
  my ($self, $Path) = @_;
  # Get the Relative Word Directory
  my $RelDir = $Path;
  # Count the number of / directory levels
  my $RelTmp = $RelDir;
  $RelTmp =~ s/\///g;
  my $DotDotCnt = length($RelDir) - length($RelTmp);
  my $DotDots = './';
  for (my $i=0; $i<$DotDotCnt; $i++) {
    $DotDots .= '../';
  }
  # Set the DotDot Token
  $self->Set_Token('DOTDOT', $DotDots);
  return $DotDots;
} #SetDotDot


#-----------------------------------------------------------------------------
#-- Check for the DATAOPEN function - #DATAOPEN[Root][Word/Phrase/Path][DataFile].[Sep].[Sort]#
#-- Sets the datafile location based on Root (off of Domain), Word/Phrase/Path index, and datafile (ie CATS.dat);
#-- Separator and Sort flag can also be set in this call.
#-- Alias:   DATAPATH   - Returns Relative DataPath
#--          DOTDOT     - Returns the relative ../ path off of the DomainDir based on the depth of the Root-Word
#--                     - Also sets the DOTDOT Token for use in pages, relatively speaking
#--
sub Orbit::omlDATAOPEN
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  # Get Function name (certain functions, usually for aliases or overloads)
  my $Function = $self->{_Function};
  my $V = "";   # Return value
  my $root     = $self->GetArgParse(1, @FunArgs);   #ROOT
  $root = $self->{_Akashic}->StandardizeRoot($root);
  my $word     = $self->GetArgParse(2, @FunArgs);   #WORD/PHRASE/PATH
  my $datafile = $self->GetArgParse(3, @FunArgs);   #DATAFILE
  my $SEP      = $self->GetArgParse(4, @FunArgs);   #sep
  my $sort     = $self->GetArgParse(5, @FunArgs);   #sort

  #
  # Make sure datafile exists
  #
  my $DataPath;
  # See if we're getting the DATAPATH relative path on return - DATAOPEN returns full path
  if ($Function eq 'DATAOPEN') {
    $DataPath = $self->{_Akashic}->GetWordDataFileDir($root, $word, $datafile);

  } elsif ($Function eq 'DATAPATH') {
    # Relative path
    if ($datafile ne '') {
      $DataPath = $root.'/'.$self->{_Akashic}->GetWordDataFileDir($root, $word, $datafile, 1);   # bRelPath=1
    } else {
      # No datafile, so return relative Word Directory
      $DataPath = $root.'/'.$self->{_Akashic}->GetTextDir($root, $word, 1);   # bRelPath=1
    }
    # Set return value to relative DataPath
    $V = $DataPath;

  } elsif ($Function eq 'DOTDOT') {
    $DataPath = '';   # Don't need a path - just return ../../
    $V = $self->SetDotDot($root, $word);
    undef @FunArgs;
    return $V;
  }
  if ($DataPath ne "") {
    $self->{_DATAROOT} = $root;       # Data Root under Domain. Set with DATAOPEN
    $self->{_DATAWORD} = $word;       # Word/Phrase/Path under Root
    $self->{_DATAFILE} = $datafile;   # Datfile name (ie CATS.dat)
    $self->{_DATAPATH} = $DataPath;   # Full or Relative DataPath Directory
    # Set the Data Separator
    if ($SEP ne "") {
      $self->{_DATASEP}  = $SEP;   # Separator
    }
    # Set the Sort flag
    if ($sort ne "") {
      $self->{_DATASORT} = $self->Eval($sort);   # Sort Flag
    }
  } else {
    #
    $V = "DATAOPEN: Datafile not found ($root)($word)($datafile)";
    # Unset stored values
    $self->{_DATAROOT} = '';
    $self->{_DATAWORD} = '';
    $self->{_DATAFILE} = '';
    $self->{_DATAPATH} = '';
    $self->{_DATASEP}  = '|';
    $self->{_DATASORT} = '0';
   }

  #
  # Free up our local Function Argument copy
  #
  undef @FunArgs;

  return $V;
} #omlDATAOPEN


#-----------------------------------------------------------------------------
#-- Check for the DATACLOSE function - #DATACLOSE[Root][Word/Phrase/Path][DataFile]#
#-- Closes the datafile and frees up the internal arrays
#-- This procedure is formally not needed, but supported for different datasets in the future, and generally good programming practice
#--
sub Orbit::omlDATACLOSE
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $V = "";
  $self->{_DATAROOT} = '';       # Data Root under Domain. Set with DATAOPEN
  $self->{_DATAWORD} = '';       # Word/Phrase/Path under Root
  $self->{_DATAFILE} = '';       # Datfile name (ie CATS.dat)
  # Undefine data and columns
  undef $self->{_COLUMNS};
  undef $self->{_DATA};
  undef $self->{_STATS};

  #
  # Free up our local Function Argument copy
  #
  undef @FunArgs;

  return $V;
} #omlDATACLOSE


#-----------------------------------------------------------------------------
#-- Check for the DATASEP function - #DATASEP[Separator]#
#-- Defines the data separator for columns and data in the datafile
#--
sub Orbit::omlDATASEP
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $a1    = $self->GetArgParse(1, @FunArgs);   #sep
  if ($a1 ne "") {
    $self->{_DATASEP} = $a1;
  }

  #
  # Free up our local Function Argument copy
  #
  undef @FunArgs;

  return "";
} #omlDATASEP


#-----------------------------------------------------------------------------
#-- Check for the DATASORT function - #DATASORT[SortFlag]#
#-- Set option to sort data when reading (1/0)
#--
sub Orbit::omlDATASORT
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $a1    = $self->GetArgParse(1, @FunArgs);   #sort
  $self->{_DATASORT} = $self->Eval($a1);
  my $V = '';

  #
  # Free up our local Function Argument copy
  #
  undef @FunArgs;

  return $V;
} #omlDATASORT

#-----------------------------------------------------------------------------
#-- Check for the DATAHEADER function - #DATAHEADER[HeaderFlag]#
#-- Set Header Flag (1/0) indicating data has a header record
#--
sub Orbit::omlDATAHEADER
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $a1    = $self->GetArgParse(1, @FunArgs);   #sort
  $self->{_DATAHEADER} = $self->Eval($a1);
  my $V = '';



   #,_COLUMNS       => { }             # Columns Names (Headers) retrieved from a dataset (array)
   #,_DATA          => { }             # Data retrieved from a source
   #,_STATS         => { }             # Summarized Data stats based on user configuration
   #,_DATAROOT      => ''              # Data Root under Domain. Set with DATAOPEN
   #,_DATAWORD      => ''              # Word/Phrase/Path under Root
   #,_DATAFILE      => ''              # Datfile name (ie CATS.dat)
   #,_DATASEP       => '|'             # Default data and column separator
   #,_DATACOLS      => 0               # Flag to indicate if datafile has a header record defining columns (1/0)
   #,_DATASORT      => 0               # Flag to sort datafiles (numeric sort, then character sort) (1/0)

   #    ,'DATAREAD'     #
   #    ,'DATAFORMAT'   #
   #    ,'DATASEARCH'   #

  #
  # Free up our local Function Argument copy
  #
  undef @FunArgs;

  return $V;
} #omlDATAHEADER

#-----------------------------------------------------------------------------
#-- Check for the DATAREAD function - #DATAREAD[StartRow][MaxRows]#
#-- Read rows of the datafile into the internal buffer - use DATAFORMAT to print
#--
sub Orbit::omlDATAREAD
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $V = "";
  # Make sure we have data set in cache
  return $V if ($self->{_DATAWORD} eq "" || $self->{_DATAFILE} eq "");

  my $StartRow = $self->GetArgParse(5, @FunArgs);
  my $MaxRows  = $self->GetArgParse(6, @FunArgs);
  $StartRow = 1 if (!$self->IsNumber($StartRow));
  $MaxRows = -1 if (!$self->IsNumber($MaxRows));

  # Get the section of data from
  if ($StartRow <= %{$self->{_DATA}}) {
    for (my $i=0; $i<$StartRow+$MaxRows-1 || $MaxRows==-1; $i++)
    {
      last if (!defined($self->{_DATA}->{$i}));
      #if () {
      #}
    }
  }

  #
  # Free up our local Function Argument copy
  #
  undef @FunArgs;

  return $V;
} #omlDATAREAD

#-----------------------------------------------------------------------------
#-- Check for the DATASEARCH function - #DATASEARCH[SearchText][StartRow][MaxRows]#
#-- Searches rows of the datafile and stores in the internal buffer - use DATAFORMAT to print
#--
sub Orbit::omlDATASEARCH
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $V = "";
  # Make sure we have data set in cache
  return $V if ($self->{_DATAWORD} eq "" || $self->{_DATAFILE} eq "");

  my $Search   = $self->GetArgParse(1, @FunArgs);
  my $StartRow = $self->GetArgParse(2, @FunArgs);
  my $MaxRows  = $self->GetArgParse(3, @FunArgs);
  $StartRow = 1 if (!$self->IsNumber($StartRow));
  $MaxRows = -1 if (!$self->IsNumber($MaxRows));

  #
  # Free up our local Function Argument copy
  #
  undef @FunArgs;

  return $V;
} #omlDATASEARCH

#-----------------------------------------------------------------------------
#-- Check for the DATAFORMAT function - #DATAFORMAT[header][repeat_body][footer].[Search][StartRow][MaxRows].[silent]#
#-- Format the internal data buffer, showing header, body, footer;
#-- silent (1) shows no header/footer if no data found
#--
sub Orbit::omlDATAFORMAT
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $bFlush   = $self->{_bFlush};
  my $V = "";
  # Make sure we have data set in cache
  return $V if ($self->{_DATAWORD} eq "" || $self->{_DATAFILE} eq "");

  #-- Get the argument
  my $a1    = $self->GetArgNoParse(1, @FunArgs);   #header
  my $a2    = $self->GetArgNoParse(2, @FunArgs);   #repeat_body
  my $a3    = $self->GetArgNoParse(3, @FunArgs);   #footer
  my $Search   = $self->GetArgParse(4, @FunArgs);
  my $StartRow = $self->GetArgParse(5, @FunArgs);
  my $MaxRows  = $self->GetArgParse(6, @FunArgs);
  $StartRow = 1 if (!$self->IsNumber($StartRow));
  $MaxRows = -1 if (!$self->IsNumber($MaxRows));
  # Get 1 more than the max rows specified to show Next link
  $MaxRows++ if ($MaxRows > 0);
  my $bSilent  = $self->GetArgParse(7, @FunArgs);   #silent

  # Get the data
  my @data;
  @data = $self->{_Akashic}->GetWordData($self->{_DATAROOT}, $self->{_DATAWORD}, $self->{_DATAFILE}, $Search, $StartRow, $MaxRows);
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
    $V .= $a1."\n";
  }
  # Loop through the data
  if ($bData) {
    #
    # Set data PREV/NEXT tokens
    #
    if ($MaxRows >= 1) {
      my $start = 1;
      # Set NEXT record
      if (@data > $MaxRows) {
        $start = $StartRow + $MaxRows;
        $self->Set_Token($self->{_DATAFILE}.'_NEXT', $start);
        # Remove the extra row we added
        delete($data[$MaxRows]);
      }
      # Set PREVious record
      if ($StartRow > 1) {
        $start = $StartRow - $MaxRows;
        $start = 1 if ($start < 1);
        $self->Set_Token($self->{_DATAFILE}.'_PREV', $start);
      }
    } #if MaxRows

    # Show the keys/values SORTED from the data array
    # {$a <=> $b} to use numeric sort
    foreach my $rec (sort {$a <=> $b} (keys @data)) {
      $self->Set_Token('1', $data[$rec]);
      # Add the data
      $V .= $self->Parse($a2."\n", $bFlush);
    }
    undef @data;
  }

  # Print the footer if we have data
  if ($bData || !$bSilent) {
    # Add the footer
    $V .= $a3."\n";
  }

  #
  # Free up our local Function Argument copy
  #
  undef @FunArgs;

  return $V;
} #omlDATAFORMAT

#-----------------------------------------------------------------------------
#-- Check for the DATAREC / RECORD / REC function - #DATAREC[Root][Word/Phrase/Path][DataFile]#
#-- - Get the data record from the datafile and assign tokens to the values based on header record (if present):  !HEADER:a|b|c
#-- Aliases: RECORD REC
sub Orbit::omlDATAREC
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
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

  # Get the field from the Akashic datafile
  my $V = $self->{_Akashic}->GetWordRecord($root, $word, $datafile);

  #
  # Free up our local Function Argument copy
  #
  undef @FunArgs;

  return $V;
} #omlDATAREC


#******************************************************************************************
# Return true to show package was loaded with
# use Orbit::OML::Function::DataPlus;
#******************************************************************************************
1;


#END Orbit::OML:Function::DataPlus Package
