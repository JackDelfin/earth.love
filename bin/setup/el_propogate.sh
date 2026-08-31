#!/bin/bash
set -euo pipefail
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
cd "$SCRIPTPATH/.."

# Ask the running Perl for its configured site-library path instead of tying
# deployment to the Perl version that happened to ship with one distribution.
PERLSITELIB="$(/usr/bin/perl -MConfig -e 'print $Config{sitelib}')"
if [ -z "$PERLSITELIB" ] || [ "${PERLSITELIB#/}" = "$PERLSITELIB" ]; then
  echo "Unable to determine an absolute Perl site-library path." >&2
  exit 1
fi

echo
echo '--'
echo '-- Install Akashic / Orbit for Perl'
echo '--'
echo "--   sudo tools/PROPOGATE_earthlove.pl    $PERLSITELIB"
echo '--'
sudo install -d -m 0755 -- "$PERLSITELIB"
sudo "$SCRIPTPATH/../tools/PROPOGATE_earthlove.pl" "$PERLSITELIB"
# Every initialized Orbit domain configured as an Apache vhost receives the
# current security-sensitive templates.  The sync command deduplicates HTTP /
# HTTPS configs and fails this propagation if an attempted update fails.
if ! sudo "$SCRIPTPATH/el_sync_auth_templates.sh" --all; then
  echo "Authentication template synchronization failed; propagation is incomplete." >&2
  exit 1
fi
