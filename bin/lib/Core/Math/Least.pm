#!/usr/bin/perl
# Version 6.7.1.0      17-Jun-2021
#*****************************************************************************************
#*
#*  Package Name    :   Core::Math::Least
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
# least <val1> <val2>
#   - Returns the least numeric value of the 2 paramters
#
# greatest <val1> <val2>
#   - Returns the greatest numeric value of the 2 paramters
#   - port for Oracle PL/SQL compatibility
#
#*****************************************************************************************
package CoreUtils;

use strict;
use warnings;
use utf8;
use feature ':5.16';


################################################################################
#
# least <val1> <val2>
#
# - Returns the least numeric value of the 2 paramters
#
################################################################################
sub CoreUtils::least
{
  my ( $self, $val1, $val2 ) = @_;

  # Get the numbers from a string
  my $num1 = $self->GetNumber($val1,0);
  my $num2 = $self->GetNumber($val2,0);

  # leave if we don't have any data
  return $val2 if ($val1 eq '');
  return ''    if ($val2 eq '');

  # Check for arithmetic comparision
  if ($num1 ne '' && $num2 ne '')
  {
    # Numeric comparison
    if ($num1 <= $num2) {
      return $num1;
    } elsif ($num1 > $num2) {
      return $num2;
    }
  } else {
    # Text comparison
    if ($val1 le $val2) {
      return $val1;
    } elsif ($val1 gt $val2) {
      return $val2;
    }
  }

  # exception
  return "";
} #least


################################################################################
#
# greatest <val1> <val2>
#
# - Returns the greatest numeric value of the 2 paramters
# - port for Oracle PL/SQL compatibility
#
################################################################################
sub CoreUtils::greatest
{
  my ( $self, $val1, $val2 ) = @_;

  # Get the numbers from a string
  my $num1 = $self->GetNumber($val1,0);
  my $num2 = $self->GetNumber($val2,0);

  # leave if we don't have any data
  return $val2 if ($val1 eq '');
  return ''    if ($val2 eq '');

  # Check for arithmetic comparision
  if ($num1 ne '' && $num2 ne '')
  {
    # Numeric comparison
    if ($num1 >= $num2) {
      return $num1;
    } elsif ($num1 < $num2) {
      return $num2;
    }
  } else {
    # Text comparison
    if ($val1 ge $val2) {
      return $val1;
    } elsif ($val1 lt $val2) {
      return $val2;
    }
  }

  # exception
  return "";
} #greatest


#******************************************************************************************
# Return true to show package was loaded with
# use Core::Math::Least;
#******************************************************************************************
1;

#END Core::Math::Least
