#!/bin/bash -e
##########################################
#
#        Install Akashic-Orbit
#               and the
#           Earth.Love BASE
#          on Fedora Linux
#
#  el_setup_fedora.sh [build / all / lite / none]
#
# 2026.07.16 oK Created for Fedora
##########################################

# Fail the pipeline if a setup phase fails (not just tee),
# so a BASE failure stops the install instead of cascading
set -o pipefail

# Get Build Option: build / all / lite / none
BUILDOPT=$1;
if [ "$BUILDOPT" == "" ]; then
  BUILDOPT="all";
fi

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

# Locate bin/setup - works from Linux_Install/ or from bin/setup/
if [ -d "$SCRIPTPATH/../bin/setup" ]; then
  SETUPDIR="$SCRIPTPATH/../bin/setup";
else
  SETUPDIR="$SCRIPTPATH";
fi
cd $SETUPDIR

##########################################
#
# Install the BASE components for Akashic-Orbit (Fedora)
#
##########################################
./el_setup_BASE_fedora.sh 2>&1 1|tee $SCRIPTPATH/el_setup_BASE_fedora_`date +%Y%m%d_%H%M%S`.out


##########################################
#
# Setup the /LOVE/earth.love root and virtual host for Apache (Fedora)
#
##########################################
./el_setup_EARTHLOVE_fedora.sh 2>&1 1|tee $SCRIPTPATH/el_setup_EARTHLOVE_fedora_`date +%Y%m%d_%H%M%S`.out


##########################################
#
# Build the Akashic WordBase for Earth.Love: /LOVE/earth.love
# (shared script - the build itself is distro-neutral)
#
##########################################
if [ "$BUILDOPT" == "build" ]; then
  ./el_setup_AKASHIC.sh build 2>&1 1|tee $SCRIPTPATH/el_setup_AKASHIC_build_`date +%Y%m%d_%H%M%S`.out;
elif [ "$BUILDOPT" == "all" ]; then
  #./el_setup_AKASHIC.sh all 2>&1 1|tee $SCRIPTPATH/el_setup_AKASHIC_all_`date +%Y%m%d_%H%M%S`.out;
  ./el_setup_AKASHIC.sh all;
elif [ "$BUILDOPT" == "lite" ]; then
  ./el_setup_AKASHIC.sh lite 2>&1 1|tee $SCRIPTPATH/el_setup_AKASHIC_lite_`date +%Y%m%d_%H%M%S`.out;
fi

##########################################
#
# Restore SELinux labels on the built WordBase
#
##########################################
if [ "$BUILDOPT" != "none" ] && [ -x /usr/sbin/restorecon ]; then
  echo;
  echo '-- Restore SELinux labels on /LOVE';
  sudo /usr/sbin/restorecon -RF /LOVE;
fi

exit 0;
