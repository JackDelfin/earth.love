#!/usr/bin/perl
# Version 7.0.0.0      17-Jun-2021
#*****************************************************************************************
#*
#* Orbit::OML::Function::HTML - Version 7
#*
#*  Package Name    :   Orbit::OML:Function::HTML
#*
#*  Description     :   Implements Orbit Markup Language (OML) for HTML Functions
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
# LoadHTMLFunctions
#   - Load the HTML OML Functions into the _OML_FUNCTIONS subroutine reference array
#
# SELECTED
# OPTIONS
# JSQUOTE
# MSGHELP
# HELP
# HELPOVER
#*****************************************************************************************
package Orbit;   # Continuation of Orbit package

use strict;
use warnings;
use utf8;
use feature ':5.16';


#-----------------------------------------------------------------------------
# LoadHTMLFunctions
#   - Load the HTML OML Functions into the _OML_FUNCTIONS subroutine reference array
#
sub Orbit::LoadHTMLFunctions
{
  my ( $O ) = @_;
  $O->{_OML_FUNCTIONS}->{'SELECTED'}    = sub { $O->omlSELECTED(), };
  $O->{_OML_FUNCTIONS}->{'OPTIONS'}     = sub { $O->omlOPTIONS(), };
  $O->{_OML_FUNCTIONS}->{'JSQUOTE'}     = sub { $O->omlJSQUOTE(), };
  $O->{_OML_FUNCTIONS}->{'MSGHELP'}     = sub { $O->omlMSGHELP(), };
  $O->{_OML_FUNCTIONS}->{'HELP'}        = sub { $O->omlHELP(), };
  $O->{_OML_FUNCTIONS}->{'HELPOVER'}    = sub { $O->omlHELPOVER(), };
} #LoadHTMLFunctions
# Alias - Function Group HTML 06
*LoadFunctionGroup06 = \&LoadHTMLFunctions;


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
sub Orbit::omlSELECTED
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $U = $self->{_Utils};
  #-- Get the option list ($V)
  my $V = $self->GetArgParse(1, @FunArgs);   # select/option text
  #-- get the find text - don't raise an error if not found
  my $a1 = $self->GetArgParse(2, @FunArgs);   # option value
  my $a2="";
  my $a3="";
  my $a4="";

  if ($self->IsArg(2, @FunArgs)) {
    #-- strip off any pre existing " and add them on either side
    #$a1 = '"'.$U->trim($a1, '"').'"';
    $a1 =~ s/"//g;
    $a1 = '"'.$a1.'"';

    my $ln_pos = index($V, $a1);
    #-- Try to get the option without the quotes if not found - look for '=<value> '
    if ($ln_pos == -1) {
      $a1 =~ s/"//g;
      $ln_pos = index($V, '='.$a1.' ');
      if ($ln_pos >= 0) {
        #-- reset the search value for replacement below
        $a1 = '='.$a1.' ';
      } else {
        $a1 = '"'.$a1.'"';
      }
    }
    if ($ln_pos >= 0) {
      #-- option found, so replace with SELECTED
      $V = $U->Replace($V, $a1, $a1.' SELECTED');
    } else {
      #-- Try to get the option without the quotes if not found - look for '=<value>>'
      if ($ln_pos == -1) {
        $a1 =~ s/"//g;   # replace " with nothing
        $ln_pos = index($V, '='.$a1.'>');
        if ($ln_pos >= 0) {
          #-- reset the search value for replacement below
          $a1 = '='.$a1.'>';
          #-- option found, so replace with SELECTED
          $V = $U->Replace($V, $a1, substr($a1, 0, length($a1)-1).' SELECTED>');
        }
      }
      #--
      #-- INSERT NEW OPTION AT TOP OF LIST
      #--  - Only if the no_add_flag is not set
      #--
      $a4 = $self->GetArgParse(5, @FunArgs);   # no_add_flag
      if ( $a4 ne '1'
          && $ln_pos == -1) {
        #-- First, look for first <option> tag in list
        $ln_pos = index($U->lower($V), '<option');
        #-- If no options, insert before </select> tag
        if ($ln_pos == -1) {
          $ln_pos = index($U->lower($V), '</select');
          #-- If no </select>, add to END of text in case <select> is present
          if ($ln_pos == -1) {
            $ln_pos = length($V);
          }
        }
        #-- check if the option text was specified
        $a2 = $self->GetArgParse(3, @FunArgs);   # option text
        #-- if option value was specified but option text was not, default to 'Not Found (Inactive)'
        if ( $a1 ne '""'
          && $a2 eq ""
          ) {
          #$a2 = 'Not Found';
        }
        #-- build the new list with the option inserted
        $V =   substr($V, 0, $ln_pos)
                    .'<option value="'.$a1.'" selected>'.$a2.'</option>'."\n"
                    .substr($V, $ln_pos);
      }
    }
    #-- Get the select class clause
    $a4 = $self->GetArgParse(4, @FunArgs);
    if ($self->IsArg(4, @FunArgs) && $a4 ne "") {
      #-- Add the select class to the <SELECT> tag
      $ln_pos = index($U->upper($V), '<SELECT');
      if ($ln_pos >= 0) {
        #-- <SELECT found, so replace with "<SELECT $a4 "
        #-- build the new list with the option inserted
        $V =   substr($V, 0, $ln_pos+7)
                    .' '.$a4.' '
                    .substr($V, $ln_pos+8);
      }
    }
  }
  # Free up our local Function Argument copy
  undef @FunArgs;
  return $V;
}


