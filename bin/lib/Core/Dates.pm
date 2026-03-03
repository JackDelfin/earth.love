#!/usr/bin/perl
# Version 6.7.1.0      17-Jun-2021
#*****************************************************************************************
#*
#*  Package Name    :   Core::Dates
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
# DATE / TIME UTILITIES
#----------------------------------------#
#
# Get_Date <format> <TimeZone> <bGMT>
#   - #DATE[format][timezone][bGMT(0/1)]#
#   - Returns the current DATE ONLY with decorations based on timezone,
#   - in GMT (1) or server time (0)
#   - optional format for YYYY.YY.MM DD Y1/M1/D1 MON MONTH DAY DY (mixed case applies)
#
# Get_Time <format> <TimeZone> <bGMT>
#   - #TIME[format][timezone][bGMT(0/1)]#
#   - Returns the current DATE ONLY with decorations based on timezone,
#   - in GMT (1) or server time (0)
#   - optional format for HH24 HH:MI:SS H1:MIN:SEC S1 AM PM HOUR Hour (mixed case applies)
#
# FormatDateTime <time elements> - used internally
#   - Format the Date and Time strings based on following format masks
#   - Date format masks: YYYY.YY.MM DD Y1/M1/D1 MON MONTH DAY DY (mixed case applies)
#   - Time format masks: HH24 H24 HH:MI:SS H1:MIN:SEC S1 AM PM HOUR Hour (mixed case applies)
#
# TimeDiffHMS <starttime> <endtime>
#   - Returns the Hours:Minutes:Seconds based on the time difference in seconds
#   - Use standard time() to get start and end
# GetHours <starttime> <endtime> <Round specification>
#   - Returns the number of Hours based on the time difference in seconds, rounded to Round specification
# GetMinutes <starttime> <endtime> <Round specification>
#   - Returns the number of Minutes based on the time difference in seconds, rounded to Round specification
# GetSeconds <starttime> <endtime>
#   - Returns the number of Seconds based on the time difference in seconds, rounded to Round specification
#
#*****************************************************************************************
package CoreUtils;

use strict;
use warnings;
use utf8;
use feature ':5.16';


#******************************************************************************************
#
# Get_Date <format> <TimeZone> <bGMT>
#
# - #DATE[format][timezone][bGMT(0/1)]#
# - Returns the current DATE ONLY with decorations based on timezone,
# - in GMT (1) or server time (0)
# - optional format for YYYY.YY.MM DD Y1/M1/D1 MON MONTH DAY DY (mixed case applies)
#******************************************************************************************/
sub CoreUtils::Get_Date
{
  my ( $self, $Format, $TZ, $bGMT ) = @_;

  my ( $Sec,$Min,$Hour, $MonthDay,$Month,$Year, $WeekDay,$YearDay,$IsDST );

  $Format = $self->{_DateFormat} if (!defined($Format) || $Format eq "");
  $TZ = "" if (!defined($TZ));
  $bGMT = 0 if (!defined($bGMT) || $bGMT ne '1');

  if ($bGMT) {
    ( $Sec,$Min,$Hour, $MonthDay,$Month,$Year, $WeekDay,$YearDay,$IsDST) = gmtime();
  } else {
    ( $Sec,$Min,$Hour, $MonthDay,$Month,$Year, $WeekDay,$YearDay,$IsDST) = localtime();
  }

  $Format = $self->FormatDateTime( $Format, $Sec,$Min,$Hour, $MonthDay,$Month,$Year, $WeekDay,$YearDay,$IsDST );

  return $Format;

} #Get_Date


