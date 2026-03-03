#!/usr/bin/perl
# Version 6.7.1.0      17-Jun-2021
#*****************************************************************************************
#*
#*  Package Name    :   Core::File
#*
#*  Description     :   This package contains utility functions and procedures for supporting Orbit for Perl
#*
#*****************************************************************************************
# History:
#   2021.06.17 earth.love oK Refactored package for performance
#   2022.10.1  earth.love oK Added GetFile support for Linux and Mac EOL
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
# GetFile <filename> <silent_mode>
#   - Returns the contents of the file as a string with carriage returns
#   - Expects a fully qualified or relative filename (with directory prefix)
#
#*****************************************************************************************
package CoreUtils;

use strict;
use warnings;
use utf8;
use feature ':5.16';

use Core::Local::Print;

#******************************************************************************************
#
# GetFile <filename> <silent_mode>
#
# - Returns the contents of the file as a string with carriage returns
# - Expects a fully qualified or relative filename (with directory prefix)
#
#******************************************************************************************
sub CoreUtils::GetFile
{
  my ( $self, $lFile, $bSilent ) = @_;
  my $lContents="";

  $bSilent = 0 if (!defined($bSilent) || $bSilent ne '1');

  # Simple check for all parameters present
  if (!defined($lFile) || $lFile eq "") {
    $lFile = "";
    if (!$bSilent) {
      $self->Uprint("Error: File not passed to GetFile [$lFile]\n");
      return "";
    } else {
      return "Error: File not passed to GetFile [$lFile]\n";
    }
  }

  # See if the datafile exists
  if (!-e $lFile) {
    # No  file by this name - return empty string
    if (!$bSilent) {
      $self->Uprint("GetFile: File not found: [$lFile]\n");
      return "";
    } else {
      return "GetFile: File not found: [$lFile]\n";
    }
  }

  #
  # Open the file and read the contents
  #
  # NOTE: Future development for limiting records read
  #
#  open(DFILE, '<', $lFile)   # UTF-8 Fix
  open(DFILE, '<:encoding(UTF-8)', $lFile)
    or die "GetFile: File not found during open: [$lFile]\n";
  while (<DFILE>) {
    # 10.1.2022 oK Unix/Mac Support
    # Convert CRLF to \n for Unix
    $_ =~ s/\r\n/\n/g;
    # Convert CR to \n for MacOS
    $_ =~ s/\r/\n/g;
    $lContents .= $_;
  }
  close(DFILE);

  # Return the RAW text from the file
  return $lContents;
} #GetFile


#******************************************************************************************
# Return true to show package was loaded with
# use Core::File;
#******************************************************************************************
1;

#END Core::File
