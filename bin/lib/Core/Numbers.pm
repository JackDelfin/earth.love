#!/usr/bin/perl
# Version 6.7.1.0      17-Jun-2021
#*****************************************************************************************
#*
#*  Package Name    :   Core::Numbers
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
# NUMBER VALIDATION UTILITIES
#----------------------------------------#
#
# SetNumberFormat <Thousands> <Decimal> <Currency>
#   - Set the number formats
#
# IsNumber <text> <RemoveThousands>
#   - Determines if string is a valid number.
#     If bRemoveThousands = 1, then the thousands separator will be
#     removed from the input string before conversion
#     NULL is NOT a number
#
# GetNumber <text> <RemoveThousands>
#   - Returns a number for a string (NULL if there are non-numbers in a string)
#     If bRemoveThousands = 1, the thousands separator (,.)  are removed
#     from the input string before conversion
#
# Numbers <text>
#   - Returns only the number portion of a string, including negative (-) and decimal
#
# NumberToChar <number> <format>
#   - Returns a number formatted to the specified mask
#   - Format chars: ($) currency (,) thousands (.) decimal (0 through 0000 for round)
#     Ex:  $,.00  ,.0$
#   - NOTE: The values for Thousands, Decimal, and Currency will be used from the class
#           The $,.0 are just placeholders with the provided definition for the format mask
#
#*****************************************************************************************
package CoreUtils;

use strict;
use warnings;
use utf8;
use feature ':5.16';


#******************************************************************************************
#* SetNumberFormat <Thousands> <Decimal> <Currency>
#*
#* - Set the number formats
#******************************************************************************************/
sub CoreUtils::SetNumberFormat {
  my ($self, $Thousands, $Decimal, $Currency) = @_;

  $Thousands = ',' if (!defined($Thousands));  # Comma default for Thousands Separator
  $Decimal   = '.' if (!defined($Decimal) || $Decimal eq "");    # Period default for Decimal Separator (can't have null)
  $Currency  = '$' if (!defined($Currency));   # Curency Symbol

  $self->{_Thousands} = $Thousands;
  $self->{_Decimal}   = $Decimal;
  $self->{_Currency}  = $Currency;
} #SetNumberFormat


#******************************************************************************************
#* IsNumber <text> <RemoveThousands>
#*
#* - Determines if string is a valid number.
#*   If bRemoveThousands = 1, then the thousands separator will be
#*   removed from the input string before conversion
#*   NULL is NOT a number
#******************************************************************************************/
sub CoreUtils::IsNumber
{
  my ( $self, $String, $bRemoveThousands ) = @_;

  # Null is not a number
  return 0 if (!defined($String) || $String eq "");

  $bRemoveThousands = 0 if (!defined($bRemoveThousands) || $bRemoveThousands ne '1');

  if ($bRemoveThousands eq "1") {
    if ($self->{_Thousands} eq ',') {
      $String =~ s/,//g;   # Take out comma
      return ($String =~ /^[-]*[0-9]*[\.]*[0-9]*$/)?1:0;
    } else {
      $String =~ s/\.//g;   # Take out period - comma is decimal point
      return ($String =~ /^[-]*[0-9]*[,]*[0-9]*$/)?1:0;
    }
  } else {
    if ($self->{_Decimal} eq '.') {
      return ($String =~ /^[-]*[0-9]*[\.]*[0-9]*$/)?1:0;
    } else {
      return ($String =~ /^[-]*[0-9]*[,]*[0-9]*$/)?1:0;
    }
  }
  return 0;
} #IsNumber


#******************************************************************************************
#* GetNumber <text> <RemoveThousands>
#*
#* - Returns a number for a string (NULL if there are non-numbers in a string)
#*   If bRemoveThousands = 1, the thousands separator (,.)  are removed
#*   from the input string before conversion
#******************************************************************************************/
sub CoreUtils::GetNumber
{
  my ( $self, $fv_string, $bRemoveThousands ) = @_;

  $bRemoveThousands = 0 if (!defined($bRemoveThousands) || $bRemoveThousands ne '1');

  # Return the input string if it is a number
  if ($self->IsNumber($fv_string, $bRemoveThousands) == 1) {
    #
    # Remove the Thousands separator if requested
    #
    if ($bRemoveThousands eq "1") {
      if ($self->{_Thousands} eq ',') {
        $fv_string =~ s/,//g;   # Take out valid numbers and should be blank
      } else {
        $fv_string =~ s/\.//g;   # Additional planetary format (1,234.56  1.234,56)
      }
    }
    # See if we have a Decimal separator in last position - remove it (ie 137.)
    my $lastpos = substr($fv_string, length($fv_string)-1, 1);
    if ($lastpos eq $self->{_Decimal}
      ||$lastpos eq '.'
      ) {
      $fv_string = substr($fv_string, 0, length($fv_string)-1);
    }
    return $fv_string;
  }

  return "";
} #GetNumber


#******************************************************************************************
#* Numbers <text>
#*
#* - Returns only the number portion of a string, including negative (-) and decimal
#******************************************************************************************/
sub CoreUtils::Numbers
{
  my ( $self, $fv_string ) = @_;

  return '' if (!defined($fv_string) || $fv_string eq '');

  my $buf = '';
  my $char = '';
  for (my $i=0; $i<length($fv_string); $i++) {
    $char = substr($fv_string, $i, 1);
    # Check for the universal Decimal separator
    if ($self->{_Decimal} eq '.') {
      $buf .= $char if ($char =~ /[0-9-.]/);
    } else {
      $buf .= $char if ($char =~ /[0-9-,]/);
    }
  }

  return $buf;
} #Numbers