#******************************************************************************************
#
# Get_Time <format> <TimeZone> <bGMT>
#
# - #TIME[format][timezone][bGMT(0/1)]#
# - Returns the current DATE ONLY with decorations based on timezone,
# - in GMT (1) or server time (0)
# - optional format for HH24 HH:MI:SS H1:MIN:SEC S1 AM PM HOUR Hour (mixed case applies)
#******************************************************************************************/
sub CoreUtils::Get_Time
{
  my ( $self, $Format, $TZ, $bGMT ) = @_;

  my ( $Sec,$Min,$Hour, $MonthDay,$Month,$Year, $WeekDay,$YearDay,$IsDST );

  $Format = $self->{_TimeFormat} if (!defined($Format) || $Format eq "");
  $TZ = "" if (!defined($TZ));
  $bGMT = 0 if (!defined($bGMT) || $bGMT ne '1');

  if ($bGMT) {
    ( $Sec,$Min,$Hour, $MonthDay,$Month,$Year, $WeekDay,$YearDay,$IsDST) = gmtime();
  } else {
    ( $Sec,$Min,$Hour, $MonthDay,$Month,$Year, $WeekDay,$YearDay,$IsDST) = localtime();
  }

  $Format = $self->FormatDateTime( $Format, $Sec,$Min,$Hour, $MonthDay,$Month,$Year, $WeekDay,$YearDay,$IsDST );

  return $Format;

} #Get_Time


