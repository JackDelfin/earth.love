#!/usr/bin/perl
# Version 6.7.1.0      17-Jun-2021
#*****************************************************************************************
#*
#*  Package Name    :   Core::Math::Ceil
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
# MATH CEIL / FLOOR UTILITIES
#----------------------------------------#
#
# ceil <number>
#   - Gets the ceiling of the number, or next highest integer
#   - NOTE: For negative numbers the ceil returns the least negative integer
#     ex) ceil(34.6)  =  35
#         ceil(-34.6) = -34
#
# floor <number>
#   - Returns the floor integer of the number
#   - NOTE: This is similar to trunc, but for negative numbers the foor returns
#           the greatest negative below the decimal
#     ex) floor(34.6)  =  34
#         floor(-34.6) = -35
#
#*****************************************************************************************
package CoreUtils;

use strict;
use warnings;
use utf8;
use feature ':5.16';


################################################################################
#
# ceil <number>
#
# - Gets the ceiling of the number, or next highest integer
# - NOTE: For negative numbers the ceil returns the least negative integer
#
#   ex) ceil(34.6)  =  35
#       ceil(-34.6) = -34
#
################################################################################
sub CoreUtils::ceil
{
  my ( $self, $num ) = @_;

  # Make sure the string is a number
  $num = $self->GetNumber($num,0);

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
  return $num if ( $dot == -1 );

  #
  # Get the ceil of the number (integer)
  #
  if ($num =~ /^-.*/) {
    # Negative number - trunc decimal
    $num = (substr($num, 0, $dot));
    $num += 0;
  } else {
    # Positive - increase number
    $num = (substr($num, 0, $dot));
    $num++;
  }

  return $num;
} # ceil


################################################################################
#
# floor <number>
#
# - Returns the floor integer of the number
#
# - NOTE: This is similar to trunc, but for negative numbers the foor returns
#         the greatest negative below the decimal
#
#   ex) floor(34.6)  =  34
#       floor(-34.6) = -35
#
################################################################################
sub CoreUtils::floor
{
  my ( $self, $num ) = @_;

  # Make sure the string is a number
  $num = $self->GetNumber($num,0);

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
  return $num if ( $dot == -1 );

  #
  # Get the floor of the number (integer below)
  #
  if ($num =~ /^-.*/) {
    # Negative floor - use least negative integer
    $num = (substr($num, 0, $dot));
    $num--;
  } else {
    # Positive number - trunc decimal
    $num = (substr($num, 0, $dot));
    $num += 0;
  }

  return $num;
} #floor


#******************************************************************************************
# Return true to show package was loaded with
# use Core::Math::Ceil;
#******************************************************************************************
1;

#END Core::Math::Ceil
