#!/usr/bin/perl
# Version 6.7.1.0      17-Jun-2021
#*****************************************************************************************
#*
#* Package: Orbit::Core
#*
#* - Loads the BASE Core utilities needed by Orbit
#* - Additonal utility packages will be loaded as needed
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
package Orbit;

use strict;
use warnings;
use utf8;
use feature ':5.16';


#
# Load in all of the Core Utilities
#
# Header Package with new
use Core::Utils;
use Core::File;
use Core::Replace;

use Core::Strings;
use Core::Numbers;
use Core::Timestamp;

use Orbit::Orbit6::Stats;
use Orbit::Orbit6::Print;

# Read as needed
#use Core::Search;
#use Core::Like;
#use Core::Replace;
#use Core::Dates;
#use Core::Timestamp;
#use Core::Math;
#use Core::Math::Ceil;
#use Core::Math::Least;
#use Core::Math::Round;
#use Core::Distance;
#use Core::Fibonacci;
#use Core::HTML;
#use Core::Crypt;


#******************************************************************************************
# Return true to show package was loaded with
# use Orbit::Core;
#******************************************************************************************
1;

#END Orbit::Core
