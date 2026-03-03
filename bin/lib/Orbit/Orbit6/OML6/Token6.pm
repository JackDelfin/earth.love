#!/usr/bin/perl
# Version 6.0.6.0      21-May-2021
#*****************************************************************************************
#*
#*  Package Name    :   Orbit::OML6::Token6
#*
#*  Description     :   Implements Orbit Markup Language (OML) for Token Modifiers
#*
#*****************************************************************************************
# History:
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
#use Core::Utils;
#use Core::Strings;
#use Core::Numbers;
#use Core::Math;
#use Orbit::Token;

#========================================================================================
#
#                      FUNCTION OML (ORBIT MARKUP LANGUAGE) SUBROUTINES
#
#========================================================================================


#******************************************************************************************
#*  Function Name   :   Process_Modifiers
#*
#*  Scope           :   PUBLIC
#*
#*  Description     :   Processes the Token Modifiers appended to a token.  Sets the new value in lv_value.
#*                      Returns TRUE if processed successfully, FALSE if an unknown modifier
#******************************************************************************************
sub Orbit::Process_Modifiers
{
  my( $self, $fv_token ) = @_;
  my $U = $self->{_Utils};

  my $fv_value = "";

  my $ln_period = 0;             # BINARY_INTEGER;
  my $ln_arg_1 = 0;              # BINARY_INTEGER;
  my $lv_modifiers = "";         # VARCHAR2(100);
  #-- Define a time field for the .TIME modifier
  my $li_end_time = 0;           # BINARY_INTEGER;
  my $ln_raw_flag = 0;           # BINARY_INTEGER;
  my $ln_cache_flag = 0;         # BINARY_INTEGER;
  my $lv_value = "";             # LONG;
  my $ln_numeric = 0;            # BINARY_INTEGER;

  if ($fv_token eq "") {
    return "";
  }

  # Add Token Statistic if turned on
  $self->AddStat("_Tokens Parsed") if ($self->GetLogStat());

  #--
  #-- check for '.' for performance since most tokens will NOT have a modifier directive
  #--
  $ln_period = index($fv_token, '.');
  if ($ln_period == -1) {
    #-- No modifiers found, so process and leave
    #-- Get the value of the token
    $fv_value = $self->Get_Token($fv_token);
    return $fv_value;
  }
  #-- Get the modifiers only
  $lv_modifiers = substr($fv_token,$ln_period).'.';
  $lv_modifiers =~ tr/[a-z]/[A-Z]/;

  #-- Get the Token Name
  $fv_token = substr($fv_token,0,$ln_period);

  #-- Get the value of the token
  $fv_value = $self->Get_Token($fv_token);

  #-----------------------------------------------------------------------------
  #-----------------------------------------------------------------------------
  #-----------------------------------------------------------------------------
  #--
  #-- Process the NULL type operators first
  #--

  #-- .BACKUP - PROCESSED IN OrbitParse prior to function assignment
  #-- Backup the existing token value - ALWAYS PROCESS FIRST IN MODIFIERS
  #-- TOKEN is backed up to TOKEN_BACK (default)
  #if ($self->Is_Modifier('.BACKUP', $lv_modifiers)) {
  #  # Backup the token; no change to fv_value
  #  $self->Set_Token($fv_token.$self->{_BackupExt}, $self->Get_Token($fv_token));
  #}

  #-- .RESTORE
  #-- Restore the Backup value TOKEN_BACK to the TOKEN name, keeping the backup token.
  #-- This is processed after .backup before any other modifiers.
  #-- TOKEN is restored from TOKEN_BACK
  if ($self->Is_Modifier('.RESTORE', $lv_modifiers)) {
    # Restore the token; no change to fv_value
    $self->Set_Token($fv_token, $self->Get_Token($fv_token.$self->{_BackupExt}));
  }

  #-- Put SPACE, TRIMS before LENGTH so length can work on resultant string
  #--
  #-- .SPACE
  #-- Convert tabs to spaces, and multiple spaces to 1 space (don't trim)
  if ($self->Is_Modifier('.SPACE', $lv_modifiers)) {
    $fv_value =~ s/\t/ /g;
    $fv_value =~ s/ [ ]*/ /g;
  }

  #-- .TRIM
  #-- Group TRIM modifiers together
  if ($self->Is_Modifier('.TRIM', $lv_modifiers)) {
    #$fv_value =~ s/^[\n\t ]*//g;
    #$fv_value =~ s/ [\n\t ]*$//g;
    $fv_value = $U->trim($fv_value);

  #-- .LTRIM
  } elsif ($self->Is_Modifier('.LTRIM', $lv_modifiers)) {
    #$fv_value =~ s/^[\n\t ]*//g;
    $fv_value = $U->ltrim($fv_value);

  #-- .RTRIM
  } elsif ($self->Is_Modifier('.RTRIM', $lv_modifiers)) {
    #$fv_value =~ s/[\n\t ]*$//g;
    $fv_value = $U->rtrim($fv_value);

  }
  #--
  #-- .LENGTH
  if ($self->Is_Modifier('.LENGTH', $lv_modifiers)) {
    $fv_value = length($fv_value);

  }
  #-- .0
  if ($self->Is_Modifier('.0', $lv_modifiers)) {
    if ($fv_value eq "") {
      $fv_value = '0';
    }

  #-- .1
  } elsif ($self->Is_Modifier('.1', $lv_modifiers)) {
    if ($fv_value eq "") {
      $fv_value = '1';
    }

  #--
  #-- Check for Non-Breaking SPace directive - use &nbsp; instead of NULL
  #-- Check last to avoid other directives interfering
  #-- .NBSP
  } elsif ($self->Is_Modifier('.NBSP', $lv_modifiers)) {
    if ($fv_value eq "") {
      $fv_value = '&nbsp;';
      #-- leave immediately since no other operators make sense after this is set
      return $fv_value;
    }

  }
  #-----------------------------------------------------------------------------
  #-- Character SQL Modifiers
  #-- KR 7/28/02 - do the case conversions before .RAW and .NBSP so HTML escaped characters are not case converted
  #-----------------------------------------------------------------------------
  #-- Group case conversion operators together
  #-- .UPPER
  if ($self->Is_Modifier('.UPPER', $lv_modifiers)) {
    $fv_value =~ tr/[a-z]/[A-Z]/;

  #-- .LOWER
  } elsif ($self->Is_Modifier('.LOWER', $lv_modifiers)) {
    $fv_value =~ tr/[A-Z]/[a-z]/;

  #-- .INITCAP
  } elsif ($self->Is_Modifier('.INITCAP', $lv_modifiers)) {
    $fv_value = $U->initcap($fv_value);

  #-- .NAMECAP .INITNAME - special initcap for names (Shows III, IV, McName, etc.)
  } elsif ($self->Is_Modifier('.NAMECAP', $lv_modifiers)
        || $self->Is_Modifier('.INITNAME', $lv_modifiers)) {
    $fv_value = $U->InitName($fv_value);

  }
  #--
  #-- .HTML .RAW - replace & with &amp; and < with &lt; and > with &gt;
  #--        and # with &#035; and " with &quot;
  if ($self->Is_Modifier('.HTML', $lv_modifiers)
    ||$self->Is_Modifier('.RAW', $lv_modifiers)
    ) {
    #-- Make sure token value is not already in RAW format
    #-- - or else Token is already in raw format - keep existing value
    if ($self->Get_Token_Raw_Flag($fv_token) == 0) {
      $fv_value = $self->Get_Token_Raw($fv_token);
    }

  }
  #--
  #-- If the token ends in .TR, translate special HTML characters for Form Gets
  #--
  if ($self->Is_Modifier('.TR', $lv_modifiers)) {
    use Core::HTML;
    $fv_value = $U->Translate_HTML_Form_Get($fv_value);
  }
  #-- .NULL
  if ($self->Is_Modifier('.NULL', $lv_modifiers)) {
    if ($fv_value eq "") {
      $fv_value = 'NULL';
      #-- leave immediately since no other operators make sense after this is set
      return $fv_value;
    }
  }
  #-- .SIGN
  if ($self->Is_Modifier('.SIGN', $lv_modifiers)) {
    if ($fv_value < 0) {       $fv_value = '-1';
    } elsif ($fv_value > 0) {  $fv_value = '1';
    } elsif ($fv_value == 0) { $fv_value = '0';
    } else {                   $fv_value = '';
    }
  }

  #--
  #-- Most commonly used modifiers should appear at top so after they are processed, no others will be checked
  #--
  #-----------------------------------------------------------------------------
  #-- Character SQL Modifiers
  #-----------------------------------------------------------------------------
  #-- .EXISTS / .ISNOTNULL - Check for token value existance first
  if  ($self->Is_Modifier('.EXISTS', $lv_modifiers)
     ||$self->Is_Modifier('.ISNOTNULL', $lv_modifiers)
     ) {
    if ($fv_value ne "") {
      #-- value exists
      $fv_value = '1';
    } else {
      #-- value does not exist
      $fv_value = '0';
    }

  }
  #-- .NOTEXISTS / .ISNULL
  if  ($self->Is_Modifier('.NOTEXISTS', $lv_modifiers)
     ||$self->Is_Modifier('.ISNULL', $lv_modifiers)
     ) {
    if ($fv_value eq "") {
      #-- value does not exist
      $fv_value = '1';
    } else {
      #-- value does exist
      $fv_value = '0';
    }

  }
  #-- .ISNUMBER
  if ($self->Is_Modifier('.ISNUMBER', $lv_modifiers)) {
    if ($fv_value eq '') {
      $fv_value = '0';
    } else {
      $fv_value = $self->IsNumber($fv_value);
    }

  }
  #--
  #-- EVAL - Evaluate the contents of the token - return 1 if TRUE, 0 otherwise
  #--
  if ($self->Is_Modifier('.EVAL', $lv_modifiers)) {
    if ($self->Eval($fv_value)) {
      $fv_value = '1';
    } else {
      $fv_value = '0';
    }

  }
  #-- .ROWS - count the number of line breaks in the token
  if ($self->Is_Modifier('.ROWS', $lv_modifiers)) {
    use Orbit::Utils::Wrap;
    $fv_value = $self->Count_Rows($fv_value);

  }
  #-- .COLS - return the max number of columns between line breaks in the token
  if ($self->Is_Modifier('.COLS', $lv_modifiers)) {
    use Orbit::Utils::Wrap;
    $fv_value = $self->Count_Cols($fv_value);

  }
  #--
  #-- Check for .NOT last since it inverts previous settings
  #-- .NOT - switch sign 1 to 0 or 0 to 1
  #--
  if ($self->Is_Modifier('.NOT', $lv_modifiers)) {
    use Core::Math;
    $ln_arg_1 = $U->GetNumber($fv_value,1);
    if ( $ln_arg_1 eq ""
      && $fv_value eq ""
       ) {
      $fv_value = '';
    } elsif
       (  $ln_arg_1 eq ""
       && $fv_value ne ""
       && !($fv_value =~ /^Y$/i
          ||$fv_value =~ /^N$/i
          ||$fv_value =~ /^T$/i
          ||$fv_value =~ /^F$/i
          ||$fv_value =~ /^TRUE$/i
          ||$fv_value =~ /^FALSE$/i
          )
      ) {
      $fv_value = '';
    } elsif ($U->sign(abs($ln_arg_1)) == 0
          || $fv_value =~ /^N$/i
          || $fv_value =~ /^F$/i
          || $fv_value =~ /^FALSE$/i
          ) {
      $fv_value = '1';
    } else {
      #-- all positive or negative numbers will return 0
      $fv_value = '0';
    }

  }
  #--
  #-- .CHECKED - If value is -1, 1, Y, T, or TRUE set value to Checked
  #--          - If 0, N, F, FALSE or NULL set to NULL
  #--
  if ($self->Is_Modifier('.CHECKED', $lv_modifiers)) {
    # Evaluate the value for boolean
    $ln_numeric = $self->Eval($fv_value);
    if ($ln_numeric eq '1') {   # in ('-1','1','Y','T','TRUE'))
      $fv_value = 'CHECKED';
      #-- leave immediately since no other operators make sense after this is set
      return $fv_value;
    } elsif ($ln_numeric eq '0') {   # in ('0','N','F','FALSE'))
      $fv_value = '';
      #-- leave immediately since no other operators make sense after this is set
      return $fv_value;
    }

  }
  #--
  #-- .CHECKBOX - If value is -1, 1, Y, T, or TRUE set value to CHECK_ON token
  #--           - if 0, N, F, FALSE or NULL set to CHECK_OFF token
  #--
  if ($self->Is_Modifier('.CHECKBOX', $lv_modifiers)) {
    # Evaluate the value for boolean
    $ln_numeric = $self->Eval($fv_value);
    if ($ln_numeric eq '1') {   # in ('-1','1','Y','T','TRUE'))
      $fv_value = $self->Get_Token('CHECK_ON');
      #-- leave immediately since no other operators make sense after this is set
      return $fv_value;
    } elsif ($ln_numeric eq '0') {   # in ('0','N','F','FALSE'))
      $fv_value = $self->Get_Token('CHECK_OFF');
      #-- leave immediately since no other operators make sense after this is set
      return $fv_value;
    }

  }
  #-----------------------------------------------------------------------------
  #-- .CACHE : Set the token cache flag to 1 (MJ 12/02/2002)
  #--
  if ($self->Is_Modifier('.CACHE', $lv_modifiers)) {
    #-- Get all of the token record fields if we haven't already
    ($fv_value, $ln_raw_flag, $ln_cache_flag) = $self->Get_Token_Rec($fv_token);
    #-- Set the cache flag to 1 (if it isn't 1 already)
    if ($ln_cache_flag	 != 1) {
      $self->Set_Token($fv_token, $fv_value, $ln_raw_flag, 1);
    }
  }
  #-----------------------------------------------------------------------------
  #-- .UNCACHE : Set the token cache flag to 0 (MJ 12/04/2002)
  #--
  if ($self->Is_Modifier('.UNCACHE', $lv_modifiers)) {
    #-- Get all of the token record fields if we haven't already
    ($fv_value, $ln_raw_flag, $ln_cache_flag) = $self->Get_Token_Rec($fv_token);
    #-- Set the cache flag to 0 (if it isn't 0 already)
    if ($ln_cache_flag != 0) {
      $self->Set_Token($fv_token, $fv_value, $ln_raw_flag, 0);
    }
  }
  #--
  #-- Leave if the value eq "" since the remainder modifiers work on NOT NULL values
  #--
  if ($fv_value eq "") {
    return "";
  }
  #--
  #-- Set the numeric flag
  #--
  if ($self->IsNumber($fv_value,1)) {
    $ln_numeric = 1;
  } elsif ($fv_value ne "") {
    $ln_numeric = 0;
  } else {
    $ln_numeric = '';
  }
  #-----------------------------------------------------------------------------
  #-----------------------------------------------------------------------------
  #-----------------------------------------------------------------------------
  #--
  #-- Text only (non-numeric)
  #--
  if ($ln_numeric == 0) {
    #-----------------------------------------------------------------------------
    #-- HTML Specific Modifiers
    #-----------------------------------------------------------------------------
    #-- .NOTAGS - replace < with &lt; and > with &gt; and & with &amp;
    if ($self->Is_Modifier('.NOTAGS', $lv_modifiers)) {
      #$fv_value = replace(replace(replace($fv_value, '&', '&amp;'), '<', '&lt;'), '>', '&gt;');
      $fv_value =~ s/&/&amp;/g;
      $fv_value =~ s/</&lt;/g;
      $fv_value =~ s/>/&gt;/g;

    }
    #-- .NOPARSE - replace # with &#035;
    if ($self->Is_Modifier('.NOPARSE', $lv_modifiers)) {
      #$fv_value = replace($fv_value, '#', '&#035;');
      $fv_value =~ s/#/&#035;/g;

    }
#    #-- .ONEPARSE - replace # with chr(29) so resulting string will not be token parsed at all
#    #-- - used for counting number of characters without the HTML escaped values
#    if ($self->Is_Modifier('.ONEPARSE', $lv_modifiers)) {
#      $fv_value = replace($fv_value, '#', chr(29));
#
#    }
    #-- .NOQUOTE - replace " with &quot;
    if ($self->Is_Modifier('.NOQUOTE', $lv_modifiers)) {
      #$fv_value = replace($fv_value, '"', '&quot;');
      $fv_value =~ s/"/&quot;/ig;

    }
    #-- .UNTAG - replace (&amp; &lt; &gt;) with (& < >)
    if ($self->Is_Modifier('.UNTAG', $lv_modifiers)) {
      #$fv_value = replace(replace(replace($fv_value, '&amp;', '&'), '&lt;', '<'), '&gt;', '>');
      $fv_value =~ s/&amp;/&/ig;
      $fv_value =~ s/&lt;/</ig;
      $fv_value =~ s/&gt;/>/ig;

    }
    #-- .UNPARSE - replace &#035; with #
    if ($self->Is_Modifier('.UNPARSE', $lv_modifiers)) {
      #$fv_value = replace($fv_value, '&#035;', '#');
      $fv_value =~ s/&#035;/#/g;

    }
    #-- .UNRAW - replace (&amp; &lt; &gt; &#035; &quot;) with (& < > # ")
    if ($self->Is_Modifier('.UNRAW', $lv_modifiers)) {
      #$fv_value = replace(replace(replace(replace(replace($fv_value,
      #            '&amp;', '&'), '&lt;', '<'), '&gt;', '>'), '&#035;', '#'), '&quot;', '"');
      $fv_value =~ s/&amp;/&/ig;
      $fv_value =~ s/&lt;/</ig;
      $fv_value =~ s/&gt;/>/ig;
      $fv_value =~ s/&#035;/#/ig;
      $fv_value =~ s/&quot;/"/ig;
    }
    #-- .NOHTML - remove HTML tags from the token value, including & escaped
    if ($self->Is_Modifier('.NOHTML', $lv_modifiers)) {
      #$fv_value = replace(replace(replace(replace(replace(replace($fv_value,
      #            '&amp;', '&'), '&lt;', '<'), '&gt;', '>'), '&nbsp;', ' '), '&quot;', '"'), '<BR>', "\n");
      $fv_value =~ s/&amp;/&/ig;
      $fv_value =~ s/&lt;/</ig;
      $fv_value =~ s/&gt;/>/ig;
      $fv_value =~ s/&nbsp;/ /ig;
      $fv_value =~ s/&quot;/"/ig;
      $fv_value =~ s/<br>/\n/ig;
      $fv_value = $self->Strip_Text($fv_value, '<', '>', '', 1, 0);
          #  $fv_text                        => $fv_value
          # ,$fv_begin_text                  => '<'
          # ,$fv_end_text                    => '>'
          # ,$fn_match_pairs                 => 1
          # );
    }
#    #-- .RAW2 - replace < with &lt; and > with &gt; and # with &#035;
#    if ($self->Is_Modifier('.RAW2', $lv_modifiers)) {
#      #-- Make sure token value is not already in RAW format (from the query flag)
#      if NVL($ln_raw_flag, 0) = 0) {
#        $U->Get_Raw_Text2($fv_value);
#      }
#
#    }
#    #-- .QUOTE - replace single quotes ' with two single quotes ''
#    if ($self->Is_Modifier('.QUOTE', $lv_modifiers)) {
#      $fv_value = replace($fv_value, '''', '''''');
#
#    }
    #-- .JSQUOTE - replace single quotes ' and double quotes " \' and \" respectively
    #-- KR 2/3/02 - replace carriage returns with \r
    if ($self->Is_Modifier('.JSQUOTE', $lv_modifiers)) {
      #$fv_value = replace(replace(replace(replace(replace($fv_value, '''', '\'''), '"', '\"')
      #                   ,CHR(13)||"\n", '\r'), CHR(13), '\r'), "\n", '\r');
      #
      $fv_value =~ s/'/\\'/g;
      $fv_value =~ s/"/\\"/g;
      $fv_value =~ s/\n/\\r/g;

    }
    #-- .BR - use <BR> instead of "\n"
    if ($self->Is_Modifier('.BR', $lv_modifiers)) {
      $fv_value =~ s/\n/<br>/g;

    }
    #-- .NOWRAP - change all spaces to &nbsp;
    if ($self->Is_Modifier('.NOWRAP', $lv_modifiers)) {
      #$fv_value = replace($fv_value,' ','&nbsp;');
      $fv_value =~ s/ /&nbsp;/g;
    }

  } # Text Only / Non-numeric

  #-- .OML<token> - OML (Orbit Markup Language) User Defined Modifier
  #-- Prefixed with OML. #OML<token># must be defined prior to use. Reference token value as #OML#
  #-- ie #OMLRED=[<font color="red">#OML#</font>]#
  #--    #tok.OMLRed#
  if ($self->Is_Modifier('.OML', $lv_modifiers, 1)) {
    # Check for multiple OML User Defined Modifiers
    my $omlToken="";
    my $pOML=-1;
    # Loop through all the OML modifiers
    while (1)
    {
      $omlToken = $lv_modifiers;
      $pOML = index($lv_modifiers, '.OML');
      last if ($pOML == -1);

      $omlToken = substr($lv_modifiers, $pOML+1, index($lv_modifiers, '.', $pOML+1)-$pOML-1);

      # Leave when all OML Modifiers processed
      last if ($omlToken eq "");
      # See if omlToken is defined
      if ($self->Get_Token($omlToken) ne "") {
        $self->Set_Token('OML', $fv_value);
        $fv_value = $self->Parse($self->Get_Token($omlToken), 0);
      }
      # Remove the OML token modifier from the modifiers
      $lv_modifiers =~ s/\.$omlToken//;
    } #while
  }

  #-- .EARTHIFY - change all words in the text to link to .earth or .earth.love pages
  if ($self->Is_Modifier('.EARTHIFY', $lv_modifiers)
    ||$self->Is_Modifier('.EARTH', $lv_modifiers)
    ) {
    # More to come
    $fv_value = $fv_value;
  }

  #-- .LOVE - Return 'Love' if the value is TRUE
  if ($self->Is_Modifier('.LOVE', $lv_modifiers)) {
    # Return 'Love' if the value is TRUE
    $fv_value = 'Love' if ($self->Eval($fv_value));
  }

  #-----------------------------------------------------------------------------
  #-- Numeric Modifiers
  #-----------------------------------------------------------------------------
  #--
  #-- NUMERIC
  #--
  if ($ln_numeric == 1) {
    #-- .ROUND
    if ($self->Is_Modifier('.ROUND', $lv_modifiers)) {
      use Core::Math::Round;
      $lv_value = $U->round($fv_value, 0);
      #-- only overwrite the value if the conversion was successful
      if ($fv_value ne "" && $lv_value ne "") {
        $fv_value = $lv_value;
      }

    }
    #-- .ROUND2
    if ($self->Is_Modifier('.ROUND2', $lv_modifiers)) {
      use Core::Math::Round;
      $lv_value = $U->round($fv_value, 2);
      #-- only overwrite the value if the conversion was successful
      if ($fv_value ne "" && $lv_value ne "") {
        $fv_value = $lv_value;
      }

    }
    #-- .ROUND1
    if ($self->Is_Modifier('.ROUND1', $lv_modifiers)) {
      use Core::Math::Round;
      $lv_value = $U->round($fv_value, 1);
      #-- only overwrite the value if the conversion was successful
      if ($fv_value ne "" && $lv_value ne "") {
        $fv_value = $lv_value;
      }

    }
    #-- .TRUNC
    if ($self->Is_Modifier('.TRUNC', $lv_modifiers)) {
      use Core::Math::Round;
      $lv_value = $U->trunc($fv_value);
      #-- only overwrite the value if the conversion was successful
      if ($fv_value ne "" && $lv_value ne "") {
        $fv_value = $lv_value;
      }

    }
    #-- .ABS
    if ($self->Is_Modifier('.ABS', $lv_modifiers)) {
      $fv_value = abs($fv_value);

    }
    #-- .CEIL
    if ($self->Is_Modifier('.CEIL', $lv_modifiers)) {
      use Core::Math::Ceil;
      $fv_value = $U->ceil($fv_value);

    }
    #-- .FLOOR
    if ($self->Is_Modifier('.FLOOR', $lv_modifiers)) {
      use Core::Math::Ceil;
      $fv_value = $U->floor($fv_value);

    }
    #-- .PERCENT - change contents to a percentage
    if ($self->Is_Modifier('.PERCENT', $lv_modifiers)) {
      use Core::Math::Round;
      #-- round to at most 4 decimal places
      $lv_value = $U->round($fv_value*100);
      if ($lv_value ne "") {
        $lv_value = $lv_value.'%';
      }
      #-- only overwrite the value if the conversion was successful
      if ($fv_value ne "" && $lv_value ne "") {
        $fv_value = $lv_value;
      }
    }
    #-- .PERCENT1 - change contents to a percentage
    if ($self->Is_Modifier('.PERCENT1', $lv_modifiers)) {
      use Core::Math::Round;
      #-- round to at most 4 decimal places
      $lv_value = $U->round($fv_value*100, 1);
      if ($lv_value ne "") {
        $lv_value = $lv_value.'%';
      }
      #-- only overwrite the value if the conversion was successful
      if ($fv_value ne "" && $lv_value ne "") {
        $fv_value = $lv_value;
      }
    }
    #-- .PERCENT2 - change contents to a percentage
    if ($self->Is_Modifier('.PERCENT2', $lv_modifiers)) {
      use Core::Math::Round;
      #-- round to at most 4 decimal places
      $lv_value = $U->round($fv_value*100, 2);
      if ($lv_value ne "") {
        $lv_value = $lv_value.'%';
      }
      #-- only overwrite the value if the conversion was successful
      if ($fv_value ne "" && $lv_value ne "") {
        $fv_value = $lv_value;
      }
    }
  }

  #-----------------------------------------------------------------------------
  #-- END Check token modifiers
  #-----------------------------------------------------------------------------

  #
  # Return the modified value of the Token
  #
  return $fv_value;
} #Process_Modifiers

