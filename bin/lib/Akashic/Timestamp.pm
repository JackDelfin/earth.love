#!/usr/bin/perl
# Version 6.7.1.0      17-Jun-2021
#*****************************************************************************************
#*
#*  Package Name    :   Akashic:Timestamp
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
# TIMESTAMP UTILITIES
#----------------------------------------#
#
# Timestamp
#   - Returns a timestamp formatted string for Transaction processing
#
#*****************************************************************************************
package Akashic;

use strict;
use warnings;
use utf8;
use feature ':5.16';


#******************************************************************************************
# Timestamp
#
# - Returns a timestamp formatted string for Transaction processing
#******************************************************************************************/
sub Akashic::Timestamp
{
  my ( $self, $DateTimeSep ) = @_;

  $DateTimeSep = "" if (!defined($DateTimeSep));

  my ( $Sec,$Min,$Hour, $MonthDay,$Month,$Year, $WeekDay,$YearDay,$IsDST) = gmtime();
  $Year+=1900; $Month++;

  my $sysdate = "";
  $sysdate = sprintf("%d%02d%02d".$DateTimeSep."%02d%02d%02d"
                    ,$Year, $Month, $MonthDay, $Hour, $Min, $Sec);

  return $sysdate;
} #Timestamp


#******************************************************************************************
# Return true to show package was loaded with
# use Akashic:Timestamp;
#******************************************************************************************
1;

#END Akashic:Timestamp
