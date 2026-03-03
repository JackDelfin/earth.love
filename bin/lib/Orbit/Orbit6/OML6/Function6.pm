#!/usr/bin/perl
# Version 6.1.6.0      2-Jun-2021
#*****************************************************************************************
#*
#*  Package Name    :   Orbit::OML6:Function6
#*
#*  Description     :   Implements Orbit Markup Language (OML) for Functions
#*
#*****************************************************************************************
# History:
#   2021.06.02 earth.love oK Added OPTIONS function
#   2021.04.29 earth.love oK Refactored
#   2021.04.24 earth.love oK Converted from PL/SQL Orbit package (2015.05.30 Ver 5.0.0.0)
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
package Orbit;   # Continuation of Orbit package

use strict;
use warnings;
use utf8;
use feature ':5.16';

# Orbit packages
#use Orbit::Utils;
#use Orbit::Token;

#========================================================================================
#
#                      FUNCTION OML (ORBIT MARKUP LANGUAGE) SUBROUTINES
#
#========================================================================================


#******************************************************************************************
#* Process_Function
#*
#* - Processes a Function call for an orbit token and sets the result
#*   in fv_value.  Returns TRUE if the function was processed, FALSE if not found
#* - bFlush is passed to Parse to see if we buffer or print directly to package print buf
#******************************************************************************************
sub Orbit::Process_Function
{
  my ( $self, $Function, $fv_token, $bFlush, @FunArgs ) = @_;
  my $U = $self->{_Utils};

  # Add a summary statistic
  $self->AddStat("_Function Calls Total") if ($self->GetLogStat());
  # Only add specific function if LogStat > 1
  $self->AddStat("Function: ".$U->rpad($Function,12)) if ($self->GetLogStat() > 1);

  #-- initialize the return value
  my $fv_value = "";

  #-- Variables for Get Argument call
  my $li_index       = 0;
  my $lv_arg_1       = "";
  my $lv_arg_2       = "";
  my $lv_arg_3       = "";
  my $lv_arg_4       = "";
  my $ln_value       = 0;
  my $ln_arg_1       = 0;
  my $ln_arg_2       = 0;
  my $ln_arg_3       = 0;

  #-----------------------------------------------------------------------------
  #-- Check token functions for known types
  #-- - Each token function logic below is only responsible for setting the $fv_value based on the function performed
  #-- - After this section is where the token is assigned or the $fv_value is displayed
  #-- - $Function will always be UPPER case
  #-- - $fv_arguments will be Mixed Case
  #-- - Multiple arguments are separated with ][, as in #token=NVL[valx][valy][valz]#
  #-- KR 8/3/01 - allow arguments to be separated with whitespace - space, tab, "\n", chr(13)
  #-- KR 10/30/01 - put most commonly used functions at the top for performance
  #-----------------------------------------------------------------------------

  #-----------------------------------------------------------------------------
  #-- Check for the ASSIGN function - TOKEN ASSIGNMENT   #token=[#text#]#  #ASSIGN[value][backup(1/0) or BackupExt]#
  #-- Token Assignment without parsing (also #token=[value]# without function name);
  #-- Backup (1) will set existing value of TOKEN to TOKEN_BACK as default, or
  #-- BackupExt could be set instead (ie _BACKUP).
  #-- - No parsing is done on the 1st argument
  #--
  if ($Function eq 'ASSIGN') {
    # Get the backup extension first
    $lv_arg_2 = $self->GetArgNoParse(2, @FunArgs);
    # Check for backup
    if ($lv_arg_2 ne "0" && $lv_arg_2 ne "") {
      #
      # Backup the token first
      #
      if ($lv_arg_2 eq '1') {
        # Default backup
        $self->Set_Token($fv_token.$self->{_BackupExt}, $self->Get_Token($fv_token));
      } else {
        # Use user defined backup extension
        $self->Set_Token($fv_token.$lv_arg_2, $self->Get_Token($fv_token));
      }
    }
    #
    # TOKEN ASSIGNMENT - Set return to first argument
    #
    $fv_value = $self->GetArgNoParse(1, @FunArgs);

#-----------------------------------------------------------------------------
#-- Check for the LOADTOKEN function - TOKEN Bulk Load #LOADTOKEN=[tok=value\n tok = value tok= [ value ]\n ...]#
#-- Load a list of tokens, carriage return separated, and token specified as:
#--   token = [ value ]
#--   token = value
#--   token=value
#-- - No parsing is done
#--
  } elsif ($Function eq 'LOADTOKEN'
         ||$Function eq 'LOADMSG'
         ||$Function eq 'MSGLOAD'
         ||$Function eq 'TOKENLOAD'
         ) {

  my $bMSG = 0;   # Translate messages
  $bMSG = 1 if ($Function =~ /.*MSG.*/);
  #
  # Get the CR separated list of Tokens
  #
  my $Tokens = $self->GetArgNoParse(1, @FunArgs);
  #
  # Loop through list and Set token/value pairs
  #
  if ($Tokens ne "") {
    my $tok;
    my $val;
    my $fn;   # Quick mini function
    my $split;
    my @TOKENS = split(/\n/, $Tokens);
    foreach my $tokval (@TOKENS) {
      next if ($tokval eq '');
      $split = index($tokval, '=');
      next if ($split == -1);   # Skip if bad format
      $tok = substr($tokval, 0, $split);
      $val = substr($tokval, $split+1);
      $tok = $U->trim($tok);
      next if ($tok eq '');
      $val = $U->trim($val);
      # Look for Function in Token Load
      if ($val =~ /^[a-z][a-z]*\[.*\][#]*$/i) {   # fn[.*]#
        $fn  = substr($val, 0, index($val, '['));
        $val = substr($val, index($val, '[')+1);   # Get arguments
        $val =~ s/\][#]*$//;   # remove ] suffix with or without #

        #
        # Get the Function Arguments from the $val text
        #
        my @FunArgs2;
        @FunArgs2 = $self->setFunctionArgs($val);

        # Process the Function, passing in Function, Token, and arguments array.
        # Some functions use token name: ASSIGN/BACK
        #
        my $bProcessed;
        ($val, $bProcessed) = $self->Process_Function($fn, $tok, $bFlush, @FunArgs2);
        $self->print('LoadToken: Function not processed: [$fn]') if (!$bProcessed);

        # Release memory from the Function Args2
        undef @FunArgs2;

        #
        # END Function within LOADTOKEN
        #
      } else {
        $val =~ s/^\[//;       # remove [ prefix
        $val =~ s/\][#]*$//;   # remove ] suffix with or without #
      }
      # Get the Message translation text if this is LOADMSG
      $val = $self->GetMessageText($val) if ($bMSG);
      # Store the token
      $self->Set_Token($tok, $val);
    }
    if ($self->GetLogStat()) {
      $tok = @TOKENS;
      $val = $self->GetStat('_LOADTOKEN Tokens');
      $self->AddStat('_LOADTOKEN Tokens', $tok+$val);
    }

    undef @TOKENS;
  }
  #
  # Free up our local Function Argument copy
  #
  undef @FunArgs;

  $fv_value = "";
  #omlLOADTOKEN


  #-----------------------------------------------------------------------------
  #-- Check for the INCLUDE function - #INCLUDE[<template>].[_1_].[_2_].[_3_]...[_n_]#
  #-- Defines function parameters as tokens (#_1_# #_2_# ...) based on user parameters
  #-- It is wise to assign these params at the beginning of the OML template if there are other nested calls
  #-- NOTE: These tokens are NOT unassigned after the function call, in order to support nested INC / OML calls
  #--
  } elsif ($Function eq 'INCLUDE'
         ||$Function eq 'INC'
         ||$Function eq 'OML'
         ||$Function eq 'FUNCTION'
         ) {
    # Parse the arg if it contains #*# hash tie fighter similarity
    $lv_arg_1 = $self->GetArgParse(1, @FunArgs);

    # Make sure template arg exists
    if ($lv_arg_1 ne "") {
      # Get the template filename
      my $lTemplate = $self->SearchTemplateDirs( $lv_arg_1 );

      # See if we have arguments to the include: set as #_1_# #_2_# ...
      if ($self->IsArg(2, @FunArgs)) {
        # search through each Arg and set it as a parameter to INCLUDE
        for ($li_index=2; $li_index <= @FunArgs; $li_index++) {
          #-- Get the next argument
          $lv_arg_1 = $self->GetArgNoParse($li_index, @FunArgs);
          # Set the token argument offset by 1.  #_1_#
          $self->Set_Token('_'.($li_index-1).'_', $lv_arg_1);
        }
      }

      # Get the template if it exists
      if (-e $lTemplate) {
        # Get the file contents and done
        $fv_value = $U->GetFile($lTemplate, 1);
        # Strip out the developer comments <!--- ---> before returning
        # Only show comments if we're flushing and ShowComments are on,
        # otherwise it could be a return value in token assign
        my $bRawComments = ($self->{_bShowComments} && $bFlush)?1:0;
        $fv_value = $self->StripComments($fv_value, $bRawComments);
        # Parse the results
        $fv_value = $self->Parse($fv_value, $bFlush);
      } else {
        $fv_value = "INCLUDE: Template not found [$lv_arg_1]";
      }
      # Unset the #_x_# parameter tokens after call is done
      if ($self->IsArg(2, @FunArgs)) {
        for ($li_index=2; $li_index <= @FunArgs; $li_index++) {
          # Set the token argument offset by 1.  #_1_#
          $self->Delete_Token('_'.($li_index-1).'_');
        }
      }

      # Add Token Statistic for INCLUDE
      $self->AddStat("_Function Call: INCLUDE") if ($self->GetLogStat());

    }   # Ignore null INCLUDE: i.e. #INCLUDE[#notfound#]# - feature to pass in optional token

  #-----------------------------------------------------------------------------
  #-- Check for the IFINCLUDE function - #IFINCLUDE[<expression>][then<template>].[else<template>].[_1_].[_2_].[_3_]...[_n_]#
  #--
  } elsif ($Function eq 'IFINCLUDE'
         ||$Function eq 'INCLUDEIF'
         ||$Function eq 'INCIF'
         ||$Function eq 'IFINC'
         ||$Function eq 'OMLIF'
         ||$Function eq 'IFOML'
         ||$Function eq 'BEFORE'
         ||$Function eq 'AFTER'
         ||$Function eq 'SHOWON'
         ) {
  my $V = "";
  #-- Get the expression argument
  my $Expression = $self->GetArgNoParse(1, @FunArgs);
  my $Template = "";
  my $Eval = 0;
  my $Stop = 0;
  # Check for function type
  if ($Function =~ /.*IF.*/) {
    $Eval = $self->Eval($Expression);
  } else {
    # BEFORE / AFTER / SHOWON
    $Eval = $U->CompareDates($Expression, $U->Timestamp());
    $Stop = 1;
    $Stop = 0 if ($Eval == -1 && $Function eq 'BEFORE');
    $Stop = 0 if ($Eval == 1  && $Function eq 'AFTER');
    $Stop = 0 if ($Eval == 0  && $Function eq 'SHOWON');
  }
  #
  if ($Eval) {
    #-- Expression was true, so value is the <then> part of the expression
    $Template = $self->GetArgParse(2, @FunArgs);
    #-- have to have at least a <then> for IF, else is optional
    if (!$self->IsArg(2, @FunArgs)) {
      $Template = $self->GetFunctionError($Function);
    }
  } else {
    #-- Expression was false, so value is the <else> part of the expression
    $Template = $self->GetArgParse(3, @FunArgs);
  }
  # Make sure template exists
  if ($Template ne "") {
    # Get the template filename
    my $TempleFile = $self->SearchTemplateDirs( $Template );

    # See if we have arguments to the include: set as #_1_# #_2_# ...
    if ($self->IsArg(4, @FunArgs)) {
      # search through each Arg and set it as a parameter to INCLUDE
      for (my $I=4; $I <= @FunArgs; $I++) {
        # Set the token argument offset by 1.  #_1_#
        $self->Set_Token('_'.($I-3).'_', $self->GetArgNoParse($I, @FunArgs));
      }
    }

    # Get the template if it exists
    if (-e $TempleFile) {
      # Get the file contents and done
      $V = $U->GetFile($TempleFile, 1);
      # Strip out the developer comments <!--- ---> before returning
      # Only show comments if we're flushing and ShowComments are on,
      # otherwise it could be a return value in token assign
      my $bRawComments = ($self->{_bShowComments} && $bFlush)?1:0;
      $V = $self->StripComments($V, $bRawComments);
      # Parse the results
      $V = $self->Parse($V, $bFlush);
    } else {
      $V = "IFINCLUDE: Template not found [$Template]";
    }
    # Unset the #_x_# parameter tokens after call is done
    if ($self->IsArg(2, @FunArgs)) {
      for (my $I=2; $I <= @FunArgs; $I++) {
        # Set the token argument offset by 1.  #_1_#
        $self->Delete_Token('_'.($I-1).'_');
      }
    }
    # Add Token Statistic for INCLUDE
    $self->AddStat("_Function Call: INCLUDE") if ($self->GetLogStat());
  }

  # See if the BEFORE AFTER SHOWON needs to stop
  if ($Stop) {
    #-- Expression was true, so Halt execution of the current page
    $V = '!!HALT_EXECUTION!!'.$V;
  }

  $fv_value = $V;
#omlIFINCLUDE

  #-----------------------------------------------------------------------------
  #-- Check for the DATA function - #DATA[Root][Word/Phrase/Path][DataFile].[Search][StartRow][MaxRows].[header][repeat_body].[footer].[Sort].[silent]
  #-- - read and show data file, using #1# #2# #3# etc for variables, separated by "sep", default "|";
  #--   silent (1) shows no header/footer if no data found
  #--
  } elsif ($Function eq 'DATA') {
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

    $lv_arg_1    = $self->GetArgNoParse(7, @FunArgs);   #header
    $lv_arg_2    = $self->GetArgNoParse(8, @FunArgs);   #repeat_body
    $lv_arg_3    = $self->GetArgNoParse(9, @FunArgs);   #footer
    $lv_arg_4    = $self->GetArgParse(10, @FunArgs);   #sep
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
      $fv_value .= $self->Parse($lv_arg_1."\n", $bFlush);   # Parse after data is loaded
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
        if ($lv_arg_1 eq "" && $lv_arg_2 eq "" && $lv_arg_3 eq "") {
          $fv_value .= $data[$rec]."\n";
        } else {
          # Set #1# to value from data record for replacement
          $self->Set_Token('1', $data[$rec]);
          # Add the data
          $fv_value .= $self->Parse($lv_arg_2."\n", $bFlush);
        }
      }

      # Free data memory
      undef @data;
    } #if bData

    # Print the footer if we have data
    if ($bData || !$bSilent) {
      # Add the footer
      $fv_value .= $self->Parse($lv_arg_3."\n", $bFlush);
    }
    # Add Token Statistic for DATA
    $self->AddStat("_Function Call: DATA") if ($self->GetLogStat());

  #-----------------------------------------------------------------------------
  #-- Check for the DATAFILE / FILE / GETFILE function - #GetFILE[Root][Word/Phrase/Path][DataFile].[Search][StartRow][MaxRows]#
  #-- - Get the full text from the datafile without parsing - can be used to assign to token and show raw text with token.HTML
  #--
  } elsif ($Function eq 'DATAFILE'
         ||$Function eq 'FILE'
         ||$Function eq 'GETFILE'
         ) {
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
    $fv_value = $self->{_Akashic}->GetWordText($root, $word, $datafile, $Search, $StartRow, $MaxRows);

    # Add Token Statistic for DATA
    $self->AddStat("_Function Call: DATA") if ($self->GetLogStat());

  #-----------------------------------------------------------------------------
  #-- Check for the DATAFIELD / FIELD / GETFIELD function - #DataFIELD[Root][Word/Phrase/Path][DataFile]#
  #-- - Get the first record from the datafile
  #--
  } elsif ($Function eq 'DATAFIELD'
         ||$Function eq 'FIELD'
         ||$Function eq 'FIELDMSG'
         ||$Function eq 'GETFIELD'
         ) {
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

  $fv_value = $V;


  #-----------------------------------------------------------------------------
  #-- Check for the IF function - #IF[<expression>][<then>][<else>]#
  #--
  } elsif ($Function eq 'IF') {
    #-- Get the expression argument
    $lv_arg_1 = $self->GetArgNoParse(1, @FunArgs);
    #
    if ($self->Eval($lv_arg_1)) {
      #-- Expression was true, so value is the <then> part of the expression
      $fv_value = $self->GetArgParse(2, @FunArgs);
      #-- have to have at least a <then> for IF, else is optional
      if (!$self->IsArg(2, @FunArgs)) {
        $fv_value = $self->GetFunctionError($Function);
      }
    } else {
      #-- Expression was false, so value is the <else> part of the expression
      $fv_value = $self->GetArgParse(3, @FunArgs);
    }

  #-----------------------------------------------------------------------------
  #-- Check for the MSG function - #MSG[<code>][<message_text>][<message_help>][<comment_text>]#
  #--
  } elsif  ($Function eq 'MSG'
          ||$Function eq 'MESSAGE'
          ||$Function eq 'MSGHELP'
          ||$Function eq 'MSGLIST'
            ) {
    $lv_arg_1 = $self->GetArgParse(1, @FunArgs);  #-- Message Code
    if ($lv_arg_1 ne "") {
      $fv_value = $self->GetArgNoParse(2, @FunArgs);  #-- Message Text
      if ($self->IsArg(2, @FunArgs)) {
        $lv_arg_2 = $self->GetArgNoParse(3, @FunArgs);  #-- Help Text
        if ($self->IsArg(3, @FunArgs)) {
          $lv_arg_3 = $self->GetArgNoParse(4, @FunArgs);  #-- Comment Text
        }
      }
      #-- Get the message text for the code specified
      #-- and the user or country default language
      $fv_value = $self->GetMessageText( $lv_arg_1, $fv_value, $lv_arg_2, $lv_arg_3 );
    }
  #-----------------------------------------------------------------------------
  #-- Check for the MSG function - #MSG[<code>][<message_text>][<message_help>][<comment_text>]#
  #--
  } elsif  ($Function eq 'LANGUAGE'
          ||$Function eq 'LANG'
          ||$Function eq 'SETLANG'
          ||$Function eq 'MSGTRANSLATE'
          ||$Function eq 'MSGINSERT'
            ) {
    # NOT IMPLEMENTED ORBIT 6
    $fv_value = "";

  #-----------------------------------------------------------------------------
  #-- Check for the NVL function - #NVL[val1][val2]...[valn]#
  #-- Returns the first non null (blank) argument
  #--
  } elsif ($Function eq 'NVL') {
    $fv_value = "";

    # search through each Arg and if any is false, return 0
    for ($li_index=1; $li_index <= @FunArgs; $li_index++) {
      #-- Get the next argument
      $fv_value = $self->GetArgParse($li_index, @FunArgs);

      # Check for empty argument (default: FALSE in AND function)
      last if ($fv_value ne "");
    }
  #-----------------------------------------------------------------------------
  #-- Check for the DECODE function
  #-- - #DECODE[<text>][<if>][<then>][<if>][<then>]...[<else>]#
  #-- - #DECODELIKE[<text>][<if>][<then>][<if>][<then>]...[<else>]#
  #--
  } elsif  ($Function eq 'DECODE'
          ||$Function eq 'CASE'
          ||$Function eq 'DECODELIKE'
          ) {
    use Core::Like;
    my $lb_like = 0;
    if ($Function eq 'DECODELIKE'
      ||$Function eq 'CASE'
      ) {
      $lb_like = 1;
    } else {
      $lb_like = 0;
    }
    #-- Get the base text ($fv_value)
    $lv_arg_1 = $self->GetArgParse(1, @FunArgs);   #text
    $lv_arg_2 = $self->GetArgParse(2, @FunArgs);   #if
    my $argFound = $self->IsArg(2, @FunArgs);
    if ($argFound) {
      $li_index = 4;
      while (1) {
        #-- leave if we have a not null or there are no more arguments or the argument count exceeds 500
        last if (!$argFound || $li_index > 5000);
        #-- See if the <text> equals the <if>
        if ($lb_like) {
          if (  $U->like($lv_arg_1, $lv_arg_2)
             || $U->like($lv_arg_2, $lv_arg_1)
             || ($lv_arg_1 eq "" && $lv_arg_2 eq "")
             ) {
            $fv_value = $self->GetArgParse($li_index-1, @FunArgs);   #then
            last;
          }
        } else {
          if (  $lv_arg_1 eq $lv_arg_2
             || ($lv_arg_1 eq "" and $lv_arg_2 eq "")
             ) {
            $fv_value = $self->GetArgParse($li_index-1, @FunArgs);   #then
            last;
          }
        }
        #-- Get the next argument - either an <if> or an <else>
        $lv_arg_2 = $self->GetArgParse($li_index, @FunArgs);
        $argFound = $self->IsArg($li_index, @FunArgs);
        #-- leave if this was not found (no <else> specified
        last if (!$argFound);
        #-- Check for <else> clause
        if (!$self->IsArg($li_index+1, @FunArgs)) {
          #-- The prior get was the else, so just return it
          $fv_value = $lv_arg_2;
          last;
        }
        #-- increment the index
        $li_index = $li_index + 2;
      }
    } else {
      $fv_value = $self->GetFunctionError($Function);
    }
  #-----------------------------------------------------------------------------
  #-- Check for the PARSE function #<token>=PARSE[<expression>]#
  #--
  } elsif  ($Function eq 'PARSE') {
    #-- Parse the first argument and return (MJ 2002/12/27)
    $fv_value = $self->GetArgParse(1, @FunArgs);

  #-----------------------------------------------------------------------------
  #-- Check for the STOP function - Halt execution of the current page - #STOP[<expression>]#
  #--
  } elsif  ($Function eq 'STOP') {
    #-- Get the expression argument
    $lv_arg_1= $self->GetArgParse(1, @FunArgs);
    if ($self->Eval($lv_arg_1)) {
      #-- Expression was true, so Halt execution of the current page
      $fv_value = '!!HALT_EXECUTION!!';
    }

  #-----------------------------------------------------------------------------
  #-- Check for the RESTORE function - #RESTORE[token]...[token]#
  #-- Restore all of the token values to TOKEN_BACK. Only uses default Backup Extension
  } elsif ($Function eq 'RESTORE') {
  $fv_value = "";   # Action function - no return value
  my $Tokens="";
  # Loop through all arguments to restore
  for (my $I=1; $I <= @FunArgs; $I++) {
    #-- Get the next argument
    $Tokens = $self->GetArgNoParse($I, @FunArgs);
    if ($Tokens ne "") {
    }

    # Check for multiple tokens space separated
    if (index($Tokens, ' ') == -1) {
      # Single token
      $self->Set_Token($Tokens, $self->Get_Token($Tokens.$self->{_BackupExt})) if ($Tokens ne "");
    } else {
      # Multiple tokens specified
      my @TOKENS = split(' ', $Tokens);
      foreach my $tok (@TOKENS) {
        $self->Set_Token($tok, $self->Get_Token($tok.$self->{_BackupExt})) if ($tok ne "");
      }
      undef @TOKENS;
    }
  }

  #-----------------------------------------------------------------------------
  #-- Check for the AND function - #AND[<val1>][<val2>]...[<valn>]#
  #-- Returns 1 if all of the expressions (vals) are true, 0 otherwise
  #-- NOTE: NULL arguments are TRUE expressions
  #--
  } elsif ($Function eq 'AND') {
    # default response to 1
    $fv_value = '1';
    my $lEval = "";

    # search through each Arg and if any is false, return 0
    for ($li_index=1; $li_index <= @FunArgs; $li_index++) {
      #
      #-- Get the next argument
      #
      $lv_arg_1 = $self->GetArgNoParse($li_index, @FunArgs);

      # Check for empty argument (default: FALSE in AND function)
      if ($lv_arg_1 ne "") {
        $lEval = $self->Eval($lv_arg_1);
        if ($lEval eq '0') {
          $fv_value = '0';
          last;
        }
      } else {
        # an empty arg is FALSE (pre-Parse)
        $fv_value = '0';
        last;
      }
    }
  #-----------------------------------------------------------------------------
  #-- Check for the OR function - #OR[<val1>][<val2>]...[<valn>]#
  #-- Returns 1 if ANY of the expressions (vals) is true, 0 otherwise
  #-- NOTE: NULL arguments are TRUE expressions
  #--
  } elsif  ($Function eq 'OR') {
    # default response to 0
    $fv_value = '0';
    $li_index = 1;
    my $lEval = "";
    while (1) {
      #-- Get the next argument
      $lv_arg_1 = $self->GetArgNoParse($li_index, @FunArgs);
      #-- leave if there are no more arguments or the argument count exceeds 5000
      last if (!$self->IsArg($li_index, @FunArgs)
               || $li_index > 5000);
      #-- leave if the expression is TRUE - return 1
      $lEval = $self->Eval($lv_arg_1);
      if ($lEval eq '1') {
        $fv_value = '1';
        last;
      }
      #-- increment the index
      $li_index = $li_index + 1;
    }

  #-----------------------------------------------------------------------------
  #-- Check for the ROUND function - #ROUND[<number>][<decimals>]#
  #--
  } elsif  ($Function eq 'ROUND') {
    use Core::Math::Round;
    #-- Get the base text ($fv_value)
    $fv_value = $self->GetArgParse(1, @FunArgs);
    $ln_value = $U->GetNumber($fv_value,1);
    $lv_arg_1 = $self->GetArgParse(2, @FunArgs);
    $ln_arg_1 = $U->NVL($U->GetNumber($lv_arg_1,1), 0);
    $fv_value = $U->round($ln_value, $ln_arg_1);

  #-----------------------------------------------------------------------------
  #-- Check for the EXISTS or ISNOTNULL or NOTNULL function - #EXISTS[<text>][then][else]#
  #-- Returns 1 if ANY of the expressions (vals) is true, 0 otherwise
  #--
  } elsif  ($Function eq 'EXISTS'
          ||$Function eq 'ISNOTNULL'
          ||$Function eq 'NOTNULL'
          ) {
    #-- Get the next argument
    $lv_arg_1 = $self->GetArgParse(1, @FunArgs);
    if ($self->IsArg(2, @FunArgs)) {
      if ($lv_arg_1 ne "") {
        #-- Expression was true, so value is the <then> part of the expression
        $fv_value = $self->GetArgParse(2, @FunArgs); #--then
      } else {
        #-- Expression was false, so value is the <else> part of the expression
        $fv_value = $self->GetArgParse(3, @FunArgs);
      }
    } else {  #-- use standard functionality
      if ($lv_arg_1 ne "") {
        $fv_value = '1';
      } else {
        $fv_value = '0';
      }
    }

  #-----------------------------------------------------------------------------
  #-- Check for the FORMAT function - 2 Formats
  #-- - #FORMAT[<date>][<in_format>][<out_format>]#
  #-- - #FORMAT[<number>][<format>]#  ,.00
  #--
  } elsif  ($Function eq 'FORMAT') {
    #-- Get the base text ($lv_arg_1)
    $lv_arg_1 = $self->GetArgParse(1, @FunArgs);
    $lv_arg_2 = $self->GetArgParse(2, @FunArgs);
    if ($self->IsArg(2, @FunArgs)) {
      #-- have a second parameter - check for the 3rd
      $lv_arg_3 = $self->GetArgParse(3, @FunArgs);
      if ($lv_arg_3 ne '') {
        #-- Date format
        $fv_value = $U->DateToChar($lv_arg_1, $lv_arg_2, $lv_arg_3);
      } else {
        #-- number format
        $fv_value = $U->NumberToChar($lv_arg_1, $lv_arg_2);
      }
    } else {
      #-- default to number format if no format specified
      $fv_value = $U->NumberToChar($lv_arg_1);
    }

  #-----------------------------------------------------------------------------
  #-- Check for the EQUAL function - #EQUAL[val1][val2][then][else]#
  #--
  } elsif  ($Function eq 'EQUAL') {
    #-- Get the base text ($fv_value)
    $fv_value = $self->GetArgParse(1, @FunArgs);
    $lv_arg_1 = $self->GetArgParse(2, @FunArgs); #--val2
    if ($self->IsArg(2, @FunArgs)) {
      if ($self->IsArg(3, @FunArgs)) { #--then
        #-- See if the <val1> equals <val2>
        if ($fv_value eq $lv_arg_1
           || ($fv_value eq "" && $lv_arg_1 eq "")) {
          #-- Expression was true, so value is the <then> part of the expression
          $fv_value = $self->GetArgParse(3, @FunArgs); #--then
        } else {
          #-- Expression was false, so value is the <else> part of the expression
          $fv_value = $self->GetArgParse(4, @FunArgs);
        }
      } else {   #-- no) {/else specified - use standard functionality
        if ($fv_value eq $lv_arg_1
           || ($fv_value eq "" && $lv_arg_1 eq "")) {
          $fv_value = '1';
        } else {
          $fv_value = '0';
        }
      }
    } else {
      $fv_value = $self->GetFunctionError($Function);
    }
  #-----------------------------------------------------------------------------
  #-- Check for the NOTEQUAL function - #NOTEQUAL[val1][val2][then][else]#
  #--
  } elsif  ($Function eq 'NOTEQUAL') {
    #-- Get the base text ($fv_value)
    $fv_value = $self->GetArgParse(1, @FunArgs);
    $lv_arg_1 = $self->GetArgParse(2, @FunArgs); #--val2
    if ($self->IsArg(2, @FunArgs)) {
      if ($self->IsArg(3, @FunArgs)) {   #--then
        #-- See if the <val1> NOT equals <val2>
        if ($fv_value eq $lv_arg_1
           || ($fv_value eq "" && $lv_arg_1 eq "")) {
          #-- Expression was true, so value is the <else> part of the expression
          $fv_value = $self->GetArgParse(4, @FunArgs);
        } else {
          #-- Expression was false, so value is the <then> part of the expression
          $fv_value = $self->GetArgParse(3, @FunArgs); #--then
        }
      } else {   #-- no) {/else specified - use standard functionality
        if ($fv_value eq $lv_arg_1
           || ($fv_value eq "" && $lv_arg_1 eq "")) {
          $fv_value = '0';
        } else {
          $fv_value = '1';
        }
      }
    } else {
      $fv_value = $self->GetFunctionError($Function);
    }
  #-----------------------------------------------------------------------------
  #-- Check for the SELECTED function -
  #-- #SELECTED[<select/option_text>][<option_value>][<option_text>][<select_class>][<no_add_flag>]#
  #--
  #-- this function only works if the option value is enclosed in "" within the list
  #-- Used specifically for <SELECT> lists in HTML, this function marks an option as selected as
  #-- identified by the <option_value>. This will return the <select/option_list> text with
  #-- any ""<option_value>"" replaced with ""<option_value>"" SELECTED. This allows you to define
  #-- an entire drop down list once, and use it on a multiple record update page without requerying
  #-- the list from the database. <option_text> is optional.  If specified and the <option_value>
  #-- was not found in the list, this option will be inserted as the first option in the list.
  #-- <select_class> is optional.  If specified, this text will be used in the <SELECT> tag - useful
  #-- for setting the style class
  #-- If <no_add_flag> is 1,) { the option will not be added if it does not exist.
  #--
  } elsif  ($Function eq 'SELECTED') {
    #-- Get the option list ($fv_value)
    $fv_value = $self->GetArgParse(1, @FunArgs);   # select/option text
    #-- get the find text - don't raise an error if not found
    $lv_arg_1 = $self->GetArgParse(2, @FunArgs);   # option value

    if ($self->IsArg(2, @FunArgs)) {
      #-- strip off any pre existing " and add them on either side
      #$lv_arg_1 = '"'.$U->trim($lv_arg_1, '"').'"';
      $lv_arg_1 =~ s/"//g;
      $lv_arg_1 = '"'.$lv_arg_1.'"';

      my $ln_pos = index($fv_value, $lv_arg_1);
      #-- Try to get the option without the quotes if not found - look for '=<value> '
      if ($ln_pos == -1) {
        $lv_arg_1 =~ s/"//g;
        $ln_pos = index($fv_value, '='.$lv_arg_1.' ');
        if ($ln_pos >= 0) {
          #-- reset the search value for replacement below
          $lv_arg_1 = '='.$lv_arg_1.' ';
        } else {
          $lv_arg_1 = '"'.$lv_arg_1.'"';
        }
      }
      if ($ln_pos >= 0) {
        #-- option found, so replace with SELECTED
        $fv_value = $U->Replace($fv_value, $lv_arg_1, $lv_arg_1.' SELECTED');
      } else {
        #-- Try to get the option without the quotes if not found - look for '=<value>>'
        if ($ln_pos == -1) {
          $lv_arg_1 =~ s/"//g;   # Remove "
          $ln_pos = index($fv_value, '='.$lv_arg_1.'>');
          if ($ln_pos >= 0) {
            #-- reset the search value for replacement below
            $lv_arg_1 = '='.$lv_arg_1.'>';
            #-- option found, so replace with SELECTED
            $fv_value = $U->Replace($fv_value, $lv_arg_1, substr($lv_arg_1, 0, length($lv_arg_1)-1).' SELECTED>');
          }
        }
        #--
        #-- INSERT NEW OPTION AT TOP OF LIST
        #--  - Only if the no_add_flag is not set
        #--
        $lv_arg_4 = $self->GetArgParse(5, @FunArgs);   # no_add_flag
        if ( $lv_arg_4 ne '1'
            && $ln_pos == -1) {
          #-- First, look for first <option> tag in list
          $ln_pos = index($U->lower($fv_value), '<option');
          #-- If no options, insert before </select> tag
          if ($ln_pos == -1) {
            $ln_pos = index($U->lower($fv_value), '</select');
            #-- If no </select>, add to END of text in case <select> is present
            if ($ln_pos == -1) {
              $ln_pos = length($fv_value);
            }
          }
          #-- check if the option text was specified
          $lv_arg_2 = $self->GetArgParse(3, @FunArgs);   # option text
          #-- if option value was specified but option text was not, default to 'Not Found (Inactive)'
          if ( $lv_arg_1 ne '""'
            && $lv_arg_2 eq ""
            ) {
            #$lv_arg_2 = 'Not Found';
          }
          #-- build the new list with the option inserted
          $fv_value =   substr($fv_value, 0, $ln_pos)
                      .'<option value="'.$lv_arg_1.'" selected>'.$lv_arg_2.'</option>'."\n"
                      .substr($fv_value, $ln_pos);
        }
      }
      #-- Get the select class clause
      $lv_arg_4 = $self->GetArgParse(4, @FunArgs);
      if ($self->IsArg(4, @FunArgs) && $lv_arg_4 ne "") {
        #-- Add the select class to the <SELECT> tag
        $ln_pos = index($U->upper($fv_value), '<SELECT');
        if ($ln_pos >= 0) {
          #-- <SELECT found, so replace with "<SELECT $lv_arg_4 "
          #-- build the new list with the option inserted
          $fv_value =   substr($fv_value, 0, $ln_pos+7)
                      .' '.$lv_arg_4.' '
                      .substr($fv_value, $ln_pos+8);
        }
      }
    }
  #-----------------------------------------------------------------------------
  #-- Check for the OPTIONS function - #OPTIONS[list].[separator].[option_line]#
  #-- - Return an <option> list from the separated input list, for use in HTML SELECT.
  #-- - Separators can be specified or auto-default: pipe(|), comma(,), semi-colon(;) if found in list.
  #-- - Second separator provides "value|display" pair. 1|apple,2|pear,3|orange,7|kevin;
  #-- - [option_line] specifies a custom option specification, or any other content,
  #--   referencing #_OPTION_VALUE_# and #_OPTION_DISPLAY_#
  #--
  } elsif ($Function eq 'OPTIONS') {
    use Core::Search;
    $fv_value = $self->GetArgParse(1, @FunArgs);
    $fv_value =~ s/\n//g;
    $lv_arg_2 = $self->GetArgParse(2, @FunArgs);
    $lv_arg_2 = ',' if ($lv_arg_2 eq "");

    # Get the best delimiter from the data
    $lv_arg_2 = $U->GetDelimiters($fv_value, $lv_arg_2);

    if ($fv_value ne "" && $lv_arg_2 ne "") {
      my $delim1 = substr($lv_arg_2, 0, 1);   # Get the first delimiter
      my $delim2 = substr($lv_arg_2, 1, 1) if (length($lv_arg_2) >= 2);
      $delim2 = "" if (!defined($delim2));

      # Special fix for | - when searching in RegEx - must escape with backslash \
      $delim1 = '\|' if ($delim1 eq "|");
      $delim2 = '\|' if ($delim2 eq "|");

      # Use primary delimiter first
      my @OPTIONS = split($delim1, $fv_value);

      $lv_arg_3 = $self->GetArgNoParse(3, @FunArgs);

      # initialize output
      $fv_value="";

      my $value="";
      my $display="";
      # search through each Arg and if any is false, return 0
      for ($li_index=0; $li_index < @OPTIONS; $li_index++) {
        # Get the next item or name/value pair
        $value   = $U->trim($OPTIONS[$li_index]);
        $display = "";

        # Assign name/value pair
        ($value, $display) = split($delim2, $value) if ($delim2 ne "" && $value ne "");
        $display = $value if (!defined($display) || $display eq "");

        # Check for user specified option line - use orbit parse
        if ($lv_arg_3 eq "") {
          # Standard quick line
          $fv_value .= "<option value=\"".$value."\">".$display."</option>";
        } else {
          $self->Set_Token('_OPTION_VALUE_', $value);
          $self->Set_Token('_OPTION_DISPLAY_', $display);
          $fv_value .= $self->Parse($lv_arg_3, $bFlush);
        }
      }
      undef @OPTIONS;
    }

  #-----------------------------------------------------------------------------
  #-- Check for the ROWS function - #ROWS[<text>][<max_linesize>][<min_rows>][<max_rows>]#
  #--
  } elsif  ($Function eq 'ROWS') {
    use Orbit::Utils::Wrap;
    use Core::Math::Least;
    #-- Get the first argument
    $lv_arg_1 = $self->GetArgParse(1, @FunArgs);
    #-- Get the next argument - max linesize
    $lv_arg_2 = $self->GetArgParse(2, @FunArgs);
    # Call Count Rows to get the count
    $ln_value = $self->Count_Rows($lv_arg_1, $U->GetNumber($lv_arg_2,1));
    $lv_arg_3 = $self->GetArgParse(3, @FunArgs);
    #-- Get the greatest value of min_rows or the number of rows returned above
    if ($self->IsArg(3, @FunArgs)) {
      $ln_arg_1 = $U->NVL($U->GetNumber($lv_arg_3,1),0);
      $ln_value = $U->greatest($ln_value, $ln_arg_1);
    }
    $lv_arg_3 = $self->GetArgParse(4, @FunArgs);
    #-- Get the least value of max_rows or the number of rows returned above
    if ($lv_arg_3 ne '') {
      $ln_arg_1 = $U->NVL($U->GetNumber($lv_arg_3,1),0);
      $ln_value = $U->least($ln_value, $ln_arg_1);
    }
    $fv_value = $U->to_char($ln_value);
  #-----------------------------------------------------------------------------
  #-- Check for the REPEAT function - #REPEAT[<times>][<text>]#
  #-- Repeatedly displays the <text> <times> number of times.
  } elsif  ($Function eq 'REPEAT') {
    #-- Get the number of times to repeat
    $lv_arg_1 = $self->GetArgParse(1, @FunArgs);
    #-- Get the text to repeat - don't parse it since it may contain context sensitive functions
    $lv_arg_2 = $self->GetArgNoParse(2, @FunArgs);  #-- Text
    if ($self->IsArg(2, @FunArgs)) {
      #-- Convert the number of times to a number
      $ln_value = $U->NVL($U->GetNumber($lv_arg_1,1),0);
      if ($ln_value > 0) {
        for (my $i=0; $i<$ln_value; $i++) {
          # Parse the second argument and a ppend this "repeat" result to the acculumating fv_value
          $fv_value .= $self->Parse($lv_arg_2, $bFlush);
        }
      }
    } else {
      $fv_value = $self->GetFunctionError($Function);
    }
  #-----------------------------------------------------------------------------
  #-- Check for the WHILE function - #WHILE[<expression>][<text>][<maxtimes>]#
  #-- Repeatedly displays the <text> while <expression> is TRUE, but not more
  #-- than <maxtimes> number of times.
  } elsif  ($Function eq 'WHILE') {
    #-- Get the expression argument
    $lv_arg_1 = $self->GetArgNoParse(1, @FunArgs);  #-- Expression
    if ($lv_arg_1 ne '') {
      #-- Get the text to repeat - don't parse it since it may contain context sensitive functions
      $lv_arg_2 = $self->GetArgNoParse(2, @FunArgs);  #-- Text
      if ($lv_arg_2 ne '') {
        #-- copy text so we don't need to keep extracting it
        $lv_arg_4 = $lv_arg_2;
        #-- Get the number of times to repeat
        $lv_arg_3 = $self->GetArgParse(3, @FunArgs);
        if ($lv_arg_3 ne '') {
          #-- Convert the number of times to a number
          $ln_arg_3 = $U->NVL($U->GetNumber($lv_arg_3,1),0);
        } else {
          $ln_arg_3 = 5000;  #-- Default <maxtimes>
        }
        #-- continue looping until expression is false, or maxtimes is reached
        $li_index = 1;
        while (1) {
          last if (!$self->Eval($lv_arg_1)
                 || $li_index > $ln_arg_3);
          #-- parse $lv_arg_2 in place
          $lv_arg_2 = $self->Parse($lv_arg_2, $bFlush);
          #-- append it to $fv_value) { reset it to unparsed string
          $fv_value = $fv_value.$lv_arg_2;
          $lv_arg_2 = $lv_arg_4;
          #-- increment loop index
          $li_index = $li_index + 1;
        }
      }
    }
  #-----------------------------------------------------------------------------
  #-- Check for the REPLACE function - #REPLACE[<text>][<find>][<replace>]#
  #-- Replaces first occurance ONLY
  } elsif  ($Function eq 'REPLACE') {
    #-- Get the base text ($fv_value)
    $fv_value = $self->GetArgParse(1, @FunArgs);
    $lv_arg_1 = $self->GetArgParse(2, @FunArgs);  #-- Find Text
    if ($self->IsArg(2, @FunArgs)) {
      $lv_arg_2 = $self->GetArgParse(3, @FunArgs);  #-- Replace Text
      $fv_value = $U->Replace($fv_value, $lv_arg_1, $lv_arg_2);
    } else {
      $fv_value = $self->GetFunctionError($Function);
    }
  #-----------------------------------------------------------------------------
  #-- Check for the REPLACEALL function - #REPLACEALL[<text>][<find>][<replace>]#
  #--
  } elsif  ($Function eq 'REPLACEALL') {
    #-- Get the base text ($fv_value)
    $fv_value = $self->GetArgParse(1, @FunArgs);
    $lv_arg_1 = $self->GetArgParse(2, @FunArgs);  #-- Find Text
    if ($self->IsArg(2, @FunArgs)) {
      $lv_arg_2 = $self->GetArgParse(3, @FunArgs);  #-- Replace Text
      $fv_value = $U->ReplaceAll($fv_value, $lv_arg_1, $lv_arg_2);
    } else {
      $fv_value = $self->GetFunctionError($Function);
    }
  #-----------------------------------------------------------------------------
  #-- Check for the IREPLACE function - #IREPLACE[<text>][<find>][<replace>]#
  #-- Perform a case Insensitive Replace
  } elsif  ($Function eq 'IREPLACE') {
    #-- Get the base text ($fv_value)
    $fv_value = $self->GetArgParse(1, @FunArgs);
    $lv_arg_1 = $self->GetArgParse(2, @FunArgs);  #-- Find Text
    if ($lv_arg_1 ne '') {
      $lv_arg_2 = $self->GetArgParse(3, @FunArgs);  #-- Replace Text
      $fv_value = $U->iReplace($fv_value, $lv_arg_1, $lv_arg_2);
    } else {
      $fv_value = $self->GetFunctionError($Function);
    }
  #-----------------------------------------------------------------------------
  #-- Check for the IREPLACEALL function - #IREPLACEALL[<text>][<find>][<replace>]#
  #-- Perform a case Insensitive Replace
  } elsif  ($Function eq 'IREPLACEALL') {
    #-- Get the base text ($fv_value)
    $fv_value = $self->GetArgParse(1, @FunArgs);
    $lv_arg_1 = $self->GetArgParse(2, @FunArgs);  #-- Find Text
    if ($lv_arg_1 ne '') {
      $lv_arg_2 = $self->GetArgParse(3, @FunArgs);  #-- Replace Text
      $fv_value = $U->iReplaceAll($fv_value, $lv_arg_1, $lv_arg_2);
    } else {
      $fv_value = $self->GetFunctionError($Function);
    }

  #-----------------------------------------------------------------------------
  #-- Check for the SYSDATE function - #SYSDATE[<format>]#
  #-- Check for the GMTSYSDATE function - #GMTSYSDATE[<format>]#
  #--
  } elsif  ($Function eq 'SYSDATE'
          ||$Function eq 'GMTSYSDATE') {
    use Core::Timestamp;
    #-- Get the base text ($fv_value)
    $lv_arg_1 = $self->GetArgParse(1, @FunArgs);
    if ($Function eq 'GMTSYSDATE') {
      if ($lv_arg_1 ne "") {
        $fv_value = $U->to_char($U->gmt_sysdate(), $lv_arg_1);
      } else {
        $fv_value = $U->to_char($U->gmt_sysdate());
      }
    } else {
      if ($lv_arg_1 ne "") {
        $fv_value = $U->to_char($U->sysdate(), $lv_arg_1);
      } else {
        $fv_value = $U->to_char($U->sysdate());
      }
    }
  #-----------------------------------------------------------------------------
  #-- Check for the DATE function - #DATE[format][timezone][bGMT(0/1)]#
  #-- - Returns the current DATE ONLY with decorations based on timezone,
  #-- - in GMT (1) or server time (0)
  #-- - Date format masks: YYYY.YY.MM DD Y1/M1/D1 MON MONTH DAY DY (mixed case applies)
  } elsif  ($Function eq 'DATE') {
    use Core::Dates;
    $lv_arg_1 = $self->GetArgParse(1, @FunArgs);
    $lv_arg_2 = $self->GetArgParse(2, @FunArgs);
    $lv_arg_3 = $self->GetArgParse(3, @FunArgs);
    $fv_value = $U->Get_Date($lv_arg_1, $lv_arg_2, $lv_arg_3);
  #-----------------------------------------------------------------------------
  #-- Check for the TIME function - #TIME[format][timezone][bGMT(0/1)]#
  #-- - Returns the current DATE ONLY with decorations based on timezone,
  #-- - in GMT (1) or server time (0)
  #-- - Time format masks: HH24 H24 HH:MI:SS H1:MIN:SEC S1 AM PM HOUR Hour (mixed case applies)
  #--
  } elsif  ($Function eq 'TIME') {
    use Core::Dates;
    $lv_arg_1 = $self->GetArgParse(1, @FunArgs);
    $lv_arg_2 = $self->GetArgParse(2, @FunArgs);
    $lv_arg_3 = $self->GetArgParse(3, @FunArgs);
    $fv_value = $U->Get_Time($lv_arg_1, $lv_arg_2, $lv_arg_3);
  #-----------------------------------------------------------------------------
  #-- Check for the TIMESTAMP function - #TIMESTAMP[DateTimeSep]#
  #-- Returns the full date and time with no decorations, optional DateTimeSep (like _.)
  #--
  } elsif  ($Function eq 'TIMESTAMP') {
    use Core::Timestamp;
    $lv_arg_1 = $self->GetArgParse(1, @FunArgs);
    $fv_value = $U->Timestamp($lv_arg_1);
  #-----------------------------------------------------------------------------
  #-- Check for the TRANSACTIONID function - #TRANSACTIONID[]#
  #--
  } elsif  ($Function eq 'TRANSACTIONID') {
    #-- Return the next Transaction ID
    $fv_value = $self->TransactionID();

  #-----------------------------------------------------------------------------
  #-- Check for the DISTANCE function - #DISTANCE[<lat,long>][<lat,long>][km]#
  #--
  } elsif  ($Function eq 'DISTANCE') {
    use Core::Distance;
    use Core::Math::Round;
    #-- Get the coordinates
    $lv_arg_1 = $self->GetArgParse(1, @FunArgs);
    $lv_arg_2 = $self->GetArgParse(2, @FunArgs);
    $lv_arg_3 = $self->GetArgParse(3, @FunArgs);
    # Get the distance
    $fv_value = $U->round($U->Get_Distance($lv_arg_1, $lv_arg_2, $lv_arg_3),2);
  #-----------------------------------------------------------------------------
  #-- Check for the BEARING function - #BEARING[<lat,long>][<lat,long>][directional]#
  #-- - returns the bearing (direction)
  } elsif  ($Function eq 'BEARING') {
    use Core::Distance;
    use Core::Math::Round;
    #-- Get the coordinates
    $lv_arg_1 = $self->GetArgParse(1, @FunArgs);
    $lv_arg_2 = $self->GetArgParse(2, @FunArgs);
    $lv_arg_3 = $self->GetArgParse(3, @FunArgs);
    # Get the Bearing
    if ($lv_arg_3 ne '1') {
      $fv_value = $U->round($U->Get_Bearing($lv_arg_1, $lv_arg_2),2);
    } else {
      $fv_value = $U->Get_Bearing($lv_arg_1, $lv_arg_2, $lv_arg_3);
    }

  #-----------------------------------------------------------------------------
  #-- Check for the FIBONACCI function - #FIBONACCI[start_iteration][end_iteration][delim]#
  #-- - Returns the Fibonacci sequence starting and ending at specified iterations, delimited by delim (def ,)
  } elsif  ($Function eq 'FIBONACCI') {
    use Core::Fibonacci;
    #-- Get the coordinates
    $lv_arg_1 = $self->GetArgParse(1, @FunArgs);
    $lv_arg_2 = $self->GetArgParse(2, @FunArgs);
    $lv_arg_3 = $self->GetArgParse(3, @FunArgs);
    # Check for valid args - must be positive and start < end, or else default
    $lv_arg_1 = 1 if (!$self->IsNumber($lv_arg_1) || $lv_arg_1 < 0);
    $lv_arg_2 = 7 if (!$self->IsNumber($lv_arg_2) || $lv_arg_2 < $lv_arg_1);
    $lv_arg_3 = ',' if ($lv_arg_3 eq '');   # Default comma
    # Get the fibonacci sequence
    $fv_value = $U->Fibonacci( $lv_arg_1, $lv_arg_2, $lv_arg_3 );

    #
    # BREAKWAY TEST - OrbitFunctionOML -> OrbitOMLFunction v7
    #
    #my $fn = sub { $U->Fibonacci( $lv_arg_1, $lv_arg_2, $lv_arg_3 ),};
    ##local ($fn);
    #{ $fv_value = $fn->(), 0 }; # protect against wild "next"



  #-----------------------------------------------------------------------------
  #-- Check for the COMMALIST function - #COMMALIST[<val1>][<val2>]...[<valn>]#
  #-- Return a comma-separated list of all non-NULL arguments in the list
  #--
  } elsif  ($Function eq 'COMMALIST') {
    $li_index = 1;
    while (1) {
      #-- Get the next argument
      $lv_arg_1 = $self->GetArgParse($li_index, @FunArgs);
      #-- leave if there are no more arguments or the argument count exceeds 500
      last if   ( !$self->IsArg($li_index, @FunArgs)
                || $li_index > 500);
      if ($lv_arg_1 ne "") {
        $fv_value = $fv_value.','.$lv_arg_1;
      }
      #-- increment the index
      $li_index = $li_index + 1;
    }
    #-- strip out the initial pipe
    if ($fv_value ne "") {
      $fv_value = substr($fv_value, 1);
    }
  #-----------------------------------------------------------------------------
  #-- Check for the PIPELIST function - #PIPELIST[<val1>][<val2>]...[<valn>]#
  #-- Return a pipe (|) separated list of all non-NULL arguments in the list
  #--
  } elsif  ($Function eq 'PIPELIST') {
    $li_index = 1;
    while (1) {
      #-- Get the next argument
      $lv_arg_1 = $self->GetArgParse($li_index, @FunArgs);
      #-- leave if there are no more arguments or the argument count exceeds 500
      last if   ( !$self->IsArg($li_index, @FunArgs)
                || $li_index > 500);
      if ($lv_arg_1 ne "") {
        $fv_value = $fv_value.'|'.$lv_arg_1;
      }
      #-- increment the index
      $li_index = $li_index + 1;
    }
    #-- strip out the initial pipe
    if ($fv_value ne "") {
      $fv_value = substr($fv_value, 1);
    }
  #-----------------------------------------------------------------------------
  #-- Check for the LIKE function - #LIKE[<text>][<compare_pattern>][then][else]#
  #--
  } elsif  ($Function eq 'LIKE') {
    use Core::Like;
    #-- Get the base text ($fv_value)
    $fv_value = $self->GetArgParse(1, @FunArgs);
    $lv_arg_1 = $self->GetArgParse(2, @FunArgs); #--pattern
    if ($self->IsArg(2, @FunArgs)) {
      if ($self->IsArg(3, @FunArgs)) {
        #-- use) {/else clauses if we found the <then>
        if (  $U->like($fv_value, $lv_arg_1)
           || $U->like($lv_arg_1, $fv_value)
           ) {
          #-- Expression was true, so value is the <then> part of the expression
          $fv_value = $self->GetArgParse(3, @FunArgs); #--then
        } else {
          #-- Expression was false, so value is the <else> part of the expression
          $fv_value = $self->GetArgParse(4, @FunArgs);
        }
      } else {   #-- no else - use standard functionality
        if (  $U->like($fv_value, $lv_arg_1)
           || $U->like($lv_arg_1, $fv_value)
           ) {
          $fv_value = '1';
        } else {
          $fv_value = '0';
        }
      }
    } else {
      $fv_value = $self->GetFunctionError($Function);
    }
  #-----------------------------------------------------------------------------
  #-- Check for the ILIKE function - #ILIKE[<text>][<compare_pattern>][then][else]#
  #--
  } elsif  ($Function eq 'ILIKE') {
    use Core::Like;
    #-- Get the base text ($fv_value)
    $fv_value = $self->GetArgParse(1, @FunArgs);
    $lv_arg_1 = $self->GetArgParse(2, @FunArgs); #--pattern
    if ($self->IsArg(2, @FunArgs)) {
      if ($self->IsArg(3, @FunArgs)) {
        #-- use) {/else clauses if we found the <then>
        if (  $U->ilike($fv_value, $lv_arg_1)
           || $U->ilike($lv_arg_1, $fv_value)
           ) {
          #-- Expression was true, so value is the <then> part of the expression
          $fv_value = $self->GetArgParse(3, @FunArgs); #--then
        } else {
          #-- Expression was false, so value is the <else> part of the expression
          $fv_value = $self->GetArgParse(4, @FunArgs);
        }
      } else {   #-- no else - use standard functionality
        if (  $U->ilike($fv_value, $lv_arg_1)
           || $U->ilike($lv_arg_1, $fv_value)
           ) {
          $fv_value = '1';
        } else {
          $fv_value = '0';
        }
      }
    } else {
      $fv_value = $self->GetFunctionError($Function);
    }
  #-----------------------------------------------------------------------------
  #-- Check for the HELP function - #HELP[<text>][<popup_text>][<required_flag>]#
  #--
  } elsif  ($Function eq 'HELP') {
    $fv_value = $self->GetArgParse(1, @FunArgs);  #-- base text
    $lv_arg_1 = $self->GetArgParse(2, @FunArgs);  #-- Popup Text
    if ($fv_value ne ""
       && $lv_arg_1 ne "") {
      $lv_arg_2 = $self->GetArgParse(3, @FunArgs);  #-- required_flag
      if ($U->NVL($lv_arg_2,'0') eq '1') {
        $lv_arg_2 = '_req';
      } else {
        $lv_arg_2 = '';
      }
      #-- KR 1/2/04 - added tabindex=-1 so image will not be part of tab sequence
      $fv_value = '<a href="javascript:void(0);" tabindex="-1" class="help_popup'.$lv_arg_2.'"'
                .' onMouseOver="window.status=\''.$U->Replace($U->Replace($U->Replace($U->Replace($lv_arg_1,"\n",' '),'&#013;',' '),'"','&quot;'),'\'','\'').'\'; return true;"'
                .' onMouseOut="window.status=\'\'; return true;"'
                .' title="'.$U->Replace($lv_arg_1,'"','&quot;').'">'.$fv_value.'</a>';
    }
  #-----------------------------------------------------------------------------
  #-- Check for the HELPOVER function - #HELPOVER[<popup_text>]#
  #--
  } elsif  ($Function eq 'HELPOVER') {
    $lv_arg_1 = $self->GetArgParse(1, @FunArgs);  #-- Popup Text
    if ($lv_arg_1 ne "") {
      $fv_value = ' onMouseOver="window.status=\''.$U->Replace($U->Replace($U->Replace($U->Replace($lv_arg_1,"\n",' '),'&#013;',' '),'"','&quot;'),'\'','\'').'\'; return true;"'
                .' onMouseOut="window.status=\'\'; return true;"'
                .' title="'.$U->Replace($lv_arg_1,'"','&quot;').'" ';
    }
  #-----------------------------------------------------------------------------
  #-- Check for the JSQUOTE function - #JSQUOTE[<message_text>]#
  #--
  } elsif  ($Function eq 'JSQUOTE') {
    $fv_value = $self->GetArgParse(1, @FunArgs);  #-- Message Text
    if ($fv_value ne "") {
      $fv_value =~ s/'/\\'/g;
      $fv_value =~ s/"/\\"/g;
      $fv_value =~ s/\n/\\r/g;
    }

  #-----------------------------------------------------------------------------
  #-- Check for the TRANSLATE function - #TRANSLATE[<text>][<from>][<to>]#
  #--
  } elsif  ($Function eq 'TRANSLATE') {
    #-- Get the base text ($fv_value)
    $fv_value = $self->GetArgParse(1, @FunArgs);
    $lv_arg_1 = $self->GetArgParse(2, @FunArgs); #-- from
    if ($self->IsArg(3, @FunArgs)) {
      $lv_arg_2 = $self->GetArgParse(3, @FunArgs); #-- to
      $fv_value = $U->translate($fv_value, $lv_arg_1, $lv_arg_2);
    } else {
      $fv_value = $self->GetFunctionError($Function);
    }
  #-----------------------------------------------------------------------------
  #-- Check for the SUBSTR function - #SUBSTR[<text>][<begin>].[<length>]#
  #-- - 1-based substr (Oracle)
  #-- - Gets a substring from [text] beginning at [start] and getting [length] chars.  1-based substr (Oracle) - returns 0 if not found
  } elsif  ($Function eq 'SUBSTR') {
    #-- Get the base text ($fv_value)
    $fv_value = $self->GetArgParse(1, @FunArgs);
    $lv_arg_1 = $self->GetArgParse(2, @FunArgs);  #-- begin
    if ($self->IsArg(2, @FunArgs)) {
      $ln_arg_1 = $U->NVL($U->GetNumber($lv_arg_1,1), 1);
      $ln_arg_1--;
      # Check for 3rd argument to make the correct call
      if ($self->IsArg(3, @FunArgs)) {
        $lv_arg_2 = $self->GetArgParse(3, @FunArgs);
        $ln_arg_2 = $U->GetNumber($lv_arg_2,1);
        $fv_value = substr($fv_value, $ln_arg_1, $ln_arg_2);
      } else {
        $fv_value = substr($fv_value, $ln_arg_1);
      }
    } else {
      $fv_value = $self->GetFunctionError($Function);
    }
  #-----------------------------------------------------------------------------
  #-- Check for the SUBSTR0 function - #SUBSTR0[<text>][<begin>].[<length>]#
  #-- - 0-based substr (Perl)
  #-- - Same as SUBSTR, but 0-based (Perl) - returns -1 if not found, 0 for beginning of string
  } elsif  ($Function eq 'SUBSTR0') {
    #-- Get the base text ($fv_value)
    $fv_value = $self->GetArgParse(1, @FunArgs);
    $lv_arg_1 = $self->GetArgParse(2, @FunArgs);  #-- begin
    if ($self->IsArg(2, @FunArgs)) {
      $ln_arg_1 = $U->NVL($U->GetNumber($lv_arg_1,1), 1);
      # Check for 3rd argument to make the correct call
      if ($self->IsArg(3, @FunArgs)) {
        $lv_arg_2 = $self->GetArgParse(3, @FunArgs);
        $ln_arg_2 = $U->GetNumber($lv_arg_2,1);
        $fv_value = substr($fv_value, $ln_arg_1, $ln_arg_2);
      } else {
        $fv_value = substr($fv_value, $ln_arg_1);
      }
    } else {
      $fv_value = $self->GetFunctionError($Function);
    }
  #-----------------------------------------------------------------------------
  #-- Check for the INSTR function - #INSTR[<text>][<find>][<begin>][<occurrence>]# - NOT SUPPORTED with occurrence
  #-- Check for the INSTR function - #INSTR[<text>][<find>][<begin>]#
  #-- 1-based offset, returns 0 if string not found, similar to Oracle "instr"
  #--
  } elsif  ($Function eq 'INSTR') {
    #-- Get the base text ($fv_value)
    $fv_value = $self->GetArgParse(1, @FunArgs);
    $lv_arg_1 = $self->GetArgParse(2, @FunArgs); #-- find
    if ($self->IsArg(2, @FunArgs)) {
      $lv_arg_2 = $self->GetArgParse(3, @FunArgs); #-- begin
      $ln_arg_2 = $U->NVL($U->GetNumber($lv_arg_2,1), 1);
      $ln_arg_2--;
      $fv_value = index($fv_value, $lv_arg_1, $ln_arg_2);
      # Increase the offset for INSTR conversion
      $fv_value++;
    } else {
      $fv_value = $self->GetFunctionError($Function);
    }
  #-----------------------------------------------------------------------------
  #-- Check for the INDEX function - #INDEX[<text>][<find>][<begin>]#
  #-- 0-based offset, returns -1 if string not found, similar to Perl "index"
  #--
  } elsif  ($Function eq 'INDEX') {
    #-- Get the base text ($fv_value)
    $fv_value = $self->GetArgParse(1, @FunArgs);
    $lv_arg_1 = $self->GetArgParse(2, @FunArgs); #-- find
    if ($self->IsArg(2, @FunArgs)) {
      $lv_arg_2 = $self->GetArgParse(3, @FunArgs); #-- begin
      $ln_arg_2 = $U->NVL($U->GetNumber($lv_arg_2,1), 1);
      $fv_value = index($fv_value, $lv_arg_1, $ln_arg_2);
    } else {
      $fv_value = $self->GetFunctionError($Function);
    }
  #-----------------------------------------------------------------------------
  #-- Check for the CACHE function #CACHE[<tname>][<tname2>][<tname3>]...[<tnamen>]#
  #-- Set the token cache flag to 1 for specified token names tname1, 2, 3... n
  #-- (MJ 12/02/2002)
  #--
  } elsif  ($Function eq 'CACHE') {
    my $ln_raw_flag    = 0;
    my $ln_cache_flag  = 0;
    $li_index = 1;
    while (1) {
      #-- Get the next argument
      $lv_arg_1 = $self->GetArgParse($li_index, @FunArgs);
      #-- leave if there are no more arguments or the argument count exceeds 5000
      last if    (!$self->IsArg($li_index, @FunArgs)
                || $li_index > 5000);
      #-- Get all of the token record fields
      ($fv_value, $ln_raw_flag, $ln_cache_flag) = $self->Get_Token_Rec($lv_arg_1);
      #-- Set the cache flag to 1 (if it isn't 1 already)
      if ($ln_cache_flag != 1) {
        $self->Set_Token($lv_arg_1, $fv_value, $ln_raw_flag, 1);
      }
      #-- increment the index
      $li_index = $li_index + 1;
    }
    #-- this token function is merely a orbit-engine directive; always returns NULL
    $fv_value = '';
  #-----------------------------------------------------------------------------
  #-- Check for the UNCACHE function #UNCACHE[<tname>][<tname2>][<tname3>]...[<tnamen>]#
  #-- Set the token cache flag to 0 for specified token names tname1, 2, 3... n
  #-- (MJ 12/04/2002)
  #--
  } elsif  ($Function eq 'UNCACHE') {
    my $ln_raw_flag    = 0;
    my $ln_cache_flag  = 0;
    $li_index = 1;
    while (1) {
      #-- Get the next argument
      $lv_arg_1 = $self->GetArgParse($li_index, @FunArgs);
      #-- leave if there are no more arguments or the argument count exceeds 5000
      last if    (!$self->IsArg($li_index, @FunArgs)
                || $li_index > 5000);
      #-- Get all of the token record fields
      ($fv_value, $ln_raw_flag, $ln_cache_flag) = $self->Get_Token_Rec($lv_arg_1);
      #-- Set the cache flag to 0 (if it isn't 0 already)
      if ($ln_cache_flag != 0) {
        $self->Set_Token($lv_arg_1, $fv_value, $ln_raw_flag, 0);
      }
      #-- increment the index
      $li_index = $li_index + 1;
    }
    #-- this token function is merely a orbit-engine directive; always returns NULL
    $fv_value = '';
  #-----------------------------------------------------------------------------
  #-- Check for the GREATERTHAN / GT function - #GREATERTHAN[val1][val2][then][else]#
  #--
  } elsif  ($Function eq 'GT'
          ||$Function eq 'GREATERTHAN'
          ) {
    #-- Get the base text ($fv_value)
    $fv_value = $self->GetArgParse(1, @FunArgs);
    $lv_arg_1 = $self->GetArgParse(2, @FunArgs); #--val2
    if ($self->IsArg(2, @FunArgs)) {
      #-- get the <then> condition
      #-- See if val1 and val2 are numeric
      $ln_value = $U->GetNumber($fv_value,1);
      $ln_arg_1 = $U->GetNumber($lv_arg_1,1);
      if ($ln_value ne "" && $ln_arg_1 ne "") {
        #-- Do a numeric based comparison
        #-- see if the <then> was specified
        if ($self->IsArg(3, @FunArgs)) {   #--then
          #-- See if the <val1> is greater than <val2>
          if ($ln_value > $ln_arg_1) {
            #-- Expression was true, so value is the <then> part of the expression
            $fv_value = $self->GetArgParse(3, @FunArgs); #--then
          } else {
            #-- Expression was false, so value is the <else> part of the expression
            $fv_value = $self->GetArgParse(4, @FunArgs);
          }
        } else {   #-- no) {/else - use standard functionality
          #-- Do a numeric based comparison
          if ($ln_value > $ln_arg_1) {
            $fv_value = '1';
          } else {
            $fv_value = '0';
          }
        }
      } else {
        #-- Do a text based comparison
        #-- see if the <then> was specified
        if ($self->IsArg(3, @FunArgs)) {
          #-- See if the <val1> is greater than <val2>
          if ($fv_value > $lv_arg_1) {
            #-- Expression was true, so value is the <then> part of the expression
            $fv_value = $self->GetArgParse(3, @FunArgs); #--then
          } else {
            #-- Expression was false, so value is the <else> part of the expression
            $fv_value = $self->GetArgParse(4, @FunArgs);
          }
        } else {   #-- no) {/else - use standard functionality
          #-- Do a text based comparison
          if ($fv_value > $lv_arg_1) {
            $fv_value = '1';
          } else {
            $fv_value = '0';
          }
        }
      }
    } else {
      $fv_value = $self->GetFunctionError($Function);
    }
  #-----------------------------------------------------------------------------
  #-- Check for the LESSTHAN / LT function - #LESSTHAN[val1][val2][then][else]#
  #--
  } elsif  ($Function eq 'LT'
          ||$Function eq 'LESSTHAN'
          ) {
    #-- Get the base text ($fv_value)
    $fv_value = $self->GetArgParse(1, @FunArgs);
    $lv_arg_1 = $self->GetArgParse(2, @FunArgs); #--val2
    if ($self->IsArg(2, @FunArgs)) {
      #-- get the <then> condition
      #-- See if val1 and val2 are numeric
      $ln_value = $U->GetNumber($fv_value,1);
      $ln_arg_1 = $U->GetNumber($lv_arg_1,1);
      if ($ln_value ne "" and $ln_arg_1 ne "") {
        #-- Do a numeric based comparison
        #-- see if the <then> was specified
        if ($self->IsArg(3, @FunArgs)) {   #--then
          #-- See if the <val1> is less than <val2>
          if ($ln_value < $ln_arg_1) {
            #-- Expression was true, so value is the <then> part of the expression
            $fv_value = $self->GetArgParse(3, @FunArgs); #--then
          } else {
            #-- Expression was false, so value is the <else> part of the expression
            $fv_value = $self->GetArgParse(4, @FunArgs);
          }
        } else {   #-- no) {/else - use standard functionality
          #-- Do a numeric based comparison
          if ($ln_value < $ln_arg_1) {
            $fv_value = '1';
          } else {
            $fv_value = '0';
          }
        }
      } else {
        #-- Do a text based comparison
        #-- see if the <then> was specified
        if ($self->IsArg(2, @FunArgs)) {
          #-- See if the <val1> is less than <val2>
          if ($fv_value < $lv_arg_1) {
            #-- Expression was true, so value is the <then> part of the expression
            $fv_value = $self->GetArgParse(3, @FunArgs); #--then
          } else {
            #-- Expression was false, so value is the <else> part of the expression
            $fv_value = $self->GetArgParse(4, @FunArgs);
          }
        } else {   #-- no) {/else - use standard functionality
          #-- Do a text based comparison
          if ($fv_value < $lv_arg_1) {
            $fv_value = '1';
          } else {
            $fv_value = '0';
          }
        }
      }
    } else {
      $fv_value = $self->GetFunctionError($Function);
    }
  #-----------------------------------------------------------------------------
  #-- Check for the GREATEREQUAL / GE function - #GREATEREQUAL[val1][val2][then][else]#
  #--
  } elsif  ($Function eq 'GE'
          ||$Function eq 'GREATEREQUAL'
          ) {
    #-- Get the base text ($fv_value)
    $fv_value = $self->GetArgParse(1, @FunArgs);
    $lv_arg_1 = $self->GetArgParse(2, @FunArgs); #--val2
    if ($self->IsArg(2, @FunArgs)) {
      #-- get the <then> condition
      #-- See if val1 and val2 are numeric
      $ln_value = $U->GetNumber($fv_value,1);
      $ln_arg_1 = $U->GetNumber($lv_arg_1,1);
      if ($ln_value ne "" and $ln_arg_1 ne "") {
        #-- Do a numeric based comparison
        #-- see if the <then> was specified
        if ($self->IsArg(3, @FunArgs)) { #--then
          #-- See if the <val1> is greater than or equal <val2>
          if ($ln_value >= $ln_arg_1) {
            #-- Expression was true, so value is the <then> part of the expression
            $fv_value = $self->GetArgParse(3, @FunArgs); #--then
          } else {
            #-- Expression was false, so value is the <else> part of the expression
            $fv_value = $self->GetArgParse(4, @FunArgs);
          }
        } else {   #-- no) {/else - use standard functionality
          #-- Do a numeric based comparison
          if ($ln_value >= $ln_arg_1) {
            $fv_value = '1';
          } else {
            $fv_value = '0';
          }
        }
      } else {
        #-- Do a text based comparison
        #-- see if the <then> was specified
        if ($self->IsArg(2, @FunArgs)) {
          #-- See if the <val1> is greater than or equal <val2>
          if ($fv_value >= $lv_arg_1) {
            #-- Expression was true, so value is the <then> part of the expression
            $fv_value = $self->GetArgParse(3, @FunArgs); #--then
          } else {
            #-- Expression was false, so value is the <else> part of the expression
            $fv_value = $self->GetArgParse(4, @FunArgs);
          }
        } else {   #-- no) {/else - use standard functionality
          #-- Do a text based comparison
          if ($fv_value >= $lv_arg_1) {
            $fv_value = '1';
          } else {
            $fv_value = '0';
          }
        }
      }
    } else {
      $fv_value = $self->GetFunctionError($Function);
    }
  #-----------------------------------------------------------------------------
  #-- Check for the LESSEQUAL / LE function - #LESSEQUAL[val1][val2][then][else]#
  #--
  } elsif  ($Function eq 'LE'
          ||$Function eq 'LESSEQUAL'
          ) {
    #-- Get the base text ($fv_value)
    $fv_value = $self->GetArgParse(1, @FunArgs);
    $lv_arg_1 = $self->GetArgParse(2, @FunArgs); #--val2
    if ($self->IsArg(2, @FunArgs)) {
      #-- get the <then> condition
      #-- See if val1 and val2 are numeric
      $ln_value = $U->GetNumber($fv_value,1);
      $ln_arg_1 = $U->GetNumber($lv_arg_1,1);
      if ($ln_value ne "" and $ln_arg_1 ne "") {
        #-- Do a numeric based comparison
        #-- see if the <then> was specified
        if ($self->IsArg(3, @FunArgs)) { #--then
          #-- See if the <val1> is less than or equal <val2>
          if ($ln_value <= $ln_arg_1) {
            #-- Expression was true, so value is the <then> part of the expression
            $fv_value = $self->GetArgParse(3, @FunArgs); #--then
          } else {
            #-- Expression was false, so value is the <else> part of the expression
            $fv_value = $self->GetArgParse(4, @FunArgs);
          }
        } else {   #-- no) {/else - use standard functionality
          #-- Do a numeric based comparison
          if ($ln_value <= $ln_arg_1) {
            $fv_value = '1';
          } else {
            $fv_value = '0';
          }
        }
      } else {
        #-- Do a text based comparison
        #-- see if the <then> was specified
        if ($self->IsArg(2, @FunArgs)) {
          #-- See if the <val1> is less than or equal <val2>
          if ($fv_value <= $lv_arg_1) {
            #-- Expression was true, so value is the <then> part of the expression
            $fv_value = $self->GetArgParse(3, @FunArgs); #--then
          } else {
            #-- Expression was false, so value is the <else> part of the expression
            $fv_value = $self->GetArgParse(4, @FunArgs);
          }
        } else {   #-- no) {/else - use standard functionality
          #-- Do a text based comparison
          if ($fv_value <= $lv_arg_1) {
            $fv_value = '1';
          } else {
            $fv_value = '0';
          }
        }
      }
    } else {
      $fv_value = $self->GetFunctionError($Function);
    }
  #-----------------------------------------------------------------------------
  #-- Check for the BETWEEN function - #BETWEEN[compare][val1][val2].[then].[else]#
  #-- - returns 1 if <compare> is between <val1> and <val2>
  } elsif  ($Function eq 'BETWEEN') {
    #-- Get the compare text ($lv_arg_1)
    $lv_arg_1 = $self->GetArgParse(1, @FunArgs);
    $lv_arg_2 = $self->GetArgParse(2, @FunArgs);
    $lv_arg_3 = $self->GetArgParse(3, @FunArgs);
    if ($self->IsArg(3, @FunArgs)) {
      #-- try to get the <then> text
      #-- try to convert the parameters to numbers for numeric between compare
      if  ( $lv_arg_1 ne ""
         || $lv_arg_2 ne ""
         || $lv_arg_3 ne "") {
        $ln_arg_1 = $U->GetNumber($lv_arg_1,1);
        $ln_arg_2 = $U->GetNumber($lv_arg_2,1);
        $ln_arg_3 = $U->GetNumber($lv_arg_3,1);
      }
      if (  ($ln_arg_1 eq "" && $lv_arg_1 ne "")
         || ($ln_arg_2 eq "" && $lv_arg_2 ne "")
         || ($ln_arg_3 eq "" && $lv_arg_3 ne "")
         ) {
        #-- Do a character comparison
        if ($self->IsArg(4, @FunArgs) == 1) { #--then
          #-- use the specified <then><else> text
          if ( $lv_arg_1 ge $lv_arg_2
            && $lv_arg_1 le $lv_arg_3
            ) {
            $fv_value = $self->GetArgParse(4, @FunArgs); #--then
          } else {
            #-- get the else from the last parameter
            $fv_value = $self->GetArgParse(5, @FunArgs);
          }
        } else {   #-- no) {/else - use standard functionality
          if ( $lv_arg_1 ge $lv_arg_2
            && $lv_arg_1 le $lv_arg_3
            ) {
            $fv_value = '1';
          } else {
            $fv_value = '0';
          }
        }
      } else {
        #-- Do a numeric comparison
        if ($self->IsArg(4, @FunArgs)) {
          #-- use the specified <then><else> text
          if ( $ln_arg_1 >= $ln_arg_2
            && $ln_arg_1 <= $ln_arg_3
            ) {
            $fv_value = $self->GetArgParse(4, @FunArgs); #--then
          } else {
            #-- get the else from the last parameter
            $fv_value = $self->GetArgParse(5, @FunArgs);
          }
        } else {   #-- no) {/else - use standard functionality
          if ($ln_arg_1 >= $ln_arg_2
            && $ln_arg_1 <= $ln_arg_3
            ) {
            $fv_value = '1';
          } else {
            $fv_value = '0';
          }
        }
      }
    } else {
      $fv_value = $self->GetFunctionError($Function);
    }
  #-----------------------------------------------------------------------------
  #-- Check for the IN / INLIKE function - #IN[<text>][<val1>][<val2>]...[<valn>]#
  #--   (MJ 2003/05/01 #-- also support NOTIN and NOTINLIKE functions)
  #--
  } elsif  ($Function eq 'IN'
          ||$Function eq 'INLIKE'
          ||$Function eq 'NOTIN'
          ||$Function eq 'NOTINLIKE'
          ) {
    use Core::Like;
    my $lb_like = 0;
    #-- Get the base text ($lv_arg_1)
    $lv_arg_1 = $self->GetArgParse(1, @FunArgs);
    #-- set return values 1/0 for IN% / NOTIN% functions
    if (!$U->like($Function, 'NOT%')) {
      $fv_value = '0'; #-- "found" return value (default)
      $lv_arg_3 = '1'; #-- "not found" return value
    } else {
      $fv_value = '1'; #-- "found" return value (default)
      $lv_arg_3 = '0'; #-- "not found" return value
    }
    #-- set LIKE boolean to true or false
    $lb_like = $U->like($Function, '%LIKE');
    $li_index = 2;
    while (1) {
      #-- Get the next argument
      $lv_arg_2 = $self->GetArgParse($li_index, @FunArgs);
      #-- leave if we have a not null or there are no more arguments or the argument count exceeds 5000
      last if    (!$self->IsArg($li_index, @FunArgs)
                || $li_index > 5000);
      if (!$lb_like) {
        #-- check for standard IN or INLIKE
        if ($lv_arg_2 eq $lv_arg_1) {
          $fv_value = $lv_arg_3; #-- "found" return value
          last;
        }
      } else {
        #-- check for INLIKE function
        #-- check for standard IN or INLIKE
        if (  $U->like($lv_arg_2, $lv_arg_1)
           || $U->like($lv_arg_1, $lv_arg_2)
           || ($lv_arg_1 eq "" && $lv_arg_2 eq "")
          ) {
          $fv_value = $lv_arg_3; #-- "found" return value
          last;
        }
      }
      #-- increment the index
      $li_index = $li_index + 1;
    }
  #-----------------------------------------------------------------------------
  #-- Check for the NOTEXISTS or ISNULL or NULL function - #NOTEXISTS[<text>][then][else]#
  #-- Returns 1 if ANY of the expressions (vals) is true, 0 otherwise
  #--
  } elsif  ($Function eq 'NOTEXISTS'     # in ('NOTEXISTS', 'ISNULL', 'NULL')
          ||$Function eq 'ISNULL'
          ||$Function eq 'NULL'
          ) {
    #-- Get the next argument
    $lv_arg_1 = $self->GetArgParse(1, @FunArgs);
    if ($self->IsArg(2, @FunArgs)) { #--then
      if ($lv_arg_1 eq "") {
        #-- Expression was true, so value is the <then> part of the expression
        $fv_value = $self->GetArgParse(2, @FunArgs); #--then
      } else {
        #-- Expression was false, so value is the <else> part of the expression
        $fv_value = $self->GetArgParse(3, @FunArgs);
      }
    } else {   #-- use standard functionality
      if ($lv_arg_1 eq "") {
        $fv_value = '1';
      } else {
        $fv_value = '0';
      }
    }
  #-----------------------------------------------------------------------------
  #-- Check for the EVAL function - #EVAL[<text>][then][else]#
  #-- Returns 1 if the expression is true, 0 otherwise
  #-- [condition].[then].[else]   - evaluates the boolean expression and returns boolean 1 or 0; null evaluates to 0
  } elsif  ($Function eq 'EVAL') {
    #-- Get the next argument
    $lv_arg_1= $self->GetArgNoParse(1, @FunArgs);
    if ($self->IsArg(2, @FunArgs)) { #--then
      if ($self->Eval($lv_arg_1)) {
        #-- Expression was true, so value is the <then> part of the expression
        $fv_value = $self->GetArgParse(2, @FunArgs); #--then
      } else {
        #-- Expression was false, so value is the <else> part of the expression
        $fv_value = $self->GetArgParse(3, @FunArgs);
      }
    } else {   #-- no) {/else - use standard functionality
      if ($self->Eval($lv_arg_1)) {
        $fv_value = '1';
      } else {
        $fv_value = '0';
      }
    }

  #-----------------------------------------------------------------------------
  #-- Check for the TRUNC function - #TRUNC[<number>][<decimals>]#
  #--
  } elsif  ($Function eq 'TRUNC') {
    use Core::Math::Round;
    #-- Get the base text ($fv_value)
    $fv_value = $self->GetArgParse(1, @FunArgs);
    $ln_value = $U->GetNumber($fv_value,1);
    $lv_arg_1 = $self->GetArgParse(2, @FunArgs);
    $ln_arg_1 = $U->NVL($U->GetNumber($lv_arg_1,1), 0);
    $fv_value = $U->trunc($ln_value, $ln_arg_1);
  #-----------------------------------------------------------------------------
  #-- Check for the CHR function - #CHR[<n>]# - not implemented
  #--
  #} elsif  ($Function eq 'CHR') {
  #  #-- Get the base text ($fv_value)
  #  $fv_value = $self->GetArgParse(1, @FunArgs);
  #  $fv_value = chr($U->GetNumber($fv_value,1));
  #-----------------------------------------------------------------------------
  #-- Check for the RPAD function - #RPAD[<text>][<length>][<char>]#
  #--
  } elsif  ($Function eq 'RPAD') {
    #-- Get the base text ($fv_value)
    $fv_value = $self->GetArgParse(1, @FunArgs);
    $lv_arg_1 = $self->GetArgParse(2, @FunArgs); #-- length
    if ($self->IsArg(2, @FunArgs)) {
      $ln_arg_1 = $U->NVL($U->GetNumber($lv_arg_1,1), 1);
      $lv_arg_2 = $self->GetArgParse(3, @FunArgs);
      $lv_arg_2 = $U->NVL($lv_arg_2, ' ');
      # RPAD
      $fv_value = $U->rpad($fv_value, $ln_arg_1, $lv_arg_2);
    } else {
      $fv_value = $self->GetFunctionError($Function);
    }
  #-----------------------------------------------------------------------------
  #-- Check for the LPAD function - #LPAD[<text>][<length>][<char>]#
  #--
  } elsif  ($Function eq 'LPAD') {
    #-- Get the base text ($fv_value)
    $fv_value = $self->GetArgParse(1, @FunArgs);
    $lv_arg_1 = $self->GetArgParse(2, @FunArgs); #-- length
    if ($self->IsArg(2, @FunArgs)) {
      $ln_arg_1 = $U->NVL($U->GetNumber($lv_arg_1,1), 1);
      $lv_arg_2 = $self->GetArgParse(3, @FunArgs);
      $lv_arg_2 = $U->NVL($lv_arg_2, ' ');
      # LPAD
      $fv_value = $U->lpad($fv_value, $ln_arg_1, $lv_arg_2);
    } else {
      $fv_value = $self->GetFunctionError($Function);
    }
  #-----------------------------------------------------------------------------
  #-- Check for the RTRIM function - #RTRIM[<text>][<char>]#
  #--
  } elsif  ($Function eq 'RTRIM') {
    #-- Get the base text ($fv_value)
    $fv_value = $self->GetArgParse(1, @FunArgs);
    $lv_arg_1 = $self->GetArgParse(2, @FunArgs);
    #$lv_arg_1 = $U->NVL($lv_arg_1, ' ');
    # RTRIM
    $fv_value = $U->rtrim($fv_value, $lv_arg_1);
  #-----------------------------------------------------------------------------
  #-- Check for the LTRIM function - #LTRIM[<text>][<char>]#
  #--
  } elsif  ($Function eq 'LTRIM') {
    #-- Get the base text ($fv_value)
    $fv_value = $self->GetArgParse(1, @FunArgs);
    $lv_arg_1 = $self->GetArgParse(2, @FunArgs);
    #$lv_arg_1 = $U->NVL($lv_arg_1, ' ');
    # LTRIM
    $fv_value = $U->ltrim($fv_value, $lv_arg_1);
  #-----------------------------------------------------------------------------
  #-- Check for the TRIM function - #TRIM[<text>][<char>]#
  #--
  } elsif  ($Function eq 'TRIM') {
    #-- Get the base text ($fv_value)
    $fv_value = $self->GetArgParse(1, @FunArgs);
    $lv_arg_1 = $self->GetArgParse(2, @FunArgs);
    #$lv_arg_1 = $U->NVL($lv_arg_1, ' ');
    # TRIM
    $fv_value = $U->trim($fv_value, $lv_arg_1);
  #-----------------------------------------------------------------------------
  #-- Check for the WRAP function - #WRAP[<text>][<maxlength>][<wb_chars>][<$lb_chars>]#
  #--
  } elsif  ($Function eq 'WRAP') {
    use Orbit::Utils::Wrap;
    #-- Get the first argument (text value)
    $fv_value = $self->GetArgParse(1, @FunArgs);
    $lv_arg_2 = $self->GetArgParse(2, @FunArgs);
    $ln_arg_2 = $U->GetNumber($lv_arg_2,1);
    $lv_arg_3 = $self->GetArgParse(3, @FunArgs);
    $lv_arg_4 = $self->GetArgParse(4, @FunArgs);
    #-- Return the wrapped token value
    $fv_value = $self->Wrap_Text($fv_value, $ln_arg_2, $lv_arg_3, $lv_arg_4);
  #-----------------------------------------------------------------------------
  #-- Check for the WRAPTOKEN function - #WRAPTOKEN[<token_name>][<maxlength>][<wb_chars>][<$lb_chars>]#
  #--
  } elsif  ($Function eq 'WRAPTOKEN') {
    use Orbit::Utils::Wrap;
    #-- Get the first argument (token name)
    $lv_arg_1 = $self->GetArgParse(1, @FunArgs);
    $lv_arg_2 = $self->GetArgParse(2, @FunArgs);
    $ln_arg_2 = $U->GetNumber($lv_arg_2,1);
    $lv_arg_3 = $self->GetArgParse(3, @FunArgs);
    $lv_arg_4 = $self->GetArgParse(4, @FunArgs);
    #-- Get the token value
    $fv_value = $self->Get_Token($lv_arg_1);
    #-- Wrap the token value and save the results back to the token
    $fv_value = $self->Wrap_Text($fv_value, $ln_arg_2, $lv_arg_3, $lv_arg_4);
  #-----------------------------------------------------------------------------
  #-- Check for the STRIPTEXT function - #STRIPTEXT[<text>][<begin_text>][<end_text>][<replace_text>][<match_pairs>][KeepRawText]#
  #--
  } elsif  ($Function eq 'STRIPTEXT') {
    #-- Get the base text ($fv_value)
    $fv_value = $self->GetArgParse(1, @FunArgs);
    if ($self->IsArg(1, @FunArgs)) {
      $lv_arg_1 = $self->GetArgParse(2, @FunArgs);  #-- Begin Text
      $lv_arg_2 = $self->GetArgParse(3, @FunArgs);  #-- End Text
      $lv_arg_3 = $self->GetArgParse(4, @FunArgs);  #-- Replace Text
      $lv_arg_4 = $self->GetArgParse(5, @FunArgs);
      my $KeepRawText = $self->GetArgParse(6, @FunArgs);
      $KeepRawText = 0 if ($KeepRawText ne '1');
      my $ln_arg_4 = $U->GetNumber($lv_arg_4, 1);  #-- Match Pairs
      #-- Call Strip_Text_Long; use default argument values
      $fv_value = $self->Strip_Text($fv_value, $U->NVL($lv_arg_1, '<!---'),
                                            $U->NVL($lv_arg_2, '--->'),
                                            $lv_arg_3,
                                            $U->NVL($ln_arg_4, 0),
                                            $KeepRawText);
    } else {
      $fv_value = $self->GetFunctionError($Function);
    }
  #-----------------------------------------------------------------------------
  #-- Check for the SIGN function - #SIGN[<number>]#
  #--
  } elsif  ($Function eq 'SIGN') {
    use Core::Math;
    #-- Get the base text ($fv_value)
    $fv_value = $self->GetArgParse(1, @FunArgs);
    $ln_value = $U->GetNumber($fv_value,1);
    $fv_value = $U->sign($ln_value);
  #-----------------------------------------------------------------------------
  #-- Check for the ABS function - #ABS[<number>]#
  #--
  } elsif  ($Function eq 'ABS') {
    #-- Get the base text ($fv_value)
    $fv_value = $self->GetArgParse(1, @FunArgs);
    $ln_value = $U->GetNumber($fv_value,1);
    $fv_value = abs($ln_value);
  #-----------------------------------------------------------------------------
  #-- Check for the MOD function - #MOD[<m>][<n>]#
  #--
  } elsif  ($Function eq 'MOD') {
    use Core::Math;
    #-- Get the base text ($fv_value)
    $fv_value = $self->GetArgParse(1, @FunArgs);
    $ln_value = $U->GetNumber($fv_value,1);
    $lv_arg_1 = $self->GetArgParse(2, @FunArgs);
    if ($self->IsArg(2, @FunArgs)) {
      $ln_arg_1 = $U->NVL($U->GetNumber($lv_arg_1,1), 0);
      if ($ln_arg_1 == 0) {
        #-- don't divide by 0
        $fv_value = '';
      } else {
        $fv_value = $U->mod($ln_value, $ln_arg_1);
      }
    } else {
      $fv_value = $self->GetFunctionError($Function);
    }
  #-----------------------------------------------------------------------------
  #-- Check for the ADD function - #ADD[<a>][<b>]...[<n>]#
  #--
  } elsif  ($Function eq 'ADD') {
    #-- Get the first argument
    $ln_value = '';
    $fv_value = $self->GetArgParse(1, @FunArgs);
    $ln_value = $U->GetNumber($fv_value,1);
    $li_index = 2;
    while (1) {
      #-- Get the next argument
      $lv_arg_1 = $self->GetArgParse($li_index, @FunArgs);
      #-- leave if no more arguments or the argument count exceeds 500
      last if   (!$self->IsArg($li_index, @FunArgs)
                || $li_index > 500);
      $ln_arg_1 = $U->GetNumber($lv_arg_1,1);
      #-- ADD the values
      if ($ln_value ne "" && $ln_arg_1 ne "") {
        $ln_value = $ln_value + $ln_arg_1;
      } else {
        $ln_value = '';   # non number found, so return blank for operation
        last;
      }
      #-- increment the index
      $li_index = $li_index + 1;
    }
    $fv_value = $ln_value;
  #-----------------------------------------------------------------------------
  #-- Check for the SUBTRACT function - #SUB[<a>][<b>]...[<n>]#
  #--
  } elsif ($Function eq 'SUB'
         ||$Function eq 'SUBTRACT'
          ) {
    #-- Get the first argument
    $ln_value = '';
    $fv_value = $self->GetArgParse(1, @FunArgs);
    $ln_value = $U->GetNumber($fv_value,1);
    $li_index = 2;
    while (1) {
      #-- Get the next argument
      $lv_arg_1 = $self->GetArgParse($li_index, @FunArgs);
      #-- leave if no more arguments or the argument count exceeds 500
      last if    (!$self->IsArg($li_index, @FunArgs)
                || $li_index > 500);
      $ln_arg_1 = $U->GetNumber($lv_arg_1,1);
      #-- SUBTRACT the values
      if ($ln_value ne "" && $ln_arg_1 ne "") {
        $ln_value = $ln_value - $ln_arg_1;
      } else {
        $ln_value = '';   # non number found, so return blank for operation
        last;
      }
      #-- increment the index
      $li_index = $li_index + 1;
    }
    $fv_value = $ln_value;
  #-----------------------------------------------------------------------------
  #-- Check for the MULTIPLY function - #MULT[<a>][<b>]...[<n>]#
  #--
  } elsif ($Function eq 'MULT'
         ||$Function eq 'MULTIPLY'
          ) {
    #-- Get the first argument
    $ln_value = '';
    $fv_value = $self->GetArgParse(1, @FunArgs);
    $ln_value = $U->GetNumber($fv_value,1);
    # Make sure number exists
    if ($ln_value ne '') {
      $li_index = 2;
      while (1) {
        #-- Get the next argument
        $lv_arg_1 = $self->GetArgParse($li_index, @FunArgs);
        #-- leave if no more arguments or the argument count exceeds 500
        last if    (!$self->IsArg($li_index, @FunArgs)
                  || $li_index > 500);
        $ln_arg_1 = $U->GetNumber($lv_arg_1,1);
        # Make sure number exists
        if ($ln_arg_1 ne '') {
          #-- MULTIPLY the values
          $ln_value = $ln_value * $ln_arg_1;
        } else {
          $ln_value = '';   # non number found, so return blank for operation
          last;
        }
        #-- increment the index
        $li_index = $li_index + 1;
      }
    }
    $fv_value = $ln_value;
  #-----------------------------------------------------------------------------
  #-- Check for the DIVIDE function - #DIV[<a>][<b>]...[<n>]#
  #--
  } elsif ($Function eq 'DIV'
         ||$Function eq 'DIVIDE'
          ) {
      #-- Get the first argument
      $ln_value = '';
      $fv_value = $self->GetArgParse(1, @FunArgs);
      $ln_value = $U->GetNumber($fv_value,1);
      $li_index = 2;
      while (1) {
        #-- Get the next argument
        $lv_arg_1 = $self->GetArgParse($li_index, @FunArgs);
        #-- leave if no more arguments or the argument count exceeds 500
        last if    (!$self->IsArg($li_index, @FunArgs)
                  || $li_index > 500);
        $ln_arg_1 = $U->GetNumber($lv_arg_1,1);
        #-- DIVIDE the values
        if ($ln_arg_1 ne '0' && $ln_value ne "" && $ln_arg_1 ne "") {
          $ln_value = $ln_value / $ln_arg_1;
        } else {
          # Divide by 0
          $ln_value = '';
          last;
        }
        #-- increment the index
        $li_index = $li_index + 1;
      }
      $fv_value = $ln_value;
  #-----------------------------------------------------------------------------
  #-- Check for the APPEND function - #APPEND[<text1>][<text2>][<linebreak>]#
  #--
  } elsif  ($Function eq 'APPEND') {
    $fv_value = $self->GetArgParse(1, @FunArgs);
    #-- Get the text to concatenate
    $lv_arg_1 = $self->GetArgParse(2, @FunArgs);
    if ($self->IsArg(2, @FunArgs)) {
      #-- Get the linebreak character
      $lv_arg_2 = $self->GetArgParse(3, @FunArgs);
      #-- only use linebreak if original text ne ""
      if ($fv_value ne "") {
        $fv_value = $fv_value.$lv_arg_2.$lv_arg_1;
      } else {
        $fv_value = $lv_arg_1;
      }
    }
  #-----------------------------------------------------------------------------
  #-- Check for the MIN function - #MIN[<a>][<b>]...[<n>]#
  #--
  } elsif  ($Function eq 'MIN') {
    #-- initialize loop variables
    $ln_value = '';
    $fv_value = '';
    my $lb_numeric = 1;
    $li_index = 1;
    #-- loop through all arguments
    while (1) {
      #-- Get the next argument
      $lv_arg_1 = $self->GetArgParse($li_index, @FunArgs);
      #-- leave if no more arguments or the argument count exceeds 500
      last if    (!$self->IsArg($li_index, @FunArgs)
                || $li_index > 500);
      #-- only do numeric comparisons if text argument not yet found
      if ($lb_numeric) {
        $ln_arg_1 = $U->GetNumber($lv_arg_1,1);
        #-- switch to text based comparison if a non-numeric is found
        if ($ln_arg_1 eq "" && $lv_arg_1 ne "") {
          $lb_numeric = 0;
        #-- remember smaller of $ln_value and $ln_arg_1
        } elsif  (  $ln_value eq ""
                 || $ln_value > $ln_arg_1
                 ) {
          $ln_value = $ln_arg_1;
        }
      }
      #-- always do text comparisons, in case text argument later found
      if (  $fv_value eq ""
         || $fv_value > $lv_arg_1) {
        $fv_value = $lv_arg_1;
      }
      #-- increment the index
      $li_index = $li_index + 1;
    }
    #-- return numeric or text minimum as appropriate
    if ($lb_numeric) {
      $fv_value = $U->to_char($ln_value);
    }
  #-----------------------------------------------------------------------------
  #-- Check for the MAX function - #MAX[<a>][<b>]...[<n>]#
  #--
  } elsif  ($Function eq 'MAX') {
    #-- initialize loop variables
    $ln_value = '';
    $fv_value = '';
    my $lb_numeric = 1;
    $li_index = 1;
    #-- loop through all arguments
    while (1) {
      #-- Get the next argument
      $lv_arg_1 = $self->GetArgParse($li_index, @FunArgs);
      #-- leave if no more arguments or the argument count exceeds 500
      last if    (!$self->IsArg($li_index, @FunArgs)
                || $li_index > 500);
      #-- only do numeric comparisons if text argument not yet found
      if ($lb_numeric) {
        $ln_arg_1 = $U->GetNumber($lv_arg_1,1);
        #-- switch to text based comparison if a non-numeric is found
        if ($ln_arg_1 eq "" && $lv_arg_1 ne "") {
          $lb_numeric = 0;
        #-- remember larger of $ln_value and $ln_arg_1
        } elsif (   $ln_value eq ""
                 || $ln_value < $ln_arg_1) {
          $ln_value = $ln_arg_1;
        }
      }
      #-- always do text comparisons, in case text argument later found
      if (  $fv_value eq ""
         || $fv_value < $lv_arg_1) {
        $fv_value = $lv_arg_1;
      }
      #-- increment the index
      $li_index = $li_index + 1;
    }
    #-- return numeric or text maximum as appropriate
    if ($lb_numeric) {
      $fv_value = $U->to_char($ln_value);
    }
  #-----------------------------------------------------------------------------
  #-- Check for the AVG function - #AVG[<a>][<b>]...[<n>]#
  #--
  } elsif  ($Function eq 'AVG') {
    my $ln_count = 0;
    #-- Get the first argument
    $ln_value = '';
    $fv_value = $self->GetArgParse(1, @FunArgs);
    if ($self->IsArg(1, @FunArgs)) {
      $ln_value = $U->GetNumber($fv_value,1);
      if ($ln_value ne "") {
        $ln_count = 1;
      } else {
        $ln_count = 0;
      }
      $li_index = 2;
      while (1) {
        #-- Get the next argument
        $lv_arg_1 = $self->GetArgParse($li_index, @FunArgs);
        #-- leave if no more arguments or the argument count exceeds 500
        last if    (!$self->IsArg($li_index, @FunArgs)
                  || $li_index > 500);
        $ln_arg_1 = $U->GetNumber($lv_arg_1,1);
        #-- If the first value eq "", immediately assign the next value
        if ($ln_value eq "") {
          $ln_value = $ln_arg_1;
          if ($ln_value ne "") {
            $ln_count = 1;
          } else {
            $ln_count = 0;
          }
        } else {
          if ($ln_arg_1 ne "") {
            #-- ADD the values
            $ln_value = $ln_value + $ln_arg_1;
            #-- Increment the non-null counter
            $ln_count = $ln_count + 1;
          }
        }
        #-- increment the index
        $li_index = $li_index + 1;
      }
    }
    #-- Only compute average if the number of non-null elements were > 0
    if ($ln_count > 0) {
      $fv_value = $U->to_char($ln_value / $ln_count);
    } else {
      $fv_value = '';
    }

  #-----------------------------------------------------------------------------
  #
  # DATA PROCESSING FUNCTIONS USED LESS FREQUENTLY AT THE END
  #
  #-----------------------------------------------------------------------------

  #-----------------------------------------------------------------------------
  #-- Check for the DATAOPEN function - #DATAOPEN[Root][Word/Phrase/Path][DataFile].[Sep].[Sort]#
  #-- Sets the datafile location based on Root (off of Domain), Word/Phrase/Path index, and datafile (ie CATS.dat);
  #-- Separator and Sort flag can also be set in this call.
  #--
  } elsif ($Function eq 'DATAOPEN') {
    my $root     = $self->GetArgParse(1, @FunArgs);   #ROOT
    my $word     = $self->GetArgParse(2, @FunArgs);   #WORD/PHRASE/PATH
    my $datafile = $self->GetArgParse(3, @FunArgs);   #DATAFILE
    $lv_arg_4    = $self->GetArgParse(4, @FunArgs);   #sep
    my $lv_arg_5    = $self->GetArgParse(5, @FunArgs);   #sort

    #
    # Make sure datafile exists
    #
    if ($self->{_Akashic}->GetWordDataFileDir($root, $word, $datafile) ne "") {
      $self->{_DATAROOT} = $root;       # Data Root under Domain. Set with DATAOPEN
      $self->{_DATAWORD} = $word;       # Word/Phrase/Path under Root
      $self->{_DATAFILE} = $datafile;   # Datfile name (ie CATS.dat)
      # Set the Data Separator
      if ($lv_arg_4 ne "") {
        $self->{_DATASEP}  = $lv_arg_4;   # Separator
      }
      # Set the Sort flag
      if ($lv_arg_5 ne "") {
        $self->{_DATASORT} = $self->Eval($lv_arg_5);   # Sort Flag
      }
    } else {
      #
      $fv_value = "DATAOPEN: Datafile not found ($root)($word)($datafile)";
      # Unset stored values
      $self->{_DATAROOT} = '';
      $self->{_DATAWORD} = '';
      $self->{_DATAFILE} = '';
      $self->{_DATASEP}  = '|';
      $self->{_DATASORT} = '0';
     }

  #-----------------------------------------------------------------------------
  #-- Check for the DATACLOSE function - #DATACLOSE[Root][Word/Phrase/Path][DataFile]#
  #-- Closes the datafile and frees up the internal arrays
  #-- This procedure is formally not needed, but supported for different datasets in the future, and generally good programming practice
  #-- Useful for running in batch to clean up after each run, but this is done automatically after ShowPage
  #--
  } elsif ($Function eq 'DATACLOSE') {
    $self->{_DATAROOT} = '';       # Data Root under Domain. Set with DATAOPEN
    $self->{_DATAWORD} = '';       # Word/Phrase/Path under Root
    $self->{_DATAFILE} = '';       # Datfile name (ie CATS.dat)
    # Undefine data and columns
    undef $self->{_COLUMNS};
    undef $self->{_DATA};
    undef $self->{_STATS};

  #-----------------------------------------------------------------------------
  #-- Check for the DATASEP function - #DATASEP[Separator]#
  #-- Defines the data separator for columns and data in the datafile
  #--
  } elsif ($Function eq 'DATASEP') {
    $lv_arg_1    = $self->GetArgParse(1, @FunArgs);   #sep
    if ($lv_arg_1 ne "") {
      $self->{_DATASEP} = $lv_arg_1;
    }
    $fv_value = '';

  #-----------------------------------------------------------------------------
  #-- Check for the DATASORT function - #DATASORT[SortFlag]#
  #-- Set option to sort data when reading (1/0)
  #--
  } elsif ($Function eq 'DATASORT') {
    $lv_arg_1    = $self->GetArgParse(1, @FunArgs);   #sort
    $self->{_DATASORT} = $self->Eval($lv_arg_1);
    $fv_value = '';

  #-----------------------------------------------------------------------------
  #-- Check for the DATAHEADER function - #DATAHEADER[HeaderFlag]#
  #-- Set Header Flag (1/0) indicating data has a header record
  #--
  } elsif ($Function eq 'DATAHEADER') {
    $lv_arg_1    = $self->GetArgParse(1, @FunArgs);   #sort
    $self->{_DATAHEADER} = $self->Eval($lv_arg_1);
    $fv_value = '';



#    ,_COLUMNS       => { }             # Columns Names (Headers) retrieved from a dataset (array)
#    ,_DATA          => { }             # Data retrieved from a source
#    ,_STATS         => { }             # Summarized Data stats based on user configuration
#    ,_DATAROOT      => ''              # Data Root under Domain. Set with DATAOPEN
#    ,_DATAWORD      => ''              # Word/Phrase/Path under Root
#    ,_DATAFILE      => ''              # Datfile name (ie CATS.dat)
#    ,_DATASEP       => '|'             # Default data and column separator
#    ,_DATACOLS      => 0               # Flag to indicate if datafile has a header record defining columns (1/0)
#    ,_DATASORT      => 0               # Flag to sort datafiles (numeric sort, then character sort) (1/0)

#        ,'DATAREAD'     #
#        ,'DATAFORMAT'   #
#        ,'DATASEARCH'   #

  #-----------------------------------------------------------------------------
  #-- Check for the DATAREAD function - #DATAREAD[StartRow][MaxRows]#
  #-- Read rows of the datafile into the internal buffer - use DATAFORMAT to print
  #--
  } elsif ($Function eq 'DATAREAD'
         &&$self->{_DATAWORD} ne ""
         &&$self->{_DATAFILE} ne ""
          ) {
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

  #-----------------------------------------------------------------------------
  #-- Check for the DATASEARCH function - #DATASEARCH[SearchText][StartRow][MaxRows]#
  #-- Searches rows of the datafile and stores in the internal buffer - use DATAFORMAT to print
  #--
  } elsif ($Function eq 'DATASEARCH'
         &&$self->{_DATAWORD} ne ""
         &&$self->{_DATAFILE} ne ""
          ) {
    my $Search   = $self->GetArgParse(1, @FunArgs);
    my $StartRow = $self->GetArgParse(2, @FunArgs);
    my $MaxRows  = $self->GetArgParse(3, @FunArgs);
    $StartRow = 1 if (!$self->IsNumber($StartRow));
    $MaxRows = -1 if (!$self->IsNumber($MaxRows));

  #-----------------------------------------------------------------------------
  #-- Check for the DATAFORMAT function - #DATAFORMAT[header][repeat_body][footer].[Search][StartRow][MaxRows].[silent]#
  #-- Format the internal data buffer, showing header, body, footer;
  #-- silent (1) shows no header/footer if no data found
  #--
  } elsif ($Function eq 'DATAFORMAT'
         &&$self->{_DATAWORD} ne ""
         &&$self->{_DATAFILE} ne ""
          ) {
    #-- Get the argument
    $lv_arg_1    = $self->GetArgNoParse(1, @FunArgs);   #header
    $lv_arg_2    = $self->GetArgNoParse(2, @FunArgs);   #repeat_body
    $lv_arg_3    = $self->GetArgNoParse(3, @FunArgs);   #footer
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
      $fv_value .= $lv_arg_1."\n";
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
        $fv_value .= $self->Parse($lv_arg_2."\n", $bFlush);
      }
      undef @data;
    }

    # Print the footer if we have data
    if ($bData || !$bSilent) {
      # Add the footer
      $fv_value .= $lv_arg_3."\n";
    }

  #-----------------------------------------------------------------------------
  #-- Check for the DATAREC / RECORD / REC function - #DATAREC[Root][Word/Phrase/Path][DataFile]#
  #-- - Get the data record from the datafile and assign tokens to the values based on header record (if present):  !HEADER:a|b|c
  #--
  } elsif ($Function eq 'DATAREC'
         ||$Function eq 'RECORD'
         ||$Function eq 'REC'
         ) {
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
    $fv_value = $self->{_Akashic}->GetWordRecord($root, $word, $datafile);

  #-----------------------------------------------------------------------------
  #-- Check for the BEFORE / AFTER / SHOWON function - #AFTER[YYYYMMDDHHMISS].[then<template>].[else<template>].[_1_].[_2_].[_3_]...[_n_]#
  #-- Aliases: BEFORE AFTER SHOWON
  } elsif ($Function eq 'BEFORE'
         ||$Function eq 'AFTER'
         ||$Function eq 'SHOWON'
         ) {


  #-----------------------------------------------------------------------------
  #-- Check for the BACKUP function - #BACKUP[token]...[token]#
  #-- Backup all of the TOKENs, setting existing value to TOKEN_BACK (default).
  #-- #BackupExt[_BAK]# provides an alternate Extension.
  } elsif ($Function eq 'BACKUP') {
    $fv_value = "";   # Action function - no return value
  my $Tokens = "";
  # Loop through all arguments to restore
  for (my $I=1; $I <= @FunArgs; $I++) {
    #-- Get the next argument
    $Tokens = $U->trim($self->GetArgNoParse($I, @FunArgs));

    # Check for multiple tokens space separated
    if (index($Tokens, ' ') == -1) {
      # Single token
      $self->Set_Token($Tokens.$self->{_BackupExt}, $self->Get_Token($Tokens)) if ($Tokens ne "");
    } else {
      # Multiple tokens specified
      my @TOKENS = split(' ', $Tokens);
      foreach my $tok (@TOKENS) {
        $self->Set_Token($tok.$self->{_BackupExt}, $self->Get_Token($tok)) if ($tok ne '');
      }
      undef @TOKENS;
    }
  }
  #-----------------------------------------------------------------------------
  #-- Check for the DELETE function - #DELETE[token]...[token]#
  #-- - Delete all of the TOKENs to free up memory.  Useful for large buffers in certain tokens.
  #--
  } elsif ($Function eq 'DELETE') {
    $fv_value = "";   # Action function - no return value
    # Loop through all arguments to restore
    for ($li_index=1; $li_index <= @FunArgs; $li_index++) {
      #-- Get the next argument
      $lv_arg_1 = $self->GetArgNoParse($li_index, @FunArgs);
      if ($lv_arg_1 ne "") {
        $self->Delete_Token($lv_arg_1);
      }
    }

  #-----------------------------------------------------------------------------
  #-- Check for the BACKUPEXT function - #BACKUPEXT[BackupExt]#
  #-- Set the default Token Backup Extension for all future calls of BACKUP and RESTORE
  } elsif ($Function eq 'BACKUPEXT') {
    $lv_arg_1 = $self->GetArgParse(1, @FunArgs);
    # Reset internal token backup extension
    $self->{_BackupExt} = $lv_arg_1 if ($lv_arg_1 ne "");
    $fv_value = "";   # Action function - no return value

  #-----------------------------------------------------------------------------
  #-- Check for the NUMFORMAT function - #NUMFORMAT[Thousands_Sep][Decimal_Sep][Currency_Symbol]#
  #-- - Set the Thousands, Decimal, Currency formats for use in FORMAT
  #--
  } elsif  ($Function eq 'NUMFORMAT') {
    $fv_value = "";   # no return from this function
    #-- Get the base text ($lv_arg_1)
    $lv_arg_1 = $self->GetArgParse(1, @FunArgs);
    $lv_arg_2 = $self->GetArgParse(2, @FunArgs);
    $lv_arg_3 = $self->GetArgParse(3, @FunArgs);
    #-- Set number format
    $U->SetNumberFormat($lv_arg_1, $lv_arg_2, $lv_arg_3);

  #-----------------------------------------------------------------------------
  #-- Check for the DEBUG function - #DEBUG[<raw_text_flag>]#
  #-- if raw_text_flag = 0, show the contents of the token table in HTML table format
  #-- otherwise show contents in raw format (1) without decoration - one per line
  #--
  } elsif ($Function eq 'DEBUG') {
    #-- Get the next argument
    $lv_arg_1 = $self->GetArgParse(1, @FunArgs);
    $lv_arg_1 = '0' if ($lv_arg_1 ne '1');
    $lv_arg_2 = $self->GetArgParse(2, @FunArgs);
    #-- 1 = show token table in RAW format not in a <table>
    #-- 0 = show token table in HTML <table> format
    #-- Show the Token Table
    $fv_value = $self->ShowTokenTable($lv_arg_1, $lv_arg_2, 0);   # 0 - NoPrint, buffer only

  #-----------------------------------------------------------------------------
  #-- Check for the SHOWCOMMENTS function - #SHOWCOMMENTS[1/0]# - Show the OML comments in the pages, in escaped format
  #-- - Turn on/off Statistics - Level 0-9
  #--
  } elsif ($Function eq 'SHOWCOMMENTS') {
    $lv_arg_1 = $self->GetArgParse(1, @FunArgs);
    $lv_arg_1 = '0' if ($lv_arg_1 ne '1');
    $self->SetShowCommentsOn  if ($lv_arg_1 eq '1');
    $self->SetShowCommentsOff if ($lv_arg_1 eq '0');
    # Set for reference in page
    $self->Set_Token('SHOWCOMMENTS', $lv_arg_1);

  #-----------------------------------------------------------------------------
  #-- Check for the LOGSTATS function - #LOGSTATS[0-9]#
  #-- - Turn on/off Statistics - Level 0-9
  #--
  } elsif ($Function eq 'LOGSTATS') {
    # Don't allow changing LogStats level when running in batch mode (RefreshPageData)
    if (!$self->{_bBatchMode}) {
      $lv_arg_1 = $self->GetArgParse(1, @FunArgs);
      $lv_arg_1 = '0' if (!$self->IsNumber($lv_arg_1));
      $self->SetLogStats($lv_arg_1);
      # Set for reference in page
      $self->Set_Token('LOGSTATS', $lv_arg_1);
    }

  #-----------------------------------------------------------------------------
  #-- Check for the SHOWSTATS function - #SHOWSTATS[<bHTML>]#
  #-- - Show the Orbit Run-time stats
  #--
  } elsif ($Function eq 'SHOWSTATS') {
    # Don't show statistics if running in batch mode (RefreshPageData)
    if (!$self->{_bBatchMode}) {
      $lv_arg_1 = $self->GetArgParse(1, @FunArgs);
      $lv_arg_1 = '0' if ($lv_arg_1 ne '1');
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

      $self->AddStat('_Page Time: ', $Diff.'ms' );

      # Show the stats and read output from buffer
      $self->ShowStats('Orbit Stats', 1, $lv_arg_1);
      $fv_value = $self->GetUprintBuf();
      # Reset the parametes
      $self->SetShowStats($bShowStatsBak);
      $self->SetShowOutput($bShowOutputBak);
    }

  #-----------------------------------------------------------------------------
  #-- Check for the TIMER function - #TIMER[]#
  #-- - Set and return the PAGE_TIME token for elapsed milliseconds (ms)
  #--
  } elsif ($Function eq 'TIMER') {
    # Get the end time and compute elapsed time
    use Time::HiRes qw(time);
    # Log the end time in ms and set Token PAGE_TIMER for difference
    my $Time = time;
    $self->{_iEndTime} = int($Time*1000);
    my $Diff = $self->{_iEndTime} - $self->{_iStartTime};
    $self->Set_Token('PAGE_TIME', $Diff."ms");
    $fv_value = $Diff."ms";

  #-----------------------------------------------------------------------------
  #-- Check for the STOPTIMER function - #STOPTIMER[]#
  #-- - Return the elapsed milliseconds (ms) since the last STOPTIMER or TIMER
  #--
  } elsif ($Function eq 'STOPTIMER') {
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
    $fv_value = $Diff."ms";

  #-----------------------------------------------------------------------------
  #-- Check for the License function
  #-- - called like #LICENSE[]#
  #--
  } elsif ($Function eq 'LICENSE') {
    $fv_value = 'License: AGPLv3+: GNU Affero General Public License Version 3 or later';
  #-----------------------------------------------------------------------------
  #-- Check for the VERSION function - Shows the Orbit core and OML Version info
  #-- - called like #VERSION[<short_flag>]#
  #--   <short_flag> = 1 - show terse or short ver info
  #--
  } elsif ($Function eq 'VERSION') {
    $lv_arg_1 = $self->GetArgParse(1, @FunArgs);
    if ($lv_arg_1 ne '1') {
      # Show Long Version Information
      $fv_value = "Orbit Version: [".$self->{_VERSION}."] OML Version: [".$self->{_OML_VERSION}."}";
    } else {
      # Show Short Ver Info
      # Get Version without Date
      $lv_arg_1 = substr($self->{_VERSION}, 0, index($self->{_VERSION}, ' '));
      # Get OML Version without Date
      $lv_arg_2 = substr($self->{_OML_VERSION}, 0, index($self->{_OML_VERSION}, ' '));
      # Show Msg
      $fv_value = "Ver:[".$lv_arg_1."] OML:[".$lv_arg_2."}";
    }

  #-----------------------------------------------------------------------------
  #-- Function Not Found - Return FALSE
  } else {
    return ("", 0);
  }

  # Processed successfully
  return ($fv_value, 1);
} #Process_Function


