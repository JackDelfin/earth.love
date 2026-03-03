#!/usr/bin/perl
# Version 7.0.0.0      18-Jun-2021
#******************************************************************************************
#*
#*  Package Name    :   Orbit Version Selector (Chooses the latest stable Orbit version)
#*
#*  Description     :   The Orbit package is the interface to the
#*                      Orbit Web Development Suite for perl
#*
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

# Default to Orbit Version 7
use Orbit::Orbit7;

# Orbit Version 6
#use Orbit::Orbit6::Orbit6;

#******************************************************************************************
# Return true to show package was loaded with
# use Orbit;
#******************************************************************************************
1;


#END Orbit;
