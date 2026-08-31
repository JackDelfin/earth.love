#!/bin/bash -e
##########################################
# el_setup_AKASHIC.sh < build | all | lite >
#
# Parameter:
#   build - Build the Data structures ONLY
#           without loading data
#
#   all   - Build and Load All data in the toolkit
#
#   lite  - Build and Load a lite amount of data
#
# Install the Akashic WordBase
# in the default Earth.Love directory
#    /LOVE/earth.love
#
# The Akashic WordBase is a form of Trie Data Structure
#
# Consider redirecting output from this script to a log record
# ./el_setup_AKASHIC.sh all 2>&1 1|tee el_setup_AKASHIC_`date +%Y%m%d_%H%M%S`.out
#
# 2024.11.27 oK refactored
# 2022.09.13 oK created
##########################################

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
AUTH_DIR=/LOVE/earth.love/_ORBIT/_AUTH
AUTH_RUNTIME_USER=www-data
if [ -f /etc/fedora-release ]; then
  AUTH_RUNTIME_USER=apache
fi
if ! getent passwd "$AUTH_RUNTIME_USER" >/dev/null; then
  AUTH_RUNTIME_USER=www-data
fi
if ! getent passwd "$AUTH_RUNTIME_USER" >/dev/null; then
  echo "Authentication runtime account does not exist: $AUTH_RUNTIME_USER" >&2
  exit 1
fi
# Change to bin directory
cd $SCRIPTPATH/..

echo
echo '# -------------------------'
echo '# Earth.Love PRODUCTION'
echo '# -------------------------'

echo
echo '--'
echo '-- Build the Akashic Wordbase in /LOVE/earth.love/'
echo '--'
echo '-- This could take ~5 min on SSD to 30 min + on older machines'
sleep 5

#read -n1 -r -p "Paused: Press any key to continue..." key

# -- BUILD ONLY
if [ "$1" == "build" ]; then
  sudo build/BUILD_earthlove.pl /LOVE/earth.love build;

# -- BUILD AND ALL DATA
else if [ "$1" == "all" ]; then
  sudo build/BUILD_earthlove.pl /LOVE/earth.love all;

# -- BUILD AND LITE DATA
else if [ "$1" == "lite" ]; then
  sudo build/BUILD_earthlove.pl /LOVE/earth.love lite;
else
  echo 'Parameters: build | all | lite';
  exit 0;
fi
fi
fi

echo
echo '--'
echo '-- SETUP the OML Templates and Static Style Sheets'
echo '--'
# Legacy Installs - move _TEMPLATES to _ROOT
if [ -d /LOVE/earth.love/_TEMPLATES ]; then
echo
echo '--'
echo '-- Move _TEMPLATES to /LOVE/earth.love/_ROOT/_TEMPLATES'
echo '--'
sudo mv -v /LOVE/earth.love/_TEMPLATES /LOVE/earth.love/_ROOT/
fi

echo '--'
echo '-- SETUP /LOVE/earth.love/_TEMPLATES'
echo '--'
sudo cp -pruv _TEMPLATES/*       /LOVE/earth.love/_ROOT/_TEMPLATES
sudo chown -R www-data:www-data  /LOVE/earth.love/_ROOT/_TEMPLATES
sudo chmod -R g+w                /LOVE/earth.love/_ROOT/_TEMPLATES
echo
echo "Templates Installed:" `find /LOVE/earth.love/_ROOT/_TEMPLATES|wc -l`

echo;
echo '--';
echo '-- Set Attributes on /LOVE/earth.love';
echo '--';
# Preserve the private authentication store during rebuilds.  The surrounding
# domain keeps its historical web-writable ownership; _AUTH is owned solely by
# the actual CGI runtime user and restored to 0700/0600 below.  Create the
# private root unconditionally after the builder so a fresh installation is
# ready for Orbit::Auth without granting it to the installer account.
sudo find /LOVE/earth.love -path "$AUTH_DIR" -prune -o -exec chown www-data:www-data {} +
sudo find /LOVE/earth.love -path "$AUTH_DIR" -prune -o -exec chmod g+w {} +
if [ -L /LOVE/earth.love/_ORBIT ] || [ -L "$AUTH_DIR" ]; then
  echo "Refusing symbolic-link authentication path: $AUTH_DIR" >&2
  exit 1
fi
sudo chmod 0775 /LOVE/earth.love/_ORBIT
sudo install -d -o "$AUTH_RUNTIME_USER" -g "$AUTH_RUNTIME_USER" -m 0700 "$AUTH_DIR"
sudo chown -R "$AUTH_RUNTIME_USER:$AUTH_RUNTIME_USER" "$AUTH_DIR"
sudo find "$AUTH_DIR" -type d -exec chmod 0700 {} +
sudo find "$AUTH_DIR" -type f -exec chmod 0600 {} +
if [ -x /usr/sbin/restorecon ]; then
  sudo /usr/sbin/restorecon -RF "$AUTH_DIR"
fi

# Batch create pages for English
#utils/REFRESH_pages.pl /LOVE/earth.love LANGS/ENG

echo;
echo '# -------------------------';
echo '# -- Test Page with curl';
echo '# -------------------------';
echo;
echo '--';
echo '-- curl localhost';
echo '--';
curl localhost 2>/dev/null;

echo
echo '--';
echo '-- curl localhost/o/page - 7 times';
echo '--';
echo 'Benchmark:';
curl localhost/o/page 2>/dev/null|grep "ms)";
curl localhost/o/page 2>/dev/null|grep "ms)";
curl localhost/o/page 2>/dev/null|grep "ms)";
curl localhost/o/page 2>/dev/null|grep "ms)";
curl localhost/o/page 2>/dev/null|grep "ms)";
curl localhost/o/page 2>/dev/null|grep "ms)";
curl localhost/o/page 2>/dev/null|grep "ms)";

echo '#########################################'
echo '# AKASHIC WORDBASE Setup Complete'
echo '#########################################'