################################################################################
# END Process_Function
################################################################################


#******************************************************************************************
#* GetFunctionError <function>
#*
#* - Returns Function error text - called from Process Function
#******************************************************************************************/
sub Orbit::GetFunctionError
{
  my ( $self, $Function ) = @_;

  return 'ORB-101: Not enough arguments for function: ['.$Function.']';
} #GetFunctionError;


#******************************************************************************************
#* IsArg <arg_index> <@FunArgs>
#*
#* - Accepts an argument list separated by ][ (not beginning or ending with any separators)
#* - Returns TRUE if the argument exists, FALSE if it doesn't
#******************************************************************************************
sub Orbit::IsArg
{
  my ( $self, $fn_arg_index, @FunArgs ) = @_;

  $fn_arg_index--;   # Use as a number (Offset read by 1)

  if (defined($FunArgs[$fn_arg_index])) {
    return 1;
  }
  return 0;
} #IsArg


#--------------------------------------------------
#-- GetArgNoParse <arg_index> <@FunArgs>
#-- - call to get_arguments w/o parsing
#-- - Arg index specified as 1,2,3... (stored as 0,1,2... in array)
#--------------------------------------------------
sub Orbit::GetArgNoParse
{
  my ( $self, $fn_arg_index, @FunArgs ) = @_;
  my $fv_arg_value = "";

  $fn_arg_index--;   # Use as a number (Offset read by 1)

  # Make sure argument exists
  if (defined($FunArgs[$fn_arg_index])) {
    $fv_arg_value = $FunArgs[$fn_arg_index];
  }

  return $fv_arg_value;
} #GetArgNoParse;