################################################################################
#
# Token Modifiers
#
################################################################################


#******************************************************************************************
#*  Function Name   :   Check_Token_Modifier
#*
#*  Scope           :   PUBLIC
#*
#*  Description     :   Sets fb_found to TRUE if the specified modifier was found in
#*                      the token, and also removes the modifier from the token
#*                      Returns TRUE if more '.' periods are found in the string, so additional
#*                      checks don't need to be done after the most common modifiers are processed
#******************************************************************************************
sub Orbit::Check_Token_Modifier
  #          fv_token                       IN OUT NOCOPY VARCHAR2
  #         ,fv_directive                   IN     VARCHAR2
  #         ,fb_token_found                    OUT BOOLEAN
  #         ) RETURN BOOLEAN;
{
  my ( $self, $Token, $Directive, $Found ) = @_;

  return "CODE";
} #Check_Token_Modifier


#******************************************************************************************
#*  Function Name   :   Is_Modifier
#*  Description     :   Returns TRUE if the specified directive was found, and removes the modifier from the token
#*                      Raises except_NO_MORE_MODIFIERS if no more '.' periods are found in the string, so additional
#*                      checks don't need to be done after the most common modifiers are processed
#*                      bWildcard searches for partial OML Modifier (supporting .OML)
#******************************************************************************************
sub Orbit::Is_Modifier
{
  my ( $self, $fv_directive, $lv_modifiers, $bWildcard ) = @_;
  my $U = $self->{_Utils};

  return 0 if (!defined($lv_modifiers));
  $bWildcard = 0 if (!defined($bWildcard) || $bWildcard ne "1");

  #-- search for anywhere in the token, but not part of another string
  if ($bWildcard == 0 && index($lv_modifiers, $fv_directive.'.') == -1) {   # search for all inclusive modifier
    return 0;
  } elsif ($bWildcard == 1 && index($lv_modifiers, $fv_directive) == -1) {   # search without trailing .
    return 0;
  } else {
    $self->AddStat("_Token Modifiers") if ($self->GetLogStat());
    # Only log Specific Modifiers on LogStat > 1
    $self->AddStat("Token Modifier: ".$fv_directive) if ($self->GetLogStat() > 1);
    return 1;
  }
} #Is_Modifier;


################################################################################
# END Token Modifiers
################################################################################


#========================================================================================
# END TOKEN SUBROUTINES
#========================================================================================

#******************************************************************************************
# Return true to show package was loaded with
# use Orbit::OML6::Token6;
#******************************************************************************************
1;


#END Orbit::OML6::Token6 Package
