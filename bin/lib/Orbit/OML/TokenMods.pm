#!/usr/bin/perl
# Version 7.0.0.0       7-Jul-2021
#*****************************************************************************************
#*
#* Orbit::OML::TokenMods - Version 7
#*
#* Implements Orbit Markup Language (OML) for Token Modifiers
#*
#*****************************************************************************************
# History:
#   2021.07.07 earth.love oK Touchup prior to release
#   2021.06.25 earth.love oK Version 7 additions - direct OML function call
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
# Functions Supportted:
#*****************************************
#
# ProcessTokenModifiers
#   - Processes the Token Modifiers appended to a token.  Sets the new value in lv_value.
#   - Returns TRUE if processed successfully, FALSE if an unknown modifier
#
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
#* ProcessTokenModifiers
#*
#* - Processes the Token Modifiers appended to a token.  Sets the new value in lv_value.
#* - Returns TRUE if processed successfully, FALSE if an unknown modifier
#******************************************************************************************
sub Orbit::ProcessTokenModifiers
{
  my( $self, $Token ) = @_;

  my $V = "";   # Return Value
  my $Period = 0;
  my $Mods = "";
  #-- Define a time field for the .TIME modifier   # TESTING
  #my $li_end_time = 0;   #TESTING - ADD THE .TIMER MODIFIER

  # leave if no token
  return "" if ($Token eq "");

  # Add Token Statistic if turned on
  $self->AddStat("_Tokens Parsed") if ($self->GetLogStat());

  #--
  #-- check for '.' for performance since most tokens will NOT have a modifier directive
  #--
  $Period = index($Token, '.');
  if ($Period == -1) {
    #-- No modifiers found, so process and leave
    #-- Get the value of the token
    $V = $self->Get_Token($Token);
    return $V;
  }
  #-- Get the modifiers only in LOWER case
  $Mods = substr($Token,$Period+1);
  $Mods =~ tr/[A-Z]/[a-z]/;

  #-- Get the Token Name
  $Token = substr($Token,0,$Period);
  $self->{_Token} = $Token;
  #-- Get the value of the token
  $V = $self->Get_Token($Token);
  $self->{_TokVal} = $V;

  #
  # Look for the Token Mods in Left to Right order and call the dynamic function
  #
  my @MODS = split(/\./, $Mods);
  my $FunSub = '';
  my $bFound = 0;
  foreach my $mod (@MODS) {
    next if ($mod eq "");   # Avoid ... but allow it

    #
    # User dynamic OML Modifiers
    # ie  #omlBOLD=[<b>#OML#</b>]#   ->   #token.omlBOLD#
    #
    # Pass the specific modifier called to the dynamic subroutine
    $self->{_Modifier} = $mod;
    # Special case for "quick" oml modifiers with the .OML modifier
    $mod = 'oml' if ($mod =~ /^OML.*/i);
    #
    # Make sure the modifier is defined
    # - the function reference should be loaded
    #   in the corresponding Function Group
    #   NOTE: Function Group 0 contains the Base OML Functionality,
    #         including the Token Modifiers included within.
    #
    if (defined($self->{_TOKEN_MODIFIERS}->{$mod})) {
      $bFound = 1;

      #
      # Add the modifier statistics if turned on
      #
      $self->AddStat("_Token Modifiers") if ($self->GetLogStat());
      # Only log Specific Modifiers on LogStat > 1
      $self->AddStat("_Token Modifier: ".$mod) if ($self->GetLogStat() > 1);

      #
      # Get the OML Function Subroutine Reference and Execute
      #
      $FunSub = $self->{_TOKEN_MODIFIERS}->{$mod};

      #
      # Dynamically run the subroutine
      # - each Token Modifier modifies TokVal directly and we get it at the end
      #
      { $FunSub->(), 0 };

    } else {
      # Modifier not defined
      $self->AppendError("Token Modifier [.$mod] not found!");
    }
  } #foreach
  # Be Free mods
  undef @MODS;
  
  #
  # Get it at the end, it being TokVal,
  # the response back from the "magic"
  # routine that just ran above
  $V = $self->{_TokVal} if ($bFound);
  
  #
  # Reset Dynamic Parameter Buffers
  # - Was never here!
  #
  $self->{_Token}    = '';
  $self->{_TokVal}   = '';
  $self->{_Modifier} = '';

  #
  # Return the modified value of the Token
  #
  return $V;
} #ProcessTokenModifiers

