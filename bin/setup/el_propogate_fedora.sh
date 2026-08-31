#!/bin/bash
set -euo pipefail
##########################################
# el_propogate_fedora.sh
#
# Propogate the Akashic-Orbit code to
# - Perl system libraries (Fedora site_perl)
# - Apache cgi-bin directory (/var/www/cgi-bin on Fedora)
#
# Fedora differences (vs el_propogate.sh for Ubuntu/Debian):
#   - Perl site library is /usr/local/share/perl5/<version>
#     (detected from Perl's Config instead of hardcoding a version)
#   - cgi-bin is /var/www/cgi-bin (PROPOGATE_earthlove.pl
#     auto-detects this - it prefers an existing directory)
#   - restorecon for SELinux labels on the CGI programs
#
# 2026.07.16 oK created for Fedora
##########################################

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
# Change to bin directory
cd "$SCRIPTPATH/.."

#
# Get the Perl site library from perl itself (ex: /usr/local/share/perl5/5.42)
#
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
sudo mkdir -p -- "$PERLSITELIB"
sudo mkdir -p /var/www/cgi-bin
sudo "$SCRIPTPATH/../tools/PROPOGATE_earthlove.pl" "$PERLSITELIB"
# Every initialized Orbit domain configured as an Apache vhost receives the
# current security-sensitive templates.  The sync command deduplicates HTTP /
# HTTPS configs and fails this propagation if an attempted update fails.
if ! sudo "$SCRIPTPATH/el_sync_auth_templates.sh" --all; then
  echo "Authentication template synchronization failed; propagation is incomplete." >&2
  exit 1
fi

echo
echo '--'
echo '-- Restore SELinux labels on cgi-bin (httpd_sys_script_exec_t)'
echo '--'
if [ -x /usr/sbin/restorecon ]; then
  sudo /usr/sbin/restorecon -RF /var/www/cgi-bin;
fi