#-----------------------------------------------------------------------------
#-- Check for the OPTIONS function - #OPTIONS[list].[separator].[option_line]#
#-- - Return an <option> list from the separated input list, for use in HTML SELECT.
#-- - Separators can be specified or auto-default: pipe(|), comma(,), semi-colon(;) if found in list.
#-- - Second separator provides "value|display" pair. 1|apple,2|pear,3|orange,7|kevin;
#-- - [option_line] specifies a custom option specification, or any other content,
#--   referencing #_OPTION_VALUE_# and #_OPTION_DISPLAY_#
#--
sub Orbit::omlOPTIONS
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $bFlush   = $self->{_bFlush};
  my $U = $self->{_Utils};
  use Core::Search;
  my $V = $self->GetArgParse(1, @FunArgs);
  $V =~ s/\n//g;
  my $a2 = $self->GetArgParse(2, @FunArgs);
  $a2 = ',' if ($a2 eq "");
  my $a3="";

  # Get the best delimiter from the data
  $a2 = $U->GetDelimiters($V, $a2);

  if ($V ne "" && $a2 ne "") {
    my $delim1 = substr($a2, 0, 1);   # Get the first delimiter
    my $delim2 = substr($a2, 1, 1) if (length($a2) >= 2);
    $delim2 = "" if (!defined($delim2));

    # Special fix for | - when searching in RegEx - must escape with backslash \
    $delim1 = '\|' if ($delim1 eq "|");
    $delim2 = '\|' if ($delim2 eq "|");

    # Use primary delimiter first
    my @OPTIONS = split($delim1, $V);

    $a3 = $self->GetArgNoParse(3, @FunArgs);

    # initialize output
    $V="";

    my $value="";
    my $display="";
    # search through each Arg and if any is false, return 0
    for (my $I=0; $I < @OPTIONS; $I++) {
      # Get the next item or name/value pair
      $value   = $U->trim($OPTIONS[$I]);
      $display = "";

      # Assign name/value pair
      ($value, $display) = split($delim2, $value) if ($delim2 ne "" && $value ne "");
      $display = $value if (!defined($display) || $display eq "");

      # Check for user specified option line - use orbit parse
      if ($a3 eq "") {
        # Standard quick line
        $V .= "<option value=\"".$value."\">".$display."</option>";
      } else {
        $self->Set_Token('_OPTION_VALUE_', $value);
        $self->Set_Token('_OPTION_DISPLAY_', $display);
        $V .= $self->Parse($a3, $bFlush);
      }
    }
    undef @OPTIONS;
  }

  # Free up our local Function Argument copy
  undef @FunArgs;
  return $V;
}


