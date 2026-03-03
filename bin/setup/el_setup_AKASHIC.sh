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
sudo chown -R www-data:www-data /LOVE/earth.love;
sudo chmod -R g+w /LOVE/earth.love;

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