################################################################################
#
# Token Modifiers
#
################################################################################


#-- .RESTORE
#-- Restore the Backup value TOKEN_BACK to the TOKEN name, keeping the backup token.
#-- This is processed after .backup before any other modifiers.
#-- TOKEN is restored from TOKEN_BACK
sub Orbit::modRESTORE {
  my ( $O ) = @_;
  # Restore the token; no change to fv_value
  $O->Set_Token($O->{_Token}, $O->Get_Token($O->{_Token}.$O->{_BackupExt}));
}

#-- Put SPACE, TRIMS before LENGTH so length can work on resultant string
#--

#-- .SPACE
#-- Convert tabs to spaces, and multiple spaces to 1 space (don't trim)
sub Orbit::modSPACE {
  my ( $O ) = @_;
  $O->{_TokVal} =~ s/\t/ /g;
  $O->{_TokVal} =~ s/ [ ]*/ /g;
}

#-- .TRIM
#-- Group TRIM modifiers together
sub Orbit::modTRIM {
  my ( $O ) = @_;
  my $U = $O->{_Utils};
  $O->{_TokVal} = $U->trim($O->{_TokVal});
}

#-- .LTRIM
sub Orbit::modLTRIM {
  my ( $O ) = @_;
  my $U = $O->{_Utils};
  $O->{_TokVal} = $U->ltrim($O->{_TokVal});
}

#-- .RTRIM
sub Orbit::modRTRIM {
  my ( $O ) = @_;
  my $U = $O->{_Utils};
  $O->{_TokVal} = $U->rtrim($O->{_TokVal});
}

#--
#-- .LENGTH
sub Orbit::modLENGTH {
  my ( $O ) = @_;
  $O->{_TokVal} = length($O->{_TokVal});
}

#-- .0
sub Orbit::mod0 {
  my ( $O ) = @_;
  $O->{_TokVal} = '0' if ($O->{_TokVal} eq "");
}

#-- .1
sub Orbit::mod1 {
  my ( $O ) = @_;
  $O->{_TokVal} = '1' if ($O->{_TokVal} eq "");
}

#--
#-- Check for Non-Breaking SPace directive - use &nbsp; instead of NULL
#-- Check last to avoid other directives interfering
#-- .NBSP
sub Orbit::modNBSP {
  my ( $O ) = @_;
  $O->{_TokVal} = '&nbsp;' if ($O->{_TokVal} eq "");
}

#-----------------------------------------------------------------------------
#-- Character SQL Modifiers
#-- KR 7/28/02 - do the case conversions before .RAW and .NBSP so HTML escaped characters are not case converted
#-----------------------------------------------------------------------------

#-- Group case conversion operators together

#-- .UPPER
sub Orbit::modUPPER {
  my ( $O ) = @_;
  $O->{_TokVal} =~ tr/[a-z]/[A-Z]/;
}

#-- .LOWER
sub Orbit::modLOWER {
  my ( $O ) = @_;
  $O->{_TokVal} =~ tr/[A-Z]/[a-z]/;
}

#-- .INITCAP
sub Orbit::modINITCAP {
  my ( $O ) = @_;
  my $U = $O->{_Utils};
  $O->{_TokVal} = $U->initcap($O->{_TokVal});
}

#-- .NAMECAP .INITNAME - special initcap for names (Shows III, IV, McName, etc.)
sub Orbit::modINITNAME {
  my ( $O ) = @_;
  my $U = $O->{_Utils};
  $O->{_TokVal} = $U->InitName($O->{_TokVal});
}

#--
#-- .HTML .RAW - replace & with &amp; and < with &lt; and > with &gt;
#--        and # with &#035; and " with &quot;
sub Orbit::modHTML {
  my ( $O ) = @_;
  #-- Make sure token value is not already in RAW format
  #-- - or else Token is already in raw format - keep existing value
  if ($O->GetTokenRawFlag($O->{_Token}) == 0) {
    $O->{_TokVal} = $O->GetTokenRaw($O->{_Token});
  }
}

