#!/usr/bin/perl
# Version 6.7.1.0      17-Jun-2021
#*****************************************************************************************
#*
#*  Package Name    :   Core::HTML
#*
#*  Description     :   This package contains utility functions and procedures for supporting Orbit for Perl
#*
#*****************************************************************************************
# History:
#   2021.06.17 earth.love oK Refactored package for performance
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
#----------------------------------------#
# HTML HELPER UTILITIES
#----------------------------------------#
#
# Translate_HTML_Form_Get
#   - Translates characters in a parameter that conflict with Form Get special characters
#       Specifically: % & # + < > " and space
#
# Get_Raw_Text
#   - Replaces the characters &<>#" with HTML escaped characters
#       Used in .RAW, same as .HTML
#
# XML <field> <value> <indent>
#   - Return the "value" wrapped in <field>value</field> for XML format
#   - NOTE: Field is case sensitive - spelling counts
#   - <indent> is the number of spaces (default 0) to include before begin tag
#   - A Carriage Return is added to the return value
#
# GetXML <field> <text>
#   - Return the "value" in <text>, wrapped in <field>value</field> for XML format
#   - NOTE: Field is case sensitive - spelling counts
#
#*****************************************************************************************
package CoreUtils;

use strict;
use warnings;
use utf8;
use feature ':5.16';


#******************************************************************************************
#
# Translate_HTML_Form_Get
#
# - Translates characters in a parameter that conflict with Form Get special characters
#     Specifically: % & # + < > " and space
#
# URL Escape_Codes  String_Literal_Escape_Code
#
# SPACE   %20   $20
# <   %3C   $3C
# >   %3E   $3E
# #   %23   $23
# %   %25   $25
# +   %2B   $2B
# {   %7B   $7B
# }   %7D   $7D
# |   %7C   $7C
# \   %5C   $5C
# ^   %5E   $5E
# ~   %7E   $7E
# [   %5B   $5B
# ]   %5D   $5D
# `   %60   $60
# ;   %3B   $3B
# /   %2F   $2F
# ?   %3F   $3F
# :   %3A   $3A
# @   %40   $40
# =   %3D   $3D
# &   %26   $26
# $   %24   $24
#******************************************************************************************/
sub CoreUtils::Translate_HTML_Form_Get
  #(fv_string VARCHAR2)
  #RETURN VARCHAR2;
{
  my ( $self, $lv_string ) = @_;

  $lv_string =~ s/%/%25/g;   # Get the % first so we don't clobber other conversions
  $lv_string =~ s/\+/%2B/g;  # Change out + before spaces
  $lv_string =~ s/ /\+/g;    # Use + instead of %20 for a tighter Url
  $lv_string =~ s/</%3C/g;
  $lv_string =~ s/>/%3E/g;
  $lv_string =~ s/#/%23/g;
  $lv_string =~ s/{/%7B/g;
  $lv_string =~ s/}/%7D/g;
  $lv_string =~ s/\|/%7C/g;
  $lv_string =~ s/\\/%5C/g;
  $lv_string =~ s/\^/%5E/g;
  $lv_string =~ s/~/%7E/g;
  $lv_string =~ s/\[/%5B/g;
  $lv_string =~ s/\]/%5D/g;
  $lv_string =~ s/`/%60/g;   # backquote
  $lv_string =~ s/;/%3B/g;
  $lv_string =~ s/\//%2F/g;
  $lv_string =~ s/\?/%3F/g;
  $lv_string =~ s/:/%3A/g;
  $lv_string =~ s/\@/%40/g;
  $lv_string =~ s/=/%3D/g;
  $lv_string =~ s/&/%26/g;
  $lv_string =~ s/\$/%24/g;

  return $lv_string;
} #Translate_HTML_Form_Get


#******************************************************************************************
#
# Get_Raw_Text
#
# - Replaces the characters &<>#" with HTML escaped characters
#     Used in .RAW, same as .HTML
#******************************************************************************************
sub CoreUtils::Get_Raw_Text
  #          fv_text                        IN OUT NOCOPY LONG
{
  my ( $self, $Text ) = @_;

  $Text =~ s/&/&amp;/g;
  $Text =~ s/</&lt;/g;
  $Text =~ s/>/&gt;/g;
  $Text =~ s/#/&#035;/g;
  $Text =~ s/"/&quot;/g;

  return $Text;
} #Get_Raw_Text


#*******************************************************************************
#
# XML <field> <value> <indent>
#
#   - Return the "value" wrapped in <field>value</field> for XML format
#   - NOTE: Field is case sensitive - spelling counts
#   - <indent> is the number of spaces (default 0) to include before begin tag
#   - A Carriage Return is added to the return value
#
#*******************************************************************************
sub XML
{
  my ( $self, $Field, $Value, $indent ) = @_;
  return "" if ($Field eq "");   # Need a field name
  $indent = 0 if (!defined($indent) || !$self->isNumber($indent));
  my $spaces = "";
  
  # Check for indentation for easy reading of stacked data in XML
  if ($indent > 0) {
    my $U = $self->{_Utils};
    $spaces = $U->lpad(' ', $indent);
  }
  
  my $V = $spaces."<".$Field.">".$Value."</".$Field.">";
  return $V;
} #XML


#*******************************************************************************
#
# GetXML <field> <text>
#
#   - Return the "value" in <text>, wrapped in <field>value</field> for XML format
#   - NOTE: Field is case sensitive - spelling counts
#
#*******************************************************************************
sub GetXML
{
  my ( $self, $Field, $Text ) = @_;
  
  # Get the start and end tag position (case sensitive)
  my $s = index($Text, "<".$Field.">");
  my $e = index($Text, "</".$Field.">");
  
  # Leave if we don't have a valid XML format
  return "" if ($s == -1 || $e == -1);

  # Get length of field so we know the offset
  my $FieldLEN = length($Field);
  
  # return the contents between the markers
  return substr($Text, $s+2+$FieldLEN, $e-$s-2-$FieldLEN);
} #GetXML


#******************************************************************************************
# Return true to show package was loaded with
# use Core::HTML;
#******************************************************************************************
1;

#END Core::HTML
