#!/usr/bin/perl
# Version 6.7.1.0      17-Jun-2021
#*****************************************************************************************
#*
#*  Package Name    :   Core::Utils
#*
#* - This package contains utility functions and procedures for supporting Orbit for Perl
#*
#*****************************************************************************************
# History:
#   2021.06.17 earth.love oK Refactored package for performance
#   2021.05.31 earth.love oK Added Date/Time Formatting
#   2021.04.24 earth.love oK Converted from PL/SQL COR$UTILS package (2015.05.30 Ver 5.0.0.0)
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
# new #CoreUtils
#   - Initializes the Core Utilities package
#
#*****************************************************************************************
package CoreUtils;

use strict;
use warnings;
use utf8;
use feature ':5.16';


#******************************************************************************************
#*
#* new #CoreUtils
#*
#* - Initializes the Core Utilities package
#*
#******************************************************************************************
sub CoreUtils::new #CoreUtils
{
  my $class = shift;   # class is the name of this package: CoreUtils

  # Define the token structure (class variables)
  my $self = {
     #
     # NUMBERS
     #
     _Thousands          => ','   # Comma default for Thousands Separator
    ,_Decimal            => '.'   # Period default for Decimal Separator
    ,_Currency           => '$'   # Curency Symbol
     # Text arrays for Months/Days
    ,_Months             => { 0=>'Jan', 1=>'Feb', 2=>'Mar', 3=>'Apr', 4=>'May', 5=>'Jun', 6=>'Jul', 7=>'Aug', 8=>'Sep', 9=>'Oct', 10=>'Nov', 11=>'Dec' }
    ,_MonthsFull         => { 0=>'January', 1=>'February', 2=>'March', 3=>'April', 4=>'May', 5=>'June', 6=>'July', 7=>'August', 8=>'September', 9=>'October', 10=>'November', 11=>'December' }
    ,_Days               => { 0=>'Sun', 1=>'Mon', 2=>'Tue', 3=>'Wed', 4=>'Thu', 5=>'Fri', 6=>'Sat', 7=>'Sun' }
    ,_DaysFull           => { 0=>'Sunday', 1=>'Monday', 2=>'Tuesday', 3=>'Wednesday', 4=>'Thursday', 5=>'Friday', 6=>'Saturday', 7=>'Sunday' }
    ,_Hours              => { 0=>'One', 1=>'Two', 2=>'Three', 3=>'Four', 4=>'Five', 5=>'Six', 6=>'Seven', 7=>'Eight', 8=>'Nine', 9=>'Ten', 10=>'Eleven', 11=>'Twelve', 12=>'Thirteen', 13=>'Fourteen', 14=>'Fifteen', 15=>'Sixteen', 16=>'Seventeen', 17=>'Eighteen', 18=>'Nineteen', 19=>'Twenty', 20=>'Twenty-one', 21=>'Twenty-two', 22=>'Twenty-three', 23=>'Twenty-four' }
     #
    ,_sysdateFormat      => 'YYYYMMDD_HH24MISS'
    ,_DateFormat         => 'YYYY.MM.DD'
    ,_DateSep            => '.'
    ,_DateTimeSep        => ' '
    ,_TimeSep            => ':'
    ,_TimeFormat         => 'HH24:MI:SS'
    ,_DateTimeFormat     => 'YYYY.MM.DD HH24:MI:SS'
#******************************************************************************************
# COPY START FOR CORE PRINT AND STATS PACKAGES
#******************************************************************************************
#     # Statistics Array
#    ,_StatsCnt           => 0
#    ,_STATS              => { }  # Summary statistics
#     # Print Buffer for Uprint
#    ,_PrintBuf           => ''
#    ,_bBuffer            => 0    # 1 - print to _PrintBuf, 0 - print to STDOUT
#     # Optimization Settings
#    ,_bShowStats         => 1    # Show Statistics data
#    ,_bLogStats          => 1    # Log the statistics (usually for batch jobs, but possibly for OnLine)
#    ,_bShowOutput        => 1    # Show Processing Output Messages; This would be set 0 for interactive
#******************************************************************************************
# END COPY
#******************************************************************************************
  };

  # Bless makes these variables available externally
  bless $self, $class;

  return $self;
} #new #CoreUtils


#******************************************************************************************
# Return true to show package was loaded with
# use Core::Utils;
#******************************************************************************************
1;

#END Core::Utils
