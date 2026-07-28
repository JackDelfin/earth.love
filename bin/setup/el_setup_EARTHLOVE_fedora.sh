#!/bin/bash
##########################################
# el_setup_EARTHLOVE_fedora.sh
#
# Setup the /LOVE/earth.love directory for Apache
# on Fedora Linux (httpd)
#
# Fedora differences (vs el_setup_EARTHLOVE.sh for Ubuntu/Debian):
#   - Apache config root is /etc/httpd (reached as /etc/apache2
#     through the symlink created by el_setup_BASE_fedora.sh)
#   - ServerName / HostnameLookups handled by /etc/httpd/conf.d/earthlove.conf
#     (installed in BASE) instead of editing apache2.conf
#   - /o/ CGI alias handled by /etc/httpd/conf.d/earthlove-cgi.conf
#     (installed in BASE) instead of editing serve-cgi-bin.conf
#   - vhost_combined LogFormat included in the Fedora
#     other-vhosts-access-log.conf (Debian defines it in apache2.conf)
#   - 000-default.conf must be explicitly enabled (Debian ships it enabled)
#   - restorecon calls to apply the SELinux contexts from BASE
#
# Consider redirecting output from this script to a log record
# ./el_setup_EARTHLOVE_fedora.sh 2>&1 1|tee el_setup_EARTHLOVE_fedora_`date +%Y%m%d_%H%M%S`.out
#
# 2026.07.16 oK created for Fedora
##########################################

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
# Change to bin directory
cd $SCRIPTPATH/..

echo
echo '# -------------------------'
echo '# Earth.Love SETUP'
echo '#    for Apache Web Server'
echo '#    (Fedora Linux)'
echo '#'
echo '#    /LOVE/earth.love/'
echo '#'
echo '# -------------------------'

#
# Check the BASE compatibility layer is in place
#
if [ ! -d /etc/httpd ]; then
  echo 'ERROR: /etc/httpd not found - run el_setup_BASE_fedora.sh first!';
  exit 1;
fi
if [ ! -L /etc/apache2 ] && [ ! -d /etc/apache2 ]; then
  echo 'ERROR: /etc/apache2 symlink not found - run el_setup_BASE_fedora.sh first!';
  exit 1;
fi
if ! getent group www-data >/dev/null; then
  echo 'ERROR: www-data group not found - run el_setup_BASE_fedora.sh first!';
  exit 1;
fi

echo
echo '--'
echo '-- Make /LOVE/earth.love/ for www-data user'
echo '--'
sudo mkdir /LOVE 2>/dev/null
sudo chown www-data:www-data /LOVE
sudo chmod g+w /LOVE

# Future .earth domains go in /LOVE/EARTH/
echo '-- Make /LOVE/EARTH for additional .earth domains';
sudo mkdir /LOVE/EARTH 2>/dev/null
sudo chown www-data:www-data /LOVE/EARTH
sudo chmod g+w /LOVE/EARTH

echo '-- Make the earth.love domain base: /LOVE/earth.love';
sudo mkdir -v /LOVE/earth.love
sudo chown www-data:www-data /LOVE/earth.love
sudo chmod g+w /LOVE/earth.love

echo '-- Make Apache DocumentRoot: /LOVE/earth.love/_WEB'
sudo mkdir -v /LOVE/earth.love/_WEB
sudo chown www-data:www-data /LOVE/earth.love/_WEB
sudo chmod g+w /LOVE/earth.love/_WEB

echo '-- Make Apache _LOGS directory (access/error logs): /LOVE/earth.love/_LOGS'
sudo mkdir -v /LOVE/earth.love/_LOGS
sudo chown www-data:www-data /LOVE/earth.love/_LOGS
sudo chmod g+w /LOVE/earth.love/_LOGS

echo '-- Make _WEB/SITES';
sudo mkdir -v /LOVE/earth.love/_WEB/SITES
sudo chown www-data:www-data /LOVE/earth.love/_WEB/SITES
sudo chmod g+w /LOVE/earth.love/_WEB/SITES

echo '-- Make _WEB/PATCHES';
sudo mkdir -v /LOVE/earth.love/_WEB/PATCHES
sudo chown www-data:www-data /LOVE/earth.love/_WEB/PATCHES
sudo chmod g+w /LOVE/earth.love/_WEB/PATCHES

echo '-- Make _WEB/RELEASE';
sudo mkdir -v /LOVE/earth.love/_WEB/RELEASE
sudo chown www-data:www-data /LOVE/earth.love/_WEB/RELEASE
sudo chmod g+w /LOVE/earth.love/_WEB/RELEASE

echo '-- Make _WEB/UPS';
sudo mkdir -v /LOVE/earth.love/_WEB/UPS
sudo chown www-data:www-data /LOVE/earth.love/_WEB/UPS
sudo chmod g+w /LOVE/earth.love/_WEB/UPS

echo '-- Make _WEB/DOWN';
sudo mkdir -v /LOVE/earth.love/_WEB/DOWN
sudo chown www-data:www-data /LOVE/earth.love/_WEB/DOWN
sudo chmod g+w /LOVE/earth.love/_WEB/DOWN

#
# Legacy Installs: Move /earth.love to /LOVE/earth.love
#
if [ -d /earth.love ]; then
echo
echo '--'
echo '-- Move previous version of /earth.love to new /LOVE root'
echo '--'
sudo mv -v /earth.love /LOVE/earth.love_ORIG
fi

