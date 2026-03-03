#!/usr/bin/perl
# Version 6.7.1.0      17-Jun-2021
#*****************************************************************************************
#*
#*  Package Name    :   Core::Distance
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
# Get_Distance <lat,long> <lat,long>
#   - Returns the distance between the 2 lat,long pairs in MILES, unless kmFlag=1
#
# Get_Bearing <lat,long> <lat,long> <Directional>
#   - Returns the bearing (direction) between the 2 lat,long pairs in 360 degrees
#   - Directional = 1 returns general N S E W NE NW SE SW directionals instead of degrees
#
# Get_Directional <bearing> <variance def:20>
#   - Returns the textual bearing based on a 360 degree numeric bearing
#     i.e. N NE E SE S SW W NW
#   - fn_bearing should be between 0 and 360
#   - fn_variance specifies the variance on each side of N S E W which
#     should still be considered in that direction
#     i.e. if fn_variance = 10,
#          a bearing of 350 to 10 would be N
#          a bearing of 15 would be NE
#          a bearing of 35 to 55 would be E
#   - fn_variance must be between 0 and 90
#
#*****************************************************************************************
package CoreUtils;

use strict;
use warnings;
use utf8;
use feature ':5.16';

use Math::Trig;

################################################################################
#
# Get_Distance <lat,long> <lat,long>
#
# - Returns the distance between the 2 lat,long pairs in MILES, unless kmFlag=1
#
################################################################################
sub CoreUtils::Get_Distance
{
  my ($self, $geo1, $geo2, $kmFlag ) = @_;

  $kmFlag = 0 if (!defined($kmFlag) || $kmFlag ne '1');

  my ($lat1,$long1) = split(',', $geo1);
  my ($lat2,$long2) = split(',', $geo2);

  # Convert from degrees to radian
  $lat1  = deg2rad($lat1);
  $long1 = deg2rad($long1);
  $lat2  = deg2rad($lat2);
  $long2 = deg2rad($long2);

  #  D = 3959arccos[sin(Lat1)sin(Lat2) + cos(Lat1)cos(Lat2)cos(Lg2-Lg1)]
  my $D = 3959 * acos( sin($lat1)*sin($lat2) + cos($lat1)*cos($lat2)*cos($long2-$long1) );

  # Return Kilometers if specified
  $D = 1.6 * $D  if ($kmFlag);

  return $D;
} #Get_Distance


################################################################################
#
# Get_Bearing <lat,long> <lat,long> <Directional>
#
# - Returns the bearing (direction) between the 2 lat,long pairs in 360 degrees
# - Directional = 1 returns general N S E W NE NW SE SW directionals instead of degrees
#
################################################################################
sub CoreUtils::Get_Bearing
{
  my ($self, $geo1, $geo2, $directional ) = @_;

  my ($lat1,$long1) = split(',', $geo1);
  my ($lat2,$long2) = split(',', $geo2);

  $directional = 0 if (!defined($directional) || $directional ne '1');

  # Convert from degrees to radian
  $lat1  = deg2rad($lat1);
  $long1 = deg2rad($long1);
  $lat2  = deg2rad($lat2);
  $long2 = deg2rad($long2);

  # N := sin_lat1 * sin(long2 - long1);
  # D := sin(lat2) * cos(lat1) - cos(lat2) * sin_lat1 * cos(long2 - long1);
  # ln_bearing := 57.3 * atan( N / D );
  my $N = sin($lat1)*sin($long2-$long1);
  my $D = sin($lat2)*cos($lat1) - cos($lat2)*sin($lat1)*cos($long2-$long1);

  my $B = rad2deg( atan($N/$D) );

  $B += 360 if ($D > 0);
  $B += 180 if ($D < 0);

  $B = $self->mod($B, 360) + 360   if ($B < 0);

  $B = $self->mod($B, 360)         if ($B >= 360);

  if (!$directional) {
    return $B;
  } else {
    return $self->Get_Directional($B);
  }
} #Get_Bearing


################################################################################
#
# Get_Directional <bearing> <variance def:20>
#
# Returns the textual bearing based on a 360 degree numeric bearing
#  i.e. N NE E SE S SW W NW
# - fn_bearing should be between 0 and 360
# - fn_variance specifies the variance on each side of N S E W which
#   should still be considered in that direction
#   i.e. if fn_variance = 10,
#        a bearing of 350 to 10 would be N
#        a bearing of 15 would be NE
#        a bearing of 35 to 55 would be E
# - fn_variance must be between 0 and 90
################################################################################
sub CoreUtils::Get_Directional
{
  my ( $self, $ln_bearing, $ln_variance ) = @_;
  $ln_variance = 20 if (!defined($ln_variance) || $ln_variance eq '');

  return '' if ($ln_bearing eq '');

  #-- Standardize the bearing
  if ($ln_bearing < 0) {
    $ln_bearing = $self->mod($ln_bearing, 360) + 360;
  }
  if ($ln_bearing >= 360) {
    $ln_bearing = $self->mod($ln_bearing, 360);
  }
  #-- Get the textual direction
  #-- North
  if ( ($ln_bearing >= 360-$ln_variance && $ln_bearing <= 360)
     || ($ln_bearing >= 0 && $ln_bearing <= $ln_variance)) {
      return 'N';
  #-- South
  } elsif ($ln_bearing >= 180-$ln_variance && $ln_bearing <= 180+$ln_variance) {
      return 'S';
  #-- East
  } elsif ($ln_bearing >= 90-$ln_variance && $ln_bearing <= 90+$ln_variance) {
      return 'E';
  #-- West
  } elsif ($ln_bearing >= 270-$ln_variance && $ln_bearing <= 270+$ln_variance) {
      return 'W';
  #-- Northeast
  } elsif ($ln_bearing >= 0 && $ln_bearing <= 90) {
      return 'NE';
  #-- Southeast
  } elsif ($ln_bearing >= 90 && $ln_bearing <= 180) {
      return 'SE';
  #-- Northwest
  } elsif ($ln_bearing >= 270 && $ln_bearing <= 360) {
      return 'NW';
  #-- Southwest
  } elsif ($ln_bearing >= 180 && $ln_bearing <= 270) {
      return 'SW';
  }
  return '';
} #Get_Directional


#******************************************************************************************
# Return true to show package was loaded with
# use Core::Distance;
#******************************************************************************************
1;

#END Core::Distance
