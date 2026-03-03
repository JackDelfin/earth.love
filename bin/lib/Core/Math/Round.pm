#!/usr/bin/perl
# Version 6.7.1.0      17-Jun-2021
#*****************************************************************************************
#*
#*  Package Name    :   Core::Math::Round
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
# MATH / NUMBER UTILITIES
#----------------------------------------#
#
# trunc <number> [precision]
#   - Truncates the number without rounding, to the precision specified
#   - Precision:  Default:0  Range:0-4
#   - Alias: Trunc
#
# round <number> [precision]
#   - Rounds the number to the precision specified (0, 1, 2, 3, 4)
#   - Alias: Round
#
#*****************************************************************************************
package CoreUtils;

use strict;
use warnings;
use utf8;
use feature ':5.16';


################################################################################
#
# trunc <number> [precision]
#
# - Truncates the number without rounding, to the precision specified
# - Precision:  Default:0  Range:0-4
#
################################################################################
sub CoreUtils::trunc
{
  my ( $self, $num, $precision ) = @_;

  # Make sure the string is a number
  $num = $self->GetNumber($num,0);

  # leave if there's no number
  return '' if ($num eq '');

  # Get the precision: 0 default
  $precision = 0 if (!defined($precision) || $precision eq '');
  # Restrict precision to 0-4
  $precision = 0 if ($precision < 0 || $precision > 4);

  my $dot;
  # Leave if we don't have a decimal to deal with
  if ($self->{_Decimal} eq '.' || index($num, '.') != -1) {
    # find the decimal separator
    $dot = index($num, '.');
  } else {
    # the only other standard on the planet is a comma for the decimal separator - perhaps
    # find the decimal separator
    $dot = index($num, ',');
  }
  return $num if ( $dot == -1 );

  #
  # Truncate the number after the Decimal
  #
  if ($precision == 0) {
    $num = substr($num, 0, $dot)+0;
  } else {
    $num = substr($num, 0, $dot+1+$precision)+0;
  }

  return $num;
} #trunc
*Trunc = \&trunc;


################################################################################
#
# round <number> [precision]
#
# - Rounds the number to the precision specified (0, 1, 2, 3, 4)
#
################################################################################
sub CoreUtils::round
{
  my ( $self, $num, $precision ) = @_;

  # Make sure the string is a number
  $num = $self->GetNumber($num,0);

  # Get the precision: 0 default
  $precision = 0 if (!defined($precision) || $precision eq '');

  # Restrict precision to 0-4
  $precision = 0 if ($precision < 0 || $precision > 4);

  # leave if there's no number
  return '' if ($num eq '');

  my $dot;
  # Leave if we don't have a decimal to deal with
  if ($self->{_Decimal} eq '.' || index($num, '.') != -1) {
    # find the decimal separator
    $dot = index($num, '.');
  } else {
    # the only other standard on the planet is a comma for the decimal separator - perhaps
    # find the decimal separator
    $dot = index($num, ',');
  }
  # return formatted number if no Decimal separator
  if ( $dot == -1 ) {
    if ($precision > 0) {
      $num = $num.$self->{_Decimal}.$self->rpad('0', $precision, '0');
    }
    return $num;
  }

  # get the precision position to check
  my $pos = $dot+1+$precision;

  # If there is not enough precision in the input, return after formatting
  if ($pos > length($num)) {
    $num = $num.$self->rpad('0', $precision+1-length(substr($num, $dot)), '0');
    return $num;
  }

  # Get the number at pos
  my $check = substr($num, $pos, 1);
  # make sure the check digit is a valid number
  return $num if ($check eq '');

  # precision 0 removes the decimal separator
  if ($precision == 0) {
    $num = substr($num, 0, $dot);
  } else {
   # Get the number to the precision
    $num = substr($num, 0, $pos);
  }

  #
  # Round the number
  #
  # Check the number at the precision and increase for rounding
  if ($check >= 5) {
    if ($precision == 0) {
      if ($num =~ /^-.*/) {
        # Negative round
        $num--;
      } else {
        # Positive roudn
        # precision 0 round - add 1 integer
        $num++;
      }
    } else {
      # Precision of 1 adds 1/10 if rounding
      my $add = 0;
      $add = '0.1'    if ($precision == 1);
      $add = '0.01'   if ($precision == 2);
      $add = '0.001'  if ($precision == 3);
      $add = '0.0001' if ($precision == 4);
      if ($num =~ /^-.*/) {
        $num = $num - $add;
      } else {
        $num = $num + $add;
      }
      # Get the dot in the output to see if we need to pad 0's for precision
      if ($self->{_Decimal} eq '.' || index($num, '.') != -1) {
        $dot = index($num, '.');
      } else {
        $dot = index($num, ',');
      }
      # return formatted number if no Decimal separator
      if ( $dot == -1 ) {
        # Return the formatted string if precision with no Decimal separator
        $num = $num.$self->{_Decimal}.$self->rpad('0', $precision, '0');
      } else {
        if (length(substr($num, $dot))-1 < $precision) {
          $num = $num.$self->rpad('0', $precision+1-length(substr($num, $dot)), '0');
        }
      }
    }
  }

  return $num;
} #round
*Round = \&round;

#******************************************************************************************
# Return true to show package was loaded with
# use Core::Math::Round;
#******************************************************************************************
1;

#END Core::Math::Round
