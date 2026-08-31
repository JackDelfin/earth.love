#!/usr/bin/perl
# Version 1.0.0.0      20-Aug-2026
#*******************************************************************************
#
# elsettings.pl - Orbit Version 7 account settings
#
#*******************************************************************************
# Copyright 2026 Kevin Runner / Runchero Federation / PISA
#*******************************************************************************
# License: AGPLv3+: GNU Affero General Public License Version 3 or later
#*******************************************************************************
use strict;
use warnings;
use utf8;
use feature ':5.16';

# Use current directory to pick up other packages
use lib qw( ./lib ../lib );
use Orbit::Orbit7;

$CGI::POST_MAX = 1536 * 1024;
$CGI::DISABLE_UPLOADS = 0;

my $O = Orbit->new();
$O->HandleSettings();

exit 0;