#--
#-- If the token ends in .TR, translate special HTML characters for Form Gets
#--
sub Orbit::modTR {
  my ( $O ) = @_;
  use Core::HTML;
  my $U = $O->{_Utils};
  $O->{_TokVal} = $U->Translate_HTML_Form_Get($O->{_TokVal});
}

#-- .NULL
sub Orbit::modNULL {
  my ( $O ) = @_;
  if ($O->{_TokVal} eq "") {
    $O->{_TokVal} = 'NULL';
  }
}

#-- .SIGN
sub Orbit::modSIGN {
  my ( $O ) = @_;
  if      ($O->{_TokVal} < 0)  { $O->{_TokVal} = '-1';
  } elsif ($O->{_TokVal} > 0)  { $O->{_TokVal} = '1';
  } elsif ($O->{_TokVal} == 0) { $O->{_TokVal} = '0';
  } else {                       $O->{_TokVal} = '';
  }
}

#--
#-- Most commonly used modifiers should appear at top so after they are processed, no others will be checked
#--
#-----------------------------------------------------------------------------
#-- Character SQL Modifiers
#-----------------------------------------------------------------------------
#-- .EXISTS / .ISNOTNULL - Check for token value existance first
sub Orbit::modEXISTS {
  my ( $O ) = @_;
  if ($O->{_TokVal} ne "") {
    #-- value exists
    $O->{_TokVal} = '1';
  } else {
    #-- value does not exist
    $O->{_TokVal} = '0';
  }
}

#-- .NOTEXISTS / .ISNULL
sub Orbit::modNOTEXISTS {
  my ( $O ) = @_;
  if ($O->{_TokVal} eq "") {
    #-- value does not exist
    $O->{_TokVal} = '1';
  } else {
    #-- value does exist
    $O->{_TokVal} = '0';
  }
}

#-- .ISNUMBER
sub Orbit::modISNUMBER {
  my ( $O ) = @_;
  if ($O->{_TokVal} eq '') {
    $O->{_TokVal} = '0';
  } else {
    $O->{_TokVal} = $O->IsNumber($O->{_TokVal});
  }
}

#--
#-- EVAL - Evaluate the contents of the token - return 1 if TRUE, 0 otherwise
#--
sub Orbit::modEVAL {
  my ( $O ) = @_;
  if ($O->Eval($O->{_TokVal})) {
    $O->{_TokVal} = '1';
  } else {
    $O->{_TokVal} = '0';
  }
}

#-- .ROWS - count the number of line breaks in the token
sub Orbit::modROWS {
  my ( $O ) = @_;
  use Orbit::Utils::Wrap;
  my $U = $O->{_Utils};
  $O->{_TokVal} = $O->Count_Rows($O->{_TokVal});
}

#-- .COLS - return the max number of columns between line breaks in the token
sub Orbit::modCOLS {
  my ( $O ) = @_;
  use Orbit::Utils::Wrap;
  my $U = $O->{_Utils};
  $O->{_TokVal} = $O->Count_Cols($O->{_TokVal});
}

#--
#-- Check for .NOT last since it inverts previous settings
#-- .NOT - switch sign 1 to 0 or 0 to 1
#--
sub Orbit::modNOT {
  my ( $O ) = @_;
  use Core::Math;
  my $U = $O->{_Utils};
  my $num = $U->GetNumber($O->{_TokVal},1);
  if ( $num eq ""
    && $O->{_TokVal} eq ""
     ) {
    $O->{_TokVal} = '';
  } elsif
       (  $num eq ""
       && $O->{_TokVal} ne ""
       && !($O->{_TokVal} =~ /^Y$/i
          ||$O->{_TokVal} =~ /^N$/i
          ||$O->{_TokVal} =~ /^T$/i
          ||$O->{_TokVal} =~ /^F$/i
          ||$O->{_TokVal} =~ /^TRUE$/i
          ||$O->{_TokVal} =~ /^FALSE$/i
          )
      ) {
    $O->{_TokVal} = '';
  } elsif ($U->sign(abs($num)) == 0
          || $O->{_TokVal} =~ /^N$/i
          || $O->{_TokVal} =~ /^F$/i
          || $O->{_TokVal} =~ /^FALSE$/i
          ) {
    $O->{_TokVal} = '1';
  } else {
    #-- all positive or negative numbers will return 0
    $O->{_TokVal} = '0';
  }
}

