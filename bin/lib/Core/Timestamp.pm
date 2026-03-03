#!/usr/bin/perl
# Version 6.7.1.0      17-Jun-2021
#*****************************************************************************************
#*
#*  Package Name    :   Core:Timestamp
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
# gmt_sysdate
#   - Returns the GMT datetime - uses GMT Greenwich Mean Time gmtime()
#
# sysdate
#   - Returns the local server datetime - uses localtime()
#
# CompareDates <DateExpression> <Timestamp>
#   - Returns -1 if the DateExpression is LESS than the FullTimestamp
#   - Returns 1 if the DateExpression is GREATER than the FullTimestamp
#   - Returns 0 if the DateExpression is EQUAL to the FullTimestamp
#   - Wildcards are specified as YYYY MM DD HH MI SS - HH is in 24-Hour format
#   - Timestamp defaults to current Timestamp
#
#*****************************************************************************************
package CoreUtils;

use strict;
use warnings;
use utf8;
use feature ':5.16';


#******************************************************************************************
# Timestamp
#
# - Returns a timestamp formatted string for Transaction processing
#******************************************************************************************/
sub CoreUtils::Timestamp
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
#* gmt_sysdate
#*
#* - Returns the GMT datetime - uses GMT Greenwich Mean Time gmtime()
#******************************************************************************************/
sub CoreUtils::gmt_sysdate
{
  my ( $self ) = @_;

  # Return standardized time in GMT - Greenwich Mean Time
  my ( $Sec,$Min,$Hour, $MonthDay,$Month,$Year, $WeekDay,$YearDay,$IsDST) = gmtime();
  my $sysdate = "";
  $sysdate = sprintf("%d".$self->{_DateSep}."%02d".$self->{_DateSep}."%02d"
                    .$self->{_DateTimeSep}
                    ."%02d".$self->{_TimeSep}."%02d".$self->{_TimeSep}."%02d"
                    ,$Year+1900, $Month+1, $MonthDay
                    ,$Hour, $Min, $Sec);

  return $sysdate;
} #gmt_sysdate


#******************************************************************************************
#* sysdate
#*
#* - Returns the local server datetime - uses localtime()
#******************************************************************************************/
sub CoreUtils::sysdate
{
  my ( $self ) = @_;
  my $sysdate = "";

  my ( $Sec,$Min,$Hour, $MonthDay,$Month,$Year, $WeekDay,$YearDay,$IsDST) = localtime();
  $sysdate = sprintf("%d".$self->{_DateSep}."%02d".$self->{_DateSep}."%02d"
                    .$self->{_DateTimeSep}
                    ."%02d".$self->{_TimeSep}."%02d".$self->{_TimeSep}."%02d"
                    ,$Year+1900, $Month+1, $MonthDay
                    ,$Hour, $Min, $Sec);

  #$sysdate = sprintf("%d".$self->{_DateSep}."%02d".$self->{_DateSep}."%02d"
  #                  .$self->{_DateTimeSep}
  #                  ."%02d".$self->{_TimeSep}."%02d".$self->{_TimeSep}."%02d"
  #                  ,localtime->year()+1900, localtime->mon()+1, localtime->mday()
  #                  ,localtime->hour(), localtime->min(), localtime->sec());

  return $sysdate;
} #sysdate


#******************************************************************************************
# CompareDates <DateExpression> <Timestamp>
#   - Returns -1 if the DateExpression is LESS than the FullTimestamp
#   - Returns 1 if the DateExpression is GREATER than the FullTimestamp
#   - Returns 0 if the DateExpression is EQUAL to the FullTimestamp
#   - Wildcards are specified as YYYY MM DD HH MI SS - HH is in 24-Hour format
#   - Timestamp defaults to current Timestamp
#******************************************************************************************/
sub CoreUtils::CompareDates
{
  my ( $self, $DateExp, $Timestamp ) = @_;

  # Timestaq
  $Timestamp = $self->Timestamp() if (!defined($Timestamp) || $Timestamp eq '');
  
  my $sub = "";
  
  # Sub out any wildcards
  if ($DateExp =~ /.*YYYY.*/) {   # Year
    $sub = substr($Timestamp, 0, 4);
    $DateExp = s/YYYY/$sub/;
  }
  if ($DateExp =~ /.*MM.*/) {     # Month
    $sub = substr($Timestamp, 4, 2);
    $DateExp = s/MM/$sub/;
  }
  if ($DateExp =~ /.*DD.*/) {     # Day
    $sub = substr($Timestamp, 6, 2);
    $DateExp = s/DD/$sub/;
  }
  if ($DateExp =~ /.*HH.*/) {     # Hour
    $sub = substr($Timestamp, 8, 2);
    $DateExp = s/HH/$sub/;
  }
  if ($DateExp =~ /.*MI.*/) {     # Minute
    $sub = substr($Timestamp, 10, 2);
    $DateExp = s/MI/$sub/;
  }
  if ($DateExp =~ /.*SS.*/) {     # Second
    $sub = substr($Timestamp, 12, 2);
    $DateExp = s/SS/$sub/;
  }
  
  return -1 if ($DateExp lt $Timestamp);
  return 1  if ($DateExp gt $Timestamp);
  return 0  if ($DateExp eq $Timestamp);
  # Bad comparison - return null	
  return "";
} #CompareDates


#******************************************************************************************
# Return true to show package was loaded with
# use Core:Timestamp;
#******************************************************************************************
1;

#END Core:Timestamp
