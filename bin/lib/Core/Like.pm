#!/usr/bin/perl
# Version 6.7.1.0      17-Jun-2021
#*****************************************************************************************
#*
#*  Package Name    :   Core::Like
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
# REPLACE UTILITIES
#----------------------------------------#
#
# like <val1> <val2>
#   - Returns 1 if <val1> is like <val2> with pattern matching in val2
#   - Pattern Matching:
#     (%_) Oracle Convention
#     ($?) DOS Convention
#     (*.) Unix / perl convention
#
# ilike <val1> <val2>
#   - Returns 1 if <val1> is like <val2> with pattern matching in val2 (case insensitive)
#   - Pattern Matching:
#
#*****************************************************************************************
package CoreUtils;

use strict;
use warnings;
use utf8;
use feature ':5.16';


################################################################################
#
# like <val1> <val2>
#
# - Returns 1 if <val1> is like <val2> with pattern matching in val2
#
# - Pattern Matching:
#     (%_) Oracle Convention
#     ($?) DOS Convention
#     (*.) Unix / perl convention
#
################################################################################
sub CoreUtils::like
{
  my ( $self, $val1, $val2 ) = @_;

  $val1 = '' if (!defined($val1));
  $val2 = '' if (!defined($val2));

  # quick matches / conditions
  return 1 if ($val1 eq $val2);
  return 0 if ($val1 eq '' || $val2 eq '');

  # Switch out any "Oracle/DOS Style" syntax with regular expressions (ie perl)
  $val1 = $self->FixSearchString($val1);
  $val2 = $self->FixSearchString($val2);

  # return if they match or not with updated pattern matching
  if ($val1 =~ /^$val2$/) {
    return 1;
  }

  return 0;
} #like


################################################################################
#
# ilike <val1> <val2>
#
# - Returns 1 if <val1> is like <val2> with pattern matching in val2 (case insensitive)
#
# - Pattern Matching:
#     (%_) Oracle Convention
#     ($?) DOS Convention
#     (*.) Unix / perl convention
#
################################################################################
sub CoreUtils::ilike
{
  my ( $self, $val1, $val2 ) = @_;

  $val1 = '' if (!defined($val1));
  $val2 = '' if (!defined($val2));

  # quick matches / conditions
  return 1 if ($val1 eq $val2);
  return 0 if ($val1 eq '' || $val2 eq '');

  # Switch out any "Oracle/DOS Style" syntax with regular expressions (ie perl)
  $val1 = $self->FixSearchString($val1);
  $val2 = $self->FixSearchString($val2);

  # return if they match or not with updated pattern matching
  if ($val1 =~ /^$val2$/i) {   # case insensitive search
    return 1;
  }

  return 0;
} #ilike


#******************************************************************************************
# Return true to show package was loaded with
# use Core::Like;
#******************************************************************************************
1;

#END Core::Like