#--
#-- .CHECKED - If value is -1, 1, Y, T, or TRUE set value to Checked
#--          - If 0, N, F, FALSE or NULL set to NULL
#--
sub Orbit::modCHECKED {
  my ( $O ) = @_;
  # Evaluate the value for boolean
  my $eval = $O->Eval($O->{_TokVal});
  if ($eval eq '1') {   # in ('-1','1','Y','T','TRUE'))
    $O->{_TokVal} = 'CHECKED';
  } elsif ($eval eq '0') {   # in ('0','N','F','FALSE'))
    $O->{_TokVal} = '';
  }
}

#--
#-- .CHECKBOX - If value is -1, 1, Y, T, or TRUE set value to CHECK_ON token
#--           - if 0, N, F, FALSE or NULL set to CHECK_OFF token
#--
sub Orbit::modCHECKBOX {
  my ( $O ) = @_;
  # Evaluate the value for boolean
  my $eval = $O->Eval($O->{_TokVal});
  if ($eval eq '1') {   # in ('-1','1','Y','T','TRUE'))
    $O->{_TokVal} = $O->Get_Token('CHECK_ON');
  } elsif ($eval eq '0') {   # in ('0','N','F','FALSE'))
    $O->{_TokVal} = $O->Get_Token('CHECK_OFF');
  }
}

#-----------------------------------------------------------------------------
#-- .CACHE : Set the token cache flag to 1 (MJ 12/02/2002)
#--
sub Orbit::modCACHE {
  my ( $O ) = @_;
  my $bRaw=0;
  my $bCache=0;
  #-- Get all of the token record fields if we haven't already
  ($O->{_TokVal}, $bRaw, $bCache) = $O->GetTokenRec($O->{_Token});
  #-- Set the cache flag to 1 (if it isn't 1 already)
  if ($bCache	 != 1) {
    $O->Set_Token($O->{_Token}, $O->{_TokVal}, $bRaw, 1);
  }
}

#-----------------------------------------------------------------------------
#-- .UNCACHE : Set the token cache flag to 0 (MJ 12/04/2002)
#--
sub Orbit::modUNCACHE {
  my ( $O ) = @_;
  my $bRaw=0;
  my $bCache=0;
  #-- Get all of the token record fields if we haven't already
  ($O->{_TokVal}, $bRaw, $bCache) = $O->GetTokenRec($O->{_Token});
  #-- Set the cache flag to 0 (if it isn't 0 already)
  if ($bCache != 0) {
    $O->Set_Token($O->{_Token}, $O->{_TokVal}, $bRaw, 0);
  }
}

#--
#-- Text only (non-numeric)
#--

#-----------------------------------------------------------------------------
#-- HTML Specific Modifiers
#-----------------------------------------------------------------------------
#-- .NOTAGS - replace < with &lt; and > with &gt; and & with &amp;
sub Orbit::modNOTAGS {
  my ( $O ) = @_;
  $O->{_TokVal} =~ s/&/&amp;/g;
  $O->{_TokVal} =~ s/</&lt;/g;
  $O->{_TokVal} =~ s/>/&gt;/g;
}

#-- .NOPARSE - replace # with &#035;
sub Orbit::modNOPARSE {
  my ( $O ) = @_;
  $O->{_TokVal} =~ s/#/&#035;/g;
}

#-- .NOQUOTE - replace " with &quot;
sub Orbit::modNOQUOTE {
  my ( $O ) = @_;
  $O->{_TokVal} =~ s/"/&quot;/ig;   # Syntax "
}

#-- .UNTAG - replace (&amp; &lt; &gt;) with (& < >)
sub Orbit::modUNTAG {
  my ( $O ) = @_;
  $O->{_TokVal} =~ s/&amp;/&/ig;
  $O->{_TokVal} =~ s/&lt;/</ig;
  $O->{_TokVal} =~ s/&gt;/>/ig;
}

