#!/usr/bin/perl
# Version 6.1.6.0      30-May-2021
#*******************************************************************************
#
# page.pl
#
# - Just simply calls Orbit ShowPage
#
#*******************************************************************************
# URL Syntax:
#   http://localhost/cgi-bin/showpage.pl?word=CityName&root=LOCS&domain=earth.love&page=SHOWCITY
# Shorthand:          http://localhost/cgi-bin/showpage.pl?w=CityName&r=LOCS&d=earth.love&p=SHOWCITY
#*******************************************************************************
# History:
#   2021.05.30 earth.love oK Updated
#   2021.04.23 earth.love oK Created
#*******************************************************************************
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
#*******************************************************************************
use strict;
use warnings;
use utf8;
use feature ':5.16';

# Use current directory to pick up other packages
use lib qw( ./lib ../lib );
use Orbit;
# Initialize Orbit, the big oh $O
my $O = Orbit->new();

#
# Show the OML page
#
$O->ShowPage();


exit 0;
