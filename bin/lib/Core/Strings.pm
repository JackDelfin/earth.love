#!/usr/bin/perl
# Version 6.7.1.0      17-Jun-2021
#*****************************************************************************************
#*
#*  Package Name    :   Core::Strings
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
# STRING UTILITIES
#----------------------------------------#
#
# upper
#   - Returns uppercase of text
#
# lower
#   - Returns lowercase of text
#
# initcap
#   - Initial Capitalize a name taking into consideration suffixes
#
# InitName
#   - Initial Capitalize a name taking into consideration suffixes
#
# translate <text> <from_chars> <to_chars>
#   - Translate characters from one buffer to the other
#   - Just like tr/A/a/ in perl
#   - Support routine for conversion from Oracle PL/SQL
#
# ltrim <text> <trimchar>
#   - Left trim a string, trimming trimchar (default: space, \t, \n)
#
# rtrim <text> <trimchar>
#   - Right trim a string, trimming trimchar (default: space, \t, \n)
#
# trim <text> <trimchar>
#   - Trim the Right AND Left of a text string, trimming trimchar (default space, \t, \n)
#
# lpad <text> <length> <fillchar>
#   - Left pad a string to length, filling with fill char (default space)
#
# rpad <text> <length> <fillchar>
#   - Right pad a string to length, filling with fill char (default space)
#
# to_char <text> <null_value>
#   - Use for conversions from Oracle PL/SQL which makes heavy use of this
#   - Returns <text> in all cases
#
# NVL <text> <null_value>
#   - Use for conversions from Oracle PL/SQL which makes heavy use of this
#   - Returns <null_value> if <text> is null, returns <text> otherwise
#
#*****************************************************************************************
package CoreUtils;

use strict;
use warnings;
use utf8;
use feature ':5.16';


#******************************************************************************************
#* upper
#*
#* - Returns uppercase of text
#******************************************************************************************/
sub CoreUtils::upper
{
  my ( $self, $fv_string ) = @_;

  return "" if (!defined($fv_string) || $fv_string eq "");

  $fv_string =~ tr/[a-z]/[A-Z]/;

  return $fv_string;
} #upper


#******************************************************************************************
#* lower
#*
#* - Returns lowercase of text
#******************************************************************************************/
sub CoreUtils::lower
{
  my ( $self, $fv_string ) = @_;

  return "" if (!defined($fv_string) || $fv_string eq "");

  $fv_string =~ tr/[A-Z]/[a-z]/;

  return $fv_string;
} #lower


#******************************************************************************************
#* initcap
#*
#* - Initial Capitalize a name taking into consideration suffixes
#******************************************************************************************/
sub CoreUtils::initcap
{
  my ( $self, $fv_string ) = @_;

  return "" if (!defined($fv_string) || $fv_string eq "");

  $fv_string =~ tr/[A-Z]/[a-z]/;

  my $char="";
  my $pos=0;
  # loop through the characters of the string and initcap based on rules
  for ($pos=0; $pos < length($fv_string); $pos++)
  {
    if (($pos == 0
        # check for previous character not a letter or HTML start
        || (!(substr($fv_string, $pos-1, 1) =~ /[A-Za-z]/)
          && substr($fv_string, $pos-1, 1) ne '<'   # Not HTML tag
          )
        )
      # and current position is a lowercase letter
      && substr($fv_string, $pos, 1) =~ /[a-z]/
      ) {
      #
      # Get the character and uppercase it
      #
      $char = "".substr($fv_string, $pos, 1)."";
      $char =~ tr/[a-z]/[A-Z]/;

      # Rebuild the string
      $fv_string = substr($fv_string, 0, $pos)
                  ."$char"
                  .substr($fv_string, $pos+1);
    }
  }
  return $fv_string;
} #initcap