#-- .UNPARSE - replace &#035; with #
sub Orbit::modUNPARSE {
  my ( $O ) = @_;
  $O->{_TokVal} =~ s/&#035;/#/g;
}

#-- .UNRAW - replace (&amp; &lt; &gt; &#035; &quot;) with (& < > # ")
sub Orbit::modUNRAW {
  my ( $O ) = @_;
  $O->{_TokVal} =~ s/&amp;/&/ig;
  $O->{_TokVal} =~ s/&lt;/</ig;
  $O->{_TokVal} =~ s/&gt;/>/ig;
  $O->{_TokVal} =~ s/&#035;/#/ig;
  $O->{_TokVal} =~ s/&quot;/"/ig;   # Syntax "
}

#-- .NOHTML - remove HTML tags from the token value, including & escaped
sub Orbit::modNOHTML {
  my ( $O ) = @_;
  $O->{_TokVal} =~ s/&amp;/&/ig;
  $O->{_TokVal} =~ s/&lt;/</ig;
  $O->{_TokVal} =~ s/&gt;/>/ig;
  $O->{_TokVal} =~ s/&nbsp;/ /ig;
  $O->{_TokVal} =~ s/&quot;/"/ig;   #Syntax "
  $O->{_TokVal} =~ s/<br>/\n/ig;
  $O->{_TokVal} = $O->StripText($O->{_TokVal}, '<', '>', '', 1, 0);
}

#-- .JSQUOTE - replace single quotes ' and double quotes " \' and \" respectively
#-- KR 2/3/02 - replace carriage returns with \r
sub Orbit::modJSQUOTE {
  my ( $O ) = @_;
  $O->{_TokVal} =~ s/'/\\'/g;
  $O->{_TokVal} =~ s/"/\\"/g;
  $O->{_TokVal} =~ s/\n/\\r/g;
}

#-- .BR - use <BR> instead of "\n"
sub Orbit::modBR {
  my ( $O ) = @_;
  $O->{_TokVal} =~ s/\n/<br>/g;
}

#-- .NOWRAP - change all spaces to &nbsp;
sub Orbit::modNOWRAP {
  my ( $O ) = @_;
  $O->{_TokVal} =~ s/ /&nbsp;/g;
}


#-----------------------------------------------------------------------------
#-- Numeric Modifiers
#-----------------------------------------------------------------------------

#-- .ROUND
sub Orbit::modROUND {
  my ( $O ) = @_;
  use Core::Math::Round;
  my $U = $O->{_Utils};
  my $lValue = $U->round($O->{_TokVal}, 0);
  #-- only overwrite the value if the conversion was successful
  if ($O->{_TokVal} ne "" && $lValue ne "") {
    $O->{_TokVal} = $lValue;
  }
}

#-- .ROUND2
sub Orbit::modROUND2 {
  my ( $O ) = @_;
  use Core::Math::Round;
  my $U = $O->{_Utils};
  my $lValue = $U->round($O->{_TokVal}, 2);
  #-- only overwrite the value if the conversion was successful
  if ($O->{_TokVal} ne "" && $lValue ne "") {
    $O->{_TokVal} = $lValue;
  }
}

#-- .ROUND1
sub Orbit::modROUND1 {
  my ( $O ) = @_;
  use Core::Math::Round;
  my $U = $O->{_Utils};
  my $lValue = $U->round($O->{_TokVal}, 1);
  #-- only overwrite the value if the conversion was successful
  if ($O->{_TokVal} ne "" && $lValue ne "") {
    $O->{_TokVal} = $lValue;
  }
}

#-- .TRUNC
sub Orbit::modTRUNC {
  my ( $O ) = @_;
  use Core::Math::Round;
  my $U = $O->{_Utils};
  my $lValue = $U->trunc($O->{_TokVal});
  #-- only overwrite the value if the conversion was successful
  if ($O->{_TokVal} ne "" && $lValue ne "") {
    $O->{_TokVal} = $lValue;
  }
}

#-- .ABS
sub Orbit::modABS {
  my ( $O ) = @_;
  $O->{_TokVal} = abs($O->{_TokVal}) if ($O->IsNumber($O->{_TokVal}));
}