#--------------------------------------------------
#-- GetArgParse <arg_index> <@FunArgs>
#-- - local call to get_arguments - parse result field
#-- - Arg index specified as 1,2,3... (stored as 0,1,2... in array)
#--------------------------------------------------
sub Orbit::GetArgParse
{
  my ( $self, $fn_arg_index, @FunArgs ) = @_;
  my $fv_arg_value = "";

  $fn_arg_index--;   # Use as a number (Offset read by 1)

  # Make sure argument exists
  if (defined($FunArgs[$fn_arg_index])) {
    $fv_arg_value = $FunArgs[$fn_arg_index];
  }

  #
  # Parse the argument for additional OML
  #
  $fv_arg_value = $self->Parse($fv_arg_value, 0);   # Parse, no print, return buffer

  # Parse again for tokens within tokens if pattern present
  if ($fv_arg_value =~ /^.*#[A-Z_\.]*#.*$/i) {
    $fv_arg_value = $self->Parse($fv_arg_value, 0);
  }

  return $fv_arg_value;
} #GetArgParse


#========================================================================================
# END FUNCTION OML SUBROUTINES
#========================================================================================

#******************************************************************************************
# Return true to show package was loaded with
# use Orbit::OML6:Function6;
#******************************************************************************************
1;


#END Orbit::OML6:Function6 Package