#******************************************************************************************
#
# FormatDateTime <time elements> - used internally
#
# - Format the Date and Time strings based on following format masks
# - Date format masks: YYYY.YY.MM DD Y1/M1/D1 MON MONTH DAY DY (mixed case applies)
# - Time format masks: HH24 H24 HH:MI:SS H1:MIN:SEC S1 AM PM HOUR Hour (mixed case applies)
#******************************************************************************************/
sub CoreUtils::FormatDateTime
{
  my ( $self, $Format, $Sec,$Min,$Hour, $MonthDay,$Month,$Year, $WeekDay,$YearDay,$IsDST ) = @_;

  $Year+=1900;
  $Month++;
  my $buf = "";

  #
  # YEAR
  if ($Format =~ /^.*YYYY.*$/i) {
    $Format =~ s/YYYY/$Year/ig;
  }
  if ($Format =~ /^.*YY.*$/i) {
    my $Year2 = substr($Year, 2, 2);
    $Format =~ s/YY/$Year2/ig;
  }
  if ($Format =~ /^.*Y1.*$/i) {
    my $Year2 = substr($Year, 2, 2);
    $Year2+=0;
    $Format =~ s/Y1/$Year2/ig;
  }
  #
  # MONTH
  if ($Format =~ /^.*MM.*$/i) {
    $buf = sprintf("%02d", $Month);
    $Format =~ s/MM/$buf/ig;
  }
  if ($Format =~ /^.*MONTH.*$/) {
    $buf = $self->upper($self->{_MonthsFull}->{$Month-1});
    $Format =~ s/MONTH/$buf/g;
  }
  if ($Format =~ /^.*month.*$/) {
    $buf = $self->lower($self->{_MonthsFull}->{$Month-1});
    $Format =~ s/month/$buf/g;
  }
  if ($Format =~ /^.*Month.*$/) {
    $buf = $self->initcap($self->{_MonthsFull}->{$Month-1});
    $Format =~ s/Month/$buf/g;
  }
  if ($Format =~ /^.*MON.*$/) {
    $buf = $self->upper($self->{_Months}->{$Month-1});
    $Format =~ s/MON/$buf/g;
  }
  if ($Format =~ /^.*mon.*$/) {
    $buf = $self->lower($self->{_Months}->{$Month-1});
    $Format =~ s/mon/$buf/g;
  }
  if ($Format =~ /^.*Mon.*$/) {
    $buf = $self->initcap($self->{_Months}->{$Month-1});
    $Format =~ s/Mon/$buf/g;
  }
  if ($Format =~ /^.*M1.*$/i) {
    $Format =~ s/M1/$Month/ig;
  }

  #
  # DAY
  if ($Format =~ /^.*DD.*$/i) {
    $buf = sprintf("%02d", $MonthDay);
    $Format =~ s/DD/$buf/ig;
  }
  if ($Format =~ /^.*DY.*$/) {
    $buf = $self->upper($self->{_Days}->{$WeekDay});
    $Format =~ s/DY/$buf/g;
  }
  if ($Format =~ /^.*dy.*$/) {
    $buf = $self->lower($self->{_Days}->{$WeekDay});
    $Format =~ s/dy/$buf/g;
  }
  if ($Format =~ /^.*Dy.*$/) {
    $buf = $self->initcap($self->{_Days}->{$WeekDay});
    $Format =~ s/Dy/$buf/g;
  }
  if ($Format =~ /^.*DAY.*$/) {
    $buf = $self->upper($self->{_DaysFull}->{$WeekDay});
    $Format =~ s/DAY/$buf/g;
  }
  if ($Format =~ /^.*day.*$/) {
    $buf = $self->lower($self->{_DaysFull}->{$WeekDay});
    $Format =~ s/day/$buf/g;
  }
  if ($Format =~ /^.*Day.*$/) {
    $buf = $self->initcap($self->{_DaysFull}->{$WeekDay});
    $Format =~ s/Day/$buf/g;
  }
  if ($Format =~ /^.*D1.*$/i) {
    $Format =~ s/D1/$MonthDay/ig;
  }

  #
  # HOUR
  if ($Format =~ /^.*HH24.*$/i) {
    $buf = sprintf("%02d", $Hour);
    $Format =~ s/HH24/$buf/ig;
  }
  if ($Format =~ /^.*H24.*$/i) {
    $Format =~ s/H24/$Hour/ig;
  }
  if ($Format =~ /^.*HOUR.*$/) {   # Military Hour spelled out
    $buf = $Hour;
    $buf = 24 if ($Hour == 0);
    $buf = $self->{_Hours}->{$buf-1};
    $Format =~ s/HOUR/$buf/g;
  }
  if ($Format =~ /^.*Hour.*$/i) {   # 12 hour clock Hour spelled out
    $buf = $Hour;
    $buf = 12 if ($Hour == 0);
    $buf = $self->{_Hours}->{$buf-1};
    $Format =~ s/Hour/$buf/ig;
  }
  if ($Format =~ /^.*HH.*$/i) {
    $buf = $Hour;
    $buf = 12 if ($Hour == 0);
    $buf = $buf-12 if ($Hour > 12);
    $buf = sprintf("%02d", $buf);
    $Format =~ s/HH/$buf/ig;
  }
  if ($Format =~ /^.*H1.*$/i) {
    $buf = $Hour;
    $buf -= 12 if ($Hour > 12);
    $Format =~ s/H1/$buf/ig;
  }
  #
  # MINUTES
  if ($Format =~ /^.*MIN.*$/i) {
    $Format =~ s/MIN/$Min/ig;
  }
  if ($Format =~ /^.*MI.*$/i) {
    $buf = sprintf("%02d", $Min);
    $Format =~ s/MI/$buf/ig;
  }
  if ($Format =~ /^.*M1.*$/i) {
    $Format =~ s/MIN/$Min/ig;
  }
  #
  # SECONDS
  if ($Format =~ /^.*SS.*$/i) {
    $buf = sprintf("%02d", $Sec);
    $Format =~ s/SS/$buf/ig;
  }
  if ($Format =~ /^.*SEC.*$/i) {
    $buf = $Sec;
    $Format =~ s/SEC/$buf/ig;
  }
  if ($Format =~ /^.*S1.*$/i) {
    $buf = $Sec;
    $Format =~ s/S1/$buf/ig;
  }
  #
  # AM PM
  if ($Format =~ /^.*AM.*$/) {
    $buf = "";
    $buf = 'AM' if ($Hour < 12);
    $Format =~ s/AM/$buf/ig;
  }
  if ($Format =~ /^.*am.*$/i) {
    $buf = "";
    $buf = 'am' if ($Hour < 12);
    $Format =~ s/am/$buf/ig;
  }
  if ($Format =~ /^.*PM.*$/) {
    $buf = "";
    $buf = 'PM' if ($Hour < 12);
    $Format =~ s/PM/$buf/ig;
  }
  if ($Format =~ /^.*pm.*$/i) {
    $buf = "";
    $buf = 'pm' if ($Hour > 12);
    $Format =~ s/pm/$buf/ig;
  }

  return $Format;
} #FormatDateTime


#*******************************************************************************
#
# TimeDiffHMS <starttime> <endtime>
#
# - Returns the Hours:Minutes:Seconds based on the time difference in seconds
# - Use standard time() to get start and end
#
#*******************************************************************************
sub CoreUtils::TimeDiffHMS
{
  my ( $self, $starttime, $endtime ) = @_;
  my $SECdiff = $endtime - $starttime;
  my $HMS = sprintf("%d:%02d:%02d"
              ,int($SECdiff/60/60)   # Hours
              ,int(($SECdiff - int($SECdiff/60/60)*60*60) / 60)    # Minutes
              ,$SECdiff   # Seconds - Hours - Minutes
                 - int($SECdiff/60/60)*60*60   # Horus
                 - int(($SECdiff - int($SECdiff/60/60)*60*60) / 60)*60    # Minutes
            );
  return $HMS;
} #TimeDiffHMS