#-- .CEIL
sub Orbit::modCEIL {
  my ( $O ) = @_;
  use Core::Math::Ceil;
  my $U = $O->{_Utils};
  $O->{_TokVal} = $U->ceil($O->{_TokVal});
}

#-- .FLOOR
sub Orbit::modFLOOR {
  my ( $O ) = @_;
  use Core::Math::Ceil;
  my $U = $O->{_Utils};
  $O->{_TokVal} = $U->floor($O->{_TokVal});
}

#-- .PERCENT - change contents to a percentage
sub Orbit::modPERCENT {
  my ( $O ) = @_;
  use Core::Math::Round;
  #-- round to 0 decimal places
  my $num = $O->{_TokVal};
  my $U = $O->{_Utils};
  my $lValue = $U->round($num*100);
  $lValue = $lValue.'%' if ($lValue ne "");
  #-- only overwrite the value if the conversion was successful
  if ($O->{_TokVal} ne "" && $lValue ne "") {
    $O->{_TokVal} = $lValue;
  }
}

#-- .PERCENT1 - change contents to a percentage
sub Orbit::modPERCENT1 {
  my ( $O ) = @_;
  use Core::Math::Round;
  #-- round to at most 1 decimal place
  my $num = $O->{_TokVal};
  my $U = $O->{_Utils};
  my $lValue = $U->round($num*100, 1);
  $lValue = $lValue.'%' if ($lValue ne "");
  #-- only overwrite the value if the conversion was successful
  if ($O->{_TokVal} ne "" && $lValue ne "") {
    $O->{_TokVal} = $lValue;
  }
}

#-- .PERCENT2 - change contents to a percentage
sub Orbit::modPERCENT2 {
  my ( $O ) = @_;
  use Core::Math::Round;
  my $num = $O->{_TokVal};
  #-- round to at most 2 decimal places
  my $U = $O->{_Utils};
  my $lValue = $U->round($num*100, 2);
  $lValue = $lValue.'%' if ($lValue ne "");
  #-- only overwrite the value if the conversion was successful
  if ($O->{_TokVal} ne "" && $lValue ne "") {
    $O->{_TokVal} = $lValue;
  }
}

#-----------------------------------------------------------------------------
#-- .OML<token> - OML (Orbit Markup Language) User Defined Modifier
#-- Prefixed with OML. #OML<token># must be defined prior to use. Reference token value as #OML#
#-- ie #OMLRED=[<font color="red">#OML#</font>]#
#--    #tok.OMLRed#   #token.omlRED#
#-----------------------------------------------------------------------------
sub Orbit::modOML {
  my ( $O ) = @_;
  my $omlToken = $O->{_Modifier};
  
  #
  # Get the OML Function from the token modifier name
  #
  my $omlFunction = $O->GetToken($omlToken);
  
  #
  # See if omlToken is defined
  #
  if ($omlFunction ne "") {
    #
    # Set the value of the token we're working with in the #OML# Token
    #
    $O->Set_Token('OML', $O->{_TokVal});
    
    #
    # Parse the Token Function, replacing out OML with the value of our token
    #
    $O->{_TokVal} = $O->Parse($omlFunction, 0);
  }
} #modOML


#-----------------------------------------------------------------------------

#-- .EARTHIFY - change all words in the text to link to .earth or .earth.love pages
sub Orbit::modEARTHIFY {
  my ( $O ) = @_;
  # More to come
  $O->{_TokVal} = $O->{_TokVal};
}

#-- .LOVE - Return 'Love' if the value is TRUE
sub Orbit::modLOVE {
  my ( $O ) = @_;
  # Return 'Love' if the value is TRUE
  $O->{_TokVal} = 'Love' if ($O->Eval($O->{_TokVal}));
}


################################################################################
# END Token Modifiers
################################################################################


#========================================================================================
# END TOKEN SUBROUTINES
#========================================================================================

#******************************************************************************************
# Return true to show package was loaded with
# use Orbit::OML::TokenMods;
#******************************************************************************************
1;


#END Orbit::OML::TokenMods Package
