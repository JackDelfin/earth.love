#!/bin/bash
##########################################
# el_setup_EARTHLOVE.sh
#
# Setup the /LOVE/earth.love directory for Apache
#
# Consider redirecting output from this script to a log record
# ./el_setup_EARTHLOVE.sh 2>&1 1|tee el_setup_EARTHLOVE_`date +%Y%m%d_%H%M%S`.out
#
# 2024.11.27 oK refactored
# 2022.09.13 oK created
##########################################

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
# Change to bin directory
cd $SCRIPTPATH/..

echo
echo '# -------------------------'
echo '# Earth.Love SETUP'
echo '#    for Apache Web Server'
echo '#'
echo '#    /LOVE/earth.love/'
echo '#'
echo '# -------------------------'

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
setup/el_propogate.sh

echo
echo '# -----------------------------------'
echo '# Apache2 CONFIG'
echo '#   - Web Server'
echo '# -----------------------------------'

echo '--'
echo '-- Edit apache2.conf config:'
echo '--   - add ServerName earth.love'
echo '--   /etc/apache2/apache2.conf'
echo '--'
ELFOUND=`grep "^ServerName earth.love" /etc/apache2/apache2.conf|wc -l`
if [ $ELFOUND -eq 0 ]; then
echo 'ServerName earth.love' >>/etc/apache2/apache2.conf
fi

echo '--';
echo '-- Turn HostnameLookups Off in apache2.conf - easier to process _LOGS';
echo '--';
sudo sed -i -e's/HostnameLookups On/HostnameLookups Off/' /etc/apache2/apache2.conf;

echo
echo '--'
echo '-- SETUP start page redirect to /o/page'
echo '--'
sudo cp -puv config/start.html /LOVE/earth.love/_WEB/index.html
echo '-- Setup robots.txt';
sudo cp -puv config/robots.txt /LOVE/earth.love/_WEB/
echo '-- Setup Rewrite rules for BOTs and HACKers: accessBOT.log accessHACK.log';
sudo cp -puv config/elRewrite.conf /etc/apache2/
echo '-- Setup Virtual Hosts logs when not defined within vhost config: /LOVE/earth.love/_LOGS';
sudo cp -puv config/other-vhosts-access-log.conf /etc/apache2/conf-available

echo
echo '--'
echo '-- SETUP earth.love Virtual Host'
echo '--'
sudo cp -puv config/000-default.conf /etc/apache2/sites-available
sudo cp -puv config/earth.love.conf /etc/apache2/sites-available

echo
echo '--'
echo '-- Enable the earth.love Virtual Host'
echo '--'
sudo a2ensite earth.love.conf

echo
echo '--'
echo '-- Edit CGI Config - replace /cgi-bin/ with /o/'
echo '--'
sudo sed -i -e "s.ScriptAlias /cgi-bin/.ScriptAlias /o/." /etc/apache2/conf-available/serve-cgi-bin.conf

echo
echo '--'
echo '-- Install the /ELBIN and /ELDOMS directories'
echo '--'
cd $SCRIPTPATH/../ELBIN
./install_ELBIN.sh

echo
echo '--'
echo '-- Install the SETUP_DOM directories'
echo '--'
cd $SCRIPTPATH/..
if ! "$SCRIPTPATH/el_package_setup_dom.sh" "$SCRIPTPATH/.." "$HOME/SETUP_DOM"; then
  echo 'ERROR: Unable to install the domain setup security package.' >&2
  exit 1
fi

echo
echo '-- Restart Apache'
sudo systemctl restart apache2

echo '#########################################'
echo '# /LOVE/earth.love Apache Setup Complete'
echo '#########################################'