#*******************************************************************************
# GetHours <starttime> <endtime> <Round specification>
#   - Returns the number of Hours based on the time difference in seconds, rounded to Round specification
#*******************************************************************************
sub CoreUtils::GetHours
{
  my ( $self, $starttime, $endtime, $Round ) = @_;
  use Core::Math::Round;
  $Round = 1 if (!defined($Round) || $Round eq '');
  my $SECdiff = $endtime - $starttime;
  my $Hours   = $SECdiff/60/60;   # Hours
  return $self->round($Hours, $Round);
} #GetHours


#*******************************************************************************
# GetMinutes <starttime> <endtime> <Round specification>
#   - Returns the number of Minutes based on the time difference in seconds, rounded to Round specification
#*******************************************************************************
sub CoreUtils::GetMinutes
{
  my ( $self, $starttime, $endtime, $Round ) = @_;
  use Core::Math::Round;
  $Round = 1 if (!defined($Round) || $Round eq '');
  my $SECdiff = $endtime - $starttime;
  my $Minutes = $SECdiff / 60;    # Minutes
  return $self->round($Minutes, $Round);
} #GetMinutes


#*******************************************************************************
# GetSeconds <starttime> <endtime>
#   - Returns the number of Seconds based on the time difference in seconds, rounded to Round specification
#*******************************************************************************
sub CoreUtils::GetSeconds
{
  my ( $self, $starttime, $endtime, $Round ) = @_;
  $Round = 1 if (!defined($Round) || $Round eq '');
  my $SECdiff = $endtime - $starttime;
  my $Seconds = $SECdiff;         # Seconds
  return $Seconds;
} #GetSeconds


#******************************************************************************************
#*
#* Is_Date <date_text> <format> <min_date> <max_date>
#*
#* - Returns 1 if the string is a valid date based on the format, 0 if not
#*
#*        Return  Description
#*        ------  -----------------------------------------------------------
#*        NULL    Input date string is NULL
#*        1       Input date string IS a valid date within min and max dates
#*        0       Input date string IS NOT valid because:
#*                * Date does not exist (i.e. 2/31/99)
#*                * Input date string does not match the format mask (01/02 <=> 'MM/DD/YYYY')
#*                * Input date string is not between min date and max date
#******************************************************************************************/
#sub CoreUtils::Is_Date
#{
#  my ( $self, $fv_date_text, $fv_format, $fd_min_date, $fd_max_date ) = @_;
#
#  return "CODE";
#} #Is_Date


#******************************************************************************************
#*
#* ToDate <date_text> <format> <min_date> <max_date>
#*
#* - Returns a valid Oracle Date or NULL if the date string is an invalid date
#*                      based on the date format
#*
#*        Return  Description
#*        ------  -----------------------------------------------------------
#*        DATE    Returns valid date for input date string (based on min and max dates)
#*        NULL    Input date string IS NOT valid because:
#*                * Date does not exist (i.e. 2/31/99)
#*                * input date string does not match the format mask (01/02 <=> 'MM/DD/YYYY')
#*                * input date string is not between min date and max date
#*                * input date string is NULL
#******************************************************************************************/
#sub CoreUtils::ToDate
#{
#  my ( $self, $fv_date_text, $fv_format, $fd_min_date, $fd_max_date ) = @_;
#
#  return "CODE";
#} #ToDate


#******************************************************************************************
#*
#* DateToChar <date_text> <INformat> <OUTformat>
#*
#* - Returns a date formatted to the specified mask - does not raise an exception
#*   Returns standard to_char(date) if the mask is invalid
#******************************************************************************************/
#sub CoreUtils::DateToChar
#{
#  my ( $self, $fv_date, $INformat, $OUTformat ) = @_;
#
#  return "CODE";
#} #DateToChar


#******************************************************************************************
# Return true to show package was loaded with
# use Core::Dates;
#******************************************************************************************
1;

#END Core::Dates
