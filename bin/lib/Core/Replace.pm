#!/usr/bin/perl
# Version 6.7.1.0      17-Jun-2021
#*****************************************************************************************
#*
#*  Package Name    :   Core::Replace
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
# Replace
#   - Replaces First occurance of Find with Replace in Text
#     Uses index and substr to avoid unwanted REGEX characters in text ([]\)affecting replacement
#
# ReplaceAll
#   - Replaces ALL occurances of Find with Replace in Text
#
# iReplace
#   - Replaces Find with Replace case insensitive for first occurance ONLY
#
# iReplaceAll
#   - Replaces Find with Replace case insensitive for all occurances (g)
#
#*****************************************************************************************
package CoreUtils;

use strict;
use warnings;
use utf8;
use feature ':5.16';


#******************************************************************************************
#* Replace
#*
#* - Replaces First occurance of Find with Replace in Text
#*                      Uses index and substr to avoid unwanted REGEX characters in text ([]\)affecting replacement
#******************************************************************************************
sub CoreUtils::Replace
{
  my ( $self, $Text, $Find, $Replace ) = @_;

  return '' if (!defined($Text) || $Text eq '');
  return $Text if (!defined($Find) || $Find eq '');
  $Replace = '' if (!defined($Replace));

  # Replace only first occurance
  my $s = index($Text, $Find);
  return $Text if ($s == -1);

  # Rebuild Text and return it
  $Text = substr($Text, 0, $s).$Replace.substr($Text, $s+length($Find));

  return $Text;
} #Replace


#******************************************************************************************
#* ReplaceAll
#*
#* - Replaces ALL occurances of Find with Replace in Text
#******************************************************************************************
sub CoreUtils::ReplaceAll
{
  my ( $self, $Text, $Find, $Replace ) = @_;

  return '' if (!defined($Text) || $Text eq '');
  return $Text if (!defined($Find) || $Find eq '');
  $Replace = '' if (!defined($Replace) || $Replace eq '');

  # Replace all occurances
  $Text =~ s/$Find/$Replace/g;

  return $Text;
} #ReplaceAll


#******************************************************************************************
#* iReplace
#*
#* - Replaces Find with Replace case insensitive for first occurance ONLY
#******************************************************************************************
sub CoreUtils::iReplace
{
  my ( $self, $Text, $Find, $Replace ) = @_;


  return '' if (!defined($Text) || $Text eq '');
  return $Text if (!defined($Find) || $Find eq '');
  $Replace = '' if (!defined($Replace));

  $Text =~ s/$Find/$Replace/i;

  return $Text;
} #iReplace


#******************************************************************************************
#* iReplaceAll
#*
#* - Replaces Find with Replace case insensitive for all occurances (g)
#******************************************************************************************
sub CoreUtils::iReplaceAll
{
  my ( $self, $Text, $Find, $Replace ) = @_;


  return '' if (!defined($Text) || $Text eq '');
  return $Text if (!defined($Find) || $Find eq '');
  $Replace = '' if (!defined($Replace));

  $Text =~ s/$Find/$Replace/ig;

  return $Text;
} #iReplaceAll


#******************************************************************************************
# Return true to show package was loaded with
# use Core::Replace;
#******************************************************************************************
1;

#END Core::Replace