#******************************************************************************************
#*
#* NumberToChar <number> <format>
#*
#* - Returns a number formatted to the specified mask
#*
#*    Format chars: ($) currency (,) thousands (.) decimal (0 through 0000 for round)
#*    Ex:  $,.00  ,.0$
#*
#*    NOTE: The values for Thousands, Decimal, and Currency will be used from the class
#*          The $,.0 are just placeholders with the provided definition for the format mask
#******************************************************************************************/
sub CoreUtils::NumberToChar
{
  my ( $self, $fn_number, $fv_format ) = @_;

  $fn_number = "" if (!defined($fn_number));
  $fv_format = "" if (!defined($fv_format));

  # Get just the number portion
  my $Number = "";
  $Number = $self->GetNumber($fn_number,0) if ($fv_format eq "");
  $fn_number = $Number if ($Number ne "");

  # Keep input intact if no format specified
  return $fn_number if ($fn_number eq "" || $fv_format eq "");

  # Check for 2 decimal (. decimal separator)
  if ($fv_format =~ /^.*\.00$/
    ||$fv_format =~ /^.*\.00\$$/
    ) {
    $fn_number = $self->round($fn_number, 2);
  } elsif ($fv_format =~ /^.*\.0$/
    ||$fv_format =~ /^.*\.0\$$/
    ) {
    $fn_number = $self->round($fn_number, 1);
  } elsif ($fv_format =~ /^.*\.$/
    ||$fv_format =~ /^.*\.\$$/
    ) {
    $fn_number = $self->round($fn_number, 0);
  } elsif ($fv_format =~ /^.*\.000$/
    ||$fv_format =~ /^.*\.000\$$/
    ) {
    $fn_number = $self->round($fn_number, 3);
  } elsif ($fv_format =~ /^.*\.0000$/
    ||$fv_format =~ /^.*\.0000\$$/
    ) {
    $fn_number = $self->round($fn_number, 4);
  }

  # Set the thousands separator every 3 numbers
  if ($fv_format =~ /^.*,.*$/) {
    my $num = $fn_number;

    # Check for negative
    my $neg = index($fn_number, '-');
    if ($neg == 0) {
      $num = substr($fn_number, 1);
    }

    # Check for decimal point
    my $dec = index($num, $self->{_Decimal});
    if ($dec >= 0) {
      $num = substr($num, 0, $dec);
      # Get original position for replacing below
      $dec = index($fn_number, $self->{_Decimal});
    }

    my $len = length($num);
    my $div = $self->ceil($len/3); # number of segments
    my $mod = $self->mod($len, 3);  # remainder numbers to left
    my $seg="";
    my $newnum = "";

    # Add the negative first
    $newnum = '-' if ($neg == 0);

    # Add the topmost 1 or 2 numbers
    $newnum .= substr($num, 0, $mod) if ($mod > 0);
    $newnum .= substr($num, 0, 3) if ($mod == 0);

    # Get the number in 3 digit segments
    if ($mod == 0) {
      $num = substr($num, 3);
    } else {
      $num = substr($num, $mod);
    }
    for (my $i=1; $i<$div; $i++) {
      $seg = substr($num, ($i-1)*3, 3);
      last if (!defined($seg));
      if ($self->{_Thousands} ne "") {
        $newnum .= $self->{_Thousands}.$seg;
      } else {
        $newnum .= $seg;
      }
    }

    # Re-add the decimal
    $newnum .= substr($fn_number, $dec) if ($dec != -1);
    $fn_number = $newnum;
  }

  # See if we add currency to the beginning
  if (index($fv_format, '$') == 0) {
    $fn_number = $self->{_Currency}.$fn_number;
  }
  # See if we add currency to the end
  if (length($fv_format) > 1 && substr($fv_format, length($fv_format)-1, 1) eq '$') {
    $fn_number .= $self->{_Currency};
  }

  return $fn_number;
} #NumberToChar


#******************************************************************************************
#*
#* To_Hex <number>
#*
#* - Returns the hexadecimal equivalent to the input number
#******************************************************************************************/
#sub CoreUtils::To_Hex
#{
#  my ( $self, $fn_number ) = @_;

#  $lv_hex            VARCHAR2(500) = NULL;
#  $lv_hex_mod        VARCHAR2(1);
#  $li_mod            BINARY_INTEGER;
#  $li_div            BINARY_INTEGER;

#  if ($fn_number eq "") {
#    return '';
#  }
#  if ($fn_number == 0) {
#    return '0';
#  }
#  $li_mod = mod(fn_number, 16);
#  $li_div = trunc(fn_number / 16);
#  #-- Keep looping until there's no remainder
#  WHILE $li_div > 0 or $li_mod > 0 LOOP
#    if ($li_mod > 9) {
#      $lv_hex_mod = CHR(ASCII('A') + $li_mod - 10);
#    } else {
#      $lv_hex_mod = $self->to_char($li_mod);
#    }
#    #-- Append the new hex character
#    $lv_hex = $lv_hex_mod || $lv_hex;
#    #-- Get the next iteration variables
#    $li_mod = mod($li_div, 16);
#    $li_div = trunc($li_div / 16);
#  }
#  return $lv_hex;

#  return "CODE";
#} #To_Hex

#******************************************************************************************
# Return true to show package was loaded with
# use Core::Numbers;
#******************************************************************************************
1;

#END Core::Numbers