echo
echo '--'
echo '-- SETUP Static Stylesheets - /LOVE/earth.love/_WEB/_STYLES'
echo '--'

echo '-- Make _STYLES'
sudo mkdir /LOVE/earth.love/_WEB/_STYLES
sudo cp -puv _TEMPLATES/_STYLES/*.css /LOVE/earth.love/_WEB/_STYLES
sudo chown -R www-data:www-data       /LOVE/earth.love/_WEB/_STYLES
sudo chmod -R g+w                     /LOVE/earth.love/_WEB/_STYLES


echo '--'
echo '-- Propogate the Akashic-Orbit Code to'
echo '-- the Perl and Apache CGI system location'
echo '--'
setup/el_propogate_fedora.sh

echo
echo '# -----------------------------------'
echo '# Apache (httpd) CONFIG'
echo '#   - Web Server'
echo '# -----------------------------------'

echo '--';
echo '-- ServerName and HostnameLookups are set by /etc/httpd/conf.d/earthlove.conf';
echo '--   (installed by el_setup_BASE_fedora.sh)';
echo '--';

echo
echo '--'
echo '-- SETUP start page redirect to /o/page'
echo '--'
sudo cp -puv config/start.html /LOVE/earth.love/_WEB/index.html
echo '-- Setup robots.txt';
sudo cp -puv config/robots.txt /LOVE/earth.love/_WEB/
echo '-- Setup Rewrite rules for BOTs and HACKers: accessBOT.log accessHACK.log';
sudo cp -puv config/elRewrite.conf /etc/httpd/
echo '-- Setup Virtual Hosts logs when not defined within vhost config: /LOVE/earth.love/_LOGS';
echo '-- (Fedora version defines the vhost_combined LogFormat - enable with a2enconf)';
sudo cp -puv setup/fedora/other-vhosts-access-log.conf /etc/httpd/conf-available
sudo a2enconf other-vhosts-access-log

echo
echo '--'
echo '-- SETUP earth.love Virtual Host (HTTP + local HTTPS)'
echo '--'
sudo cp -puv config/000-default.conf /etc/httpd/sites-available
sudo cp -puv config/000-default-ssl.conf /etc/httpd/sites-available
sudo cp -puv config/earth.love.conf /etc/httpd/sites-available
sudo cp -puv config/earth.love-ssl.conf /etc/httpd/sites-available

echo
echo '--'
echo '-- Enable the earth.love Virtual Hosts'
echo '-- (000-default.conf ships enabled on Debian - enable it here too)'
echo '-- Local SSL uses the Fedora self-signed localhost cert until'
echo '-- elSETUP_DOM.pl / certbot issues a real certificate.'
echo '--'
sudo a2ensite 000-default.conf
sudo a2ensite 000-default-ssl.conf
sudo a2ensite earth.love.conf
sudo a2ensite earth.love-ssl.conf

# Disable stock welcome page (403 on bare HTTPS / empty docroot)
if [ -e /etc/httpd/conf.d/welcome.conf ]; then
  echo '-- Disable stock httpd welcome.conf (conflicts with local HTTPS)';
  sudo mv -v /etc/httpd/conf.d/welcome.conf /etc/httpd/conf.d/welcome.conf.disabled;
fi

# Point Fedora's stock _default_:443 DocumentRoot at earth.love so
# https://127.0.0.1/ works without a Host: earth.love header.
if [ -f /etc/httpd/conf.d/ssl.conf ] \
   && grep -q '^#DocumentRoot "/var/www/html"' /etc/httpd/conf.d/ssl.conf; then
  echo '-- Set ssl.conf _default_:443 DocumentRoot to /LOVE/earth.love/_WEB';
  sudo sed -i 's|^#DocumentRoot "/var/www/html"|DocumentRoot "/LOVE/earth.love/_WEB"|' \
    /etc/httpd/conf.d/ssl.conf;
fi

echo
echo '--'
echo '-- CGI is served from /o/ by /etc/httpd/conf.d/earthlove-cgi.conf'
echo '--   (installed by el_setup_BASE_fedora.sh)'
echo '--'

echo
echo '--'
echo '-- Install the /ELBIN and /ELDOMS directories'
echo '--'
cd $SCRIPTPATH/../ELBIN
./install_ELBIN.sh

echo
echo '--'
echo '-- Restore SELinux labels on /ELBIN (piped log program for Apache)'
echo '--'
if [ -x /usr/sbin/restorecon ]; then
  sudo /usr/sbin/restorecon -RF /ELBIN 2>/dev/null;
fi

echo
echo '--'
echo '-- Install the SETUP_DOM directories'
echo '--'
cd $SCRIPTPATH/..
cp -pruv SETUP_DOM ~

echo
echo '--'
echo '-- Restore SELinux labels on /LOVE (httpd_sys_rw_content_t)'
echo '--'
if [ -x /usr/sbin/restorecon ]; then
  sudo /usr/sbin/restorecon -RF /LOVE;
fi

echo
echo '-- Test Apache config and Restart'
sudo apachectl configtest
sudo systemctl restart httpd

echo '#########################################'
echo '# /LOVE/earth.love Apache Setup Complete'
echo '#          (Fedora Linux)'
echo '#########################################'