#-----------------------------------------------------------------------------
#-- Check for the JSQUOTE function - #JSQUOTE[<message_text>]#
#--
sub Orbit::omlJSQUOTE
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $V = $self->GetArgParse(1, @FunArgs);  #-- Message Text
  if ($V ne "") {
    $V =~ s/'/\\'/g;
    $V =~ s/"/\\"/g;
    $V =~ s/\n/\\r/g;
  }

  # Free up our local Function Argument copy
  undef @FunArgs;
  return $V;
}


#-----------------------------------------------------------------------------
#-- Check for the MSGHELP function - #MSGHELP[<code>][<message_text>][<message_help>][<comment_text>]#
#-- - returns the help text for a message
sub Orbit::omlMSGHELP
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $V = "";
  my $a1 = $self->GetArgParse(1, @FunArgs);  #-- Message Code
  my $a2 = "";
  my $a3 = "";
  if ($a1 ne "") {
    $a2 = $self->GetArgNoParse(2, @FunArgs);  #-- Message Text
    if ($self->IsArg(2, @FunArgs)) {
      $V = $self->GetArgNoParse(3, @FunArgs);  #-- Help Text
      if ($self->IsArg(3, @FunArgs)) {
        $a3 = $self->GetArgNoParse(4, @FunArgs);  #-- Comment Text
      }
    }
    #-- Get the message text for the code specified
    #-- and the user or country default language
    $self->GetMessageText( $a1, $a2, $V, $a3 );
  }
  # Free up our local Function Argument copy
  undef @FunArgs;
  return $V;
}


#-----------------------------------------------------------------------------
#-- Check for the HELP function - #HELP[<text>][<popup_text>][<required_flag>]#
#--
sub Orbit::omlHELP
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $U = $self->{_Utils};
  my $Text  = $self->GetArgParse(1, @FunArgs);  #-- base text
  # Get the translated text
  $Text = $self->GetMessageText($Text);
  my $V = $Text;
  my $popup = $self->GetArgParse(2, @FunArgs);  #-- Popup Text
  if ($Text ne ""
     && $popup ne "") {
    my $req = $self->GetArgParse(3, @FunArgs);  #-- required_flag
    if ($U->NVL($req,'0') eq '1') {
      $req = '_req';
    } else {
      $req = '';
    }
    $V =~ s/\n/ /g;
    $V =~ s/&#013;/ /g;
    $V =~ s/"/&quot;/g;   # Replace "
    $V =~ s/'/\\'/g;

    $Text =~ s/"/&quot;/g;   # Replace "
    #-- KR 1/2/04 - added tabindex=-1 so image will not be part of tab sequence
    $V = '<a href="javascript:void(0);" tabindex="-1" class="help_popup'.$req.'"'
              .' onMouseOver="window.status=\''.$V
      .'\'; return true;"'
      .' onMouseOut="window.status=\'\'; return true;"'
      .' title="'.$Text.'">'.$V.'</a>';
  }
  # Free up our local Function Argument copy
  undef @FunArgs;
  return $V;
}


#-----------------------------------------------------------------------------
#-- Check for the HELPOVER function - #HELPOVER[<popup_text>]#
#--
sub Orbit::omlHELPOVER
{
  my ($self) = @_;
  # GetLocal - Get the Global Function arguments Locally in @FunArgs
  my @FunArgs = $self->GetFunctionArgsArray();
  my $V = "";
  my $Help = $self->GetArgParse(1, @FunArgs);  #-- Popup Text
  if ($Help ne "") {
    # Get the translated text
    $Help = $self->GetMessageText($Help);
    $V = $Help;
    $V =~ s/\n/ /g;
    $V =~ s/&#013;/ /g;
    $V =~ s/"/&quot;/g;   # Replace "
    $V =~ s/'/\\'/g;

    $Help =~ s/"/&quot;/g;   # Replace "
    $V = ' onMouseOver="window.status=\''.$V
      .'\'; return true;"'
      .' onMouseOut="window.status=\'\'; return true;"'
      .' title="'.$Help.'" ';
  }
  # Free up our local Function Argument copy
  undef @FunArgs;
  return $V;
}


#******************************************************************************************
# Return true to show package was loaded with
# use Orbit::OML::Function::HTML;
#******************************************************************************************
1;


#END Orbit::OML:Function::HTML Package
