#!/bin/bash
##########################################
# el_propogate_fedora.sh
#
# Propogate the Akashic-Orbit code to
# - Perl system libraries (Fedora site_perl)
# - Apache cgi-bin directory (/var/www/cgi-bin on Fedora)
#
# Fedora differences (vs el_propogate.sh for Ubuntu/Debian):
#   - Perl site library is /usr/local/share/perl5/<version>
#     (detected from perl -V:sitelib instead of hardcoding
#      the Debian /usr/local/share/perl/5.38.2 path)
#   - cgi-bin is /var/www/cgi-bin (PROPOGATE_earthlove.pl
#     auto-detects this - it prefers an existing directory)
#   - restorecon for SELinux labels on the CGI programs
#
# 2026.07.16 oK created for Fedora
##########################################

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
# Change to bin directory
cd $SCRIPTPATH/..

#
# Get the Perl site library from perl itself (ex: /usr/local/share/perl5/5.42)
#
eval `perl -V:sitelib`;
PERLSITELIB="$sitelib";
if [ "$PERLSITELIB" == "" ]; then
  PERLSITELIB="/usr/local/share/perl5";
fi

echo
echo '--'
echo '-- Install Akashic / Orbit for Perl'
echo '--'
echo "--   sudo tools/PROPOGATE_earthlove.pl    $PERLSITELIB"
echo '--'
sudo mkdir -p $PERLSITELIB
sudo mkdir -p /var/www/cgi-bin
sudo $SCRIPTPATH/../tools/PROPOGATE_earthlove.pl    $PERLSITELIB

echo
echo '--'
echo '-- Set execute on files in cgi-bin'
echo '--'
sudo chmod +x /var/www/cgi-bin/*

echo
echo '--'
echo '-- Restore SELinux labels on cgi-bin (httpd_sys_script_exec_t)'
echo '--'
if [ -x /usr/sbin/restorecon ]; then
  sudo /usr/sbin/restorecon -RF /var/www/cgi-bin;
fi
