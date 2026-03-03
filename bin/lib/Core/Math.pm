#!/usr/bin/perl
# Version 6.7.1.0      17-Jun-2021
#*****************************************************************************************
#*
#*  Package Name    :   Core::Math
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
# sign
#   - Returns -1, 0, 1 based on sign of the number, '' if not defined
#
# mod <num1> <num2>
#   - Returns the modulus (remainder in integers) for val1 / val2
#   - port for Oracle PL/SQL compatibility
#
#*****************************************************************************************
package CoreUtils;

use strict;
use warnings;
use utf8;
use feature ':5.16';

use Core::Numbers;

################################################################################
#
# sign
#
# - Returns -1, 0, 1 based on sign of the number, '' if not defined
#
################################################################################
sub CoreUtils::sign
{
  my ( $self, $String ) = @_;

  # Null is not a number
  return '' if (!defined($String) || $String eq "");

  $String = $self->GetNumber($String,0);
  return '' if ($String eq '');

  if      ($String < 0) {
    return -1;
  } elsif ($String == "0") {
    return 0;
  } else {
    return 1;
  }
  return '';
} #sign


################################################################################
#
# mod <num1> <num2>
#
# - Returns the modulus (remainder in integers) for val1 / val2
# - port for Oracle PL/SQL compatibility
#
################################################################################
sub CoreUtils::mod
{
  my ( $self, $val1, $val2 ) = @_;
  use Core::Math::Round;

  # Get the numbers from a string
  my $num1 = $self->GetNumber($val1,0);
  my $num2 = $self->GetNumber($val2,0);

  # Avoid divide by
  return '' if ($num2 == 0 || $num1 eq '' || $num2 eq '');

  my $div = $num1/$num2;
  my $mod = 0;
  $mod = $self->trunc($num1 - $num2 * $self->trunc($div));

  return $mod;
} #mod


#******************************************************************************************
# Return true to show package was loaded with
# use Core::Math;
#******************************************************************************************
1;

#END Core::Math
