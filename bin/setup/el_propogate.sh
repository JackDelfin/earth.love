#!/bin/bash
##########################################
# el_propogate.sh
#
# Propogate the Akashic-Orbit code to
# - Perl system libraries
# - Apache cgi-bin directory
#
# 2024.11.27 oK refactored
# 2022.09.13 oK created
##########################################

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
# Change to bin directory
cd $SCRIPTPATH/..

echo
echo '--'
echo '-- Install Akashic / Orbit for Perl'
echo '--'
echo '--   sudo tools/PROPOGATE_earthlove.pl    /usr/local/share/perl/5.38.2'
echo '--'
sudo $SCRIPTPATH/../tools/PROPOGATE_earthlove.pl    /usr/local/share/perl/5.38.2

echo
echo '--'
echo '-- Set execute on files in cgi-bin'
echo '--'
sudo chmod +x /usr/lib/cgi-bin/*