#******************************************************************************************
#* InitName
#*
#* - Initial Capitalize a name taking into consideration suffixes
#******************************************************************************************/
sub CoreUtils::InitName
{
  my ( $self, $fv_string ) = @_;

  return "" if (!defined($fv_string));

  my $ln_ptr=0;

  #replace(' '.initcap(fv_string).' /,/ ,/g;
  my $lv_string = ' '.$self->initcap($fv_string).' ';

  $lv_string =~ s/,/ ,/g;
  #-- Standard Suffixes
  $lv_string =~ s/ Iii / III /g;
  $lv_string =~ s/ Ii / II /g;
  $lv_string =~ s/ Iv / IV /g;
  #-- Medical Suffixes
  $lv_string =~ s/ Phd / PhD /g;
  $lv_string =~ s/ Md / MD /g;
  $lv_string =~ s/ Mph / MPH /g;
  $lv_string =~ s/ Pa / PA /g;
  $lv_string =~ s/ Pt / PT /g;
  $lv_string =~ s/ Do / DO /g;
  $lv_string =~ s/ Dc / DC /g;
  $lv_string =~ s/ Dpm / DPM /g;
  $lv_string =~ s/ Atc / ATC /g;
  $lv_string =~ s/ Aacfs / AACFS /g;
  $lv_string =~ s/ Faac / FAAC /g;
  $lv_string =~ s/ Faap / FAAP /g;
  $lv_string =~ s/ Facc / FACC /g;
  $lv_string =~ s/ Facg / FACG /g;
  $lv_string =~ s/ Facog / FACOG /g;
  $lv_string =~ s/ Facp / FACP /g;
  $lv_string =~ s/ Facr / FACR /g;
  $lv_string =~ s/ Facrs / FACRS /g;
  $lv_string =~ s/ Facs / FACS /g;
  #-- Search for Mc last name prefix
  $ln_ptr = index(' '.$lv_string, " Mc");
  if ($ln_ptr >= 0) {
    $lv_string = substr($lv_string, 0, $ln_ptr+2).$self->upper(substr($lv_string, $ln_ptr+2, 1)).substr($lv_string, $ln_ptr+3);
  }
  #-- remove double spaces
  $lv_string =~ s/ [ ]*/ /g;
  #-- Replace comma substitution
  $lv_string =~ s/ [ ]*,/,/g;
  #-- remove any leading / trailing spaces
  $lv_string =~ s/^ [ ]*//g;
  $lv_string =~ s/ [ ]*$//g;
  return $lv_string;
} #InitName


################################################################################
#
# translate <text> <from_chars> <to_chars>
#
# - Translate characters from one buffer to the other
# - Just like tr/A/a/ in perl
# - Support routine for conversion from Oracle PL/SQL
#
################################################################################
sub CoreUtils::translate
{
  my ( $self, $fv_text, $FromChars, $ToChars ) = @_;

  return '' if (!defined($fv_text) || $fv_text eq ''
              ||!defined($FromChars) || $FromChars eq ''
              ||!defined($ToChars) || $ToChars eq ''
              ||length($FromChars) != length($ToChars)    # translate length must be the same
              );

  my $From = "";
  my $To = "";
  for (my $i=0; $i<length($FromChars); $i++) {
    $From = substr($FromChars, $i, 1);
    $To = substr($ToChars, $i, 1);
    $fv_text =~ s/$From/$To/g;
  }

  return $fv_text;
} #translate


################################################################################
#
# ltrim <text> <trimchar>
#
# - Left trim a string, trimming trimchar (default: space, \t, \n)
#
################################################################################
sub CoreUtils::ltrim
{
  my ( $self, $fv_text, $trimchar ) = @_;

  return '' if (!defined($fv_text) || $fv_text eq '');

  # Default fill to space if not defined properly
  if (!defined($trimchar) || !(length($trimchar) == 1)) {
    $trimchar = 'DEFAULT';
    #
    # Default LTRIM
    #
    $fv_text =~ s/^[\n\t ]*//g;
  }

  if ($trimchar ne 'DEFAULT') {
    # the long way

    my $trimcnt = length($fv_text);
    # Remove leading char
    my $i=0;
    for ($i=0; $i<$trimcnt; $i++) {
      last if (substr($fv_text, $i, 1) ne $trimchar);
    }
    # Read to end of line
    $fv_text = substr($fv_text, $i);
  }

  return $fv_text;
} #ltrim


