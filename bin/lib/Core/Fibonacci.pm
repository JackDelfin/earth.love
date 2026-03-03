#!/usr/bin/perl
# Version 6.7.1.0      17-Jun-2021
#*****************************************************************************************
#*
#*  Package Name    :   Core::Fibonacci
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
# UTILITIES
#----------------------------------------#
#
# Fibonacci [start_iteration] [end_iteration] [delim]
#   - Return the Fibonacci sequence up to $times, delimited by $delim, (def ,)
#
#*****************************************************************************************
package CoreUtils;

use strict;
use warnings;
use utf8;
use feature ':5.16';


################################################################################
#
# Fibonacci [start_iteration] [end_iteration] [delim]
#
# - Return the Fibonacci sequence up to $times, delimited by $delim, (def ,)
#
#___O___
#  / \
# / . \
################################################################################
sub CoreUtils::Fibonacci {
  my ( $self, $start_iteration, $end_iteration, $delim, $a, $b, $iteration ) = @_;

  $start_iteration = 1 if (!defined($start_iteration) || $start_iteration < 1);
  $end_iteration = 21  if (!defined($end_iteration) || $end_iteration < $start_iteration);
  $a         = 0  if (!defined($a));
  $b         = 1  if (!defined($b));
  $delim     = ',' if (!defined($delim));
  $iteration = 0  if (!defined($iteration));   # Used for recursion

  # Initialize Fibonacci Sequence
  my $fib = $a;

  # Add the 2 seeds together
  my $sum = $a + $b;
  # shift the numbers
  $a = $b;
  $b = $sum;

  # Increase iteration count
  $iteration++;

  # See if iteration count has reached limit
  if ($iteration == $end_iteration) {
    return $fib;
  }

  my $nextfib = $self->Fibonacci($start_iteration, $end_iteration, $delim, $a, $b, $iteration);

  # Return blank if we're not
  if ($iteration < $start_iteration) {
    return $nextfib;
  }

  # Append the next Fibonacci to current fib
  $fib .= $delim.$nextfib;

  # Recursive call to fibonacci
  return $fib;
} #Fibonacci


#******************************************************************************************
# Return true to show package was loaded with
# use Core::Fibonacci;
#******************************************************************************************
1;

#END Core::Fibonacci
