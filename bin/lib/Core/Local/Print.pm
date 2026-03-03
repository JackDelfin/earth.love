#!/usr/bin/perl
# Version 6.7.1.0      17-Jun-2021
#*****************************************************************************************
#*
#*  Package Name    :   Core::Print
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
# PRINT UTILITIES
#----------------------------------------#
#
# Uprint
#   - Print the text to the Print Buffer or standard out, based on _bBuffer (1/0)
#
# GetUprintBuf
#   - Get the results of the print buffer and reset buffer to null
#
# BufUprint
#   - Set the print buffer option (1/0); 1 - buffer; 0 - print
#
# GetShowOutput
#   - Returns the Show Output indicator 1/0
#
# SetShowOutput <1/0>
#   - Turns Output Display on/off
#
#*****************************************************************************************
package CoreUtils;

use strict;
use warnings;
use utf8;
use feature ':5.16';


#******************************************************************************************
#
# Uprint
#
# - Print the text to the Print Buffer or standard out, based on _bBuffer (1/0)
#
#******************************************************************************************/
sub CoreUtils::Uprint {
  my ($self, $text) = @_;
  return "" if (!defined($text) || $text eq "");
  if ($self->{_bBuffer}) {
    $self->{_PrintBuf} .= $text;
  } else {
    # Check for the SHOW OUTPUT  directive
    print $text if ($self->{_bShowOutput});
  }
} #Uprint


#******************************************************************************************
#
# GetUprintBuf
#
# - Get the results of the print buffer and reset buffer to null
#
#******************************************************************************************/
sub CoreUtils::GetUprintBuf {
  my ($self) = @_;
  my $text = $self->{_PrintBuf};
  $self->{_PrintBuf} = '';
  return $text;
} #GetUprintBuf


#******************************************************************************************
#
# BufUprint
#
# - Set the print buffer option (1/0); 1 - buffer; 0 - print
#
#******************************************************************************************/
sub CoreUtils::BufUprint {
  my ($self, $bBuf) = @_;
  $bBuf = 0 if (!defined($bBuf) || $bBuf ne '1');
  $self->{_bBuffer} = $bBuf;
} #BufUprint


#******************************************************************************************/
# GetShowOutput
#
# - Returns the Show Output indicator 1/0
#******************************************************************************************/
sub CoreUtils::GetShowOutput {
  my ($self) = @_;
  return $self->{_bShowOutput};
} #SetShowOutput


#******************************************************************************************/
# SetShowOutput <1/0>
#
# - Turns Output Display on/off
#******************************************************************************************/
sub CoreUtils::SetShowOutput {
  my ($self, $switch) = @_;
  $switch = 0 if (!defined($switch) || $switch ne '1');
  $self->{_bShowOutput} = $switch;
} #SetShowOutput


#******************************************************************************************
# Return true to show package was loaded with
# use Core::Print;
#******************************************************************************************
1;

#END Core::Print