################################################################################
#
# rtrim <text> <trimchar>
#
# - Right trim a string, trimming trimchar (default: space, \t, \n)
#
################################################################################
sub CoreUtils::rtrim
{
  my ( $self, $fv_text, $trimchar ) = @_;

  return '' if (!defined($fv_text) || $fv_text eq '');

  # Default fill to space if not defined properly
  if (!defined($trimchar) || !(length($trimchar) == 1)) {
    $trimchar = 'DEFAULT';
    #
    # Default RTRIM
    #
    $fv_text =~ s/[\n\t ]*$//g;
  }

  if ($trimchar ne 'DEFAULT') {
    # the long way

    my $trimcnt = length($fv_text);
    # Remove trailing char
    my $i=0;
    for ($i=$trimcnt; $i>=0; $i--) {
      last if (substr($fv_text, $i-1, 1) ne $trimchar);
    }
    # Get text up to and including $i
    $fv_text = substr($fv_text, 0, $i);
  }

  return $fv_text;
} #rtrim


################################################################################
#
# trim <text> <trimchar>
#
# - Trim the Right AND Left of a text string, trimming trimchar (default space, \t, \n)
#
################################################################################
sub CoreUtils::trim
{
  my ( $self, $fv_text, $trimchar ) = @_;

  return $self->ltrim($self->rtrim($fv_text, $trimchar), $trimchar);

} #trim


################################################################################
#
# lpad <text> <length> <fillchar>
#
# - Left pad a string to length, filling with fill char (default space)
#
################################################################################
sub CoreUtils::lpad
{
  my ( $self, $fv_text, $length, $fill ) = @_;

  return '' if (!defined($fv_text));

  # Default fill to space if not defined properly
  if (!defined($fill) || !(length($fill) == 1)) {
    $fill = ' ';
  }

  # return text as is if the length specified is not a number
  # or the length of the string is already larger than length
  if ( !$self->IsNumber($length)
    || length($fv_text) >= $length
    ) {
    return $fv_text;
  }

  my $padcnt = $length-length($fv_text);
  # Prepend the fill for the length
  for (my $i=0; $i<$padcnt; $i++) {
    $fv_text = $fill.$fv_text;
  }

  return $fv_text;
} #lpad


################################################################################
#
# rpad <text> <length> <fillchar>
#
# - Right pad a string to length, filling with fill char (default space)
#
################################################################################
sub CoreUtils::rpad
{
  my ( $self, $fv_text, $length, $fill ) = @_;

  return '' if (!defined($fv_text));

  # Default fill to space if not defined properly
  if (!defined($fill) || !(length($fill) == 1)) {
    $fill = ' ';
  }

  # return text as is if the length specified is not a number
  # or the length of the string is already larger than length
  if ( !$self->IsNumber($length)
    || length($fv_text) >= $length
    ) {
    return $fv_text;
  }

  my $padcnt = $length-length($fv_text);
  # Append the fill for the length
  for (my $i=0; $i<$padcnt; $i++) {
    $fv_text .= $fill;
  }

  return $fv_text;
} #rpad


################################################################################
#
# to_char <text> <null_value>
#
# - Use for conversions from Oracle PL/SQL which makes heavy use of this
# - Returns empty string <text> in all cases, even for undefined
#
################################################################################
sub CoreUtils::to_char
{
  my ( $self, $fv_text, $fv_value ) = @_;
  $fv_value = "" if (!defined($fv_value));

  if (defined($fv_text) && $fv_text ne "") {
    return $fv_text;
  } else {
    return $fv_value;
  }
} #to_char


################################################################################
#
# NVL <text> <null_value>
#
# - Use for conversions from Oracle PL/SQL which makes heavy use of this
# - Returns <null_value> if <text> is null, returns <text> otherwise
#
################################################################################
sub CoreUtils::NVL
{
  my ( $self, $fv_text, $fv_value ) = @_;
  # Return value if text is null
  if (defined($fv_text) && defined($fv_value) && $fv_text eq "") {
    return $fv_value;
  } else {
    return $fv_text;
  }
} #NVL


#******************************************************************************************
# Return true to show package was loaded with
# use Core::Strings;
#******************************************************************************************
1;

#END Core::Strings
