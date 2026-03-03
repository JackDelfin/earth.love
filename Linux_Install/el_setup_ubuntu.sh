#!/bin/bash -e
##########################################
#
#        Install Akashic-Orbit
#               and the
#           Earth.Love BASE
#       on Ubuntu or Debian Linux
#
#
# 2024.11.27 oK Refactored Install
##########################################

# Get Build Option: build / all / lite / none
BUILDOPT=$1;
if [ "$BUILDOPT" == "" ]; then
  BUILDOPT="all";
fi

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
# Change to bin directory
cd $SCRIPTPATH/../bin/setup

##########################################
#
# Install the BASE components for Akashic-Orbit
#
##########################################
./el_setup_BASE.sh 2>&1 1|tee $SCRIPTPATH/el_setup_BASE_`date +%Y%m%d_%H%M%S`.out


##########################################
#
# Setup the /LOVE/earth.love root and virtual host for Apache
#
##########################################
./el_setup_EARTHLOVE.sh 2>&1 1|tee $SCRIPTPATH/el_setup_EARTHLOVE_`date +%Y%m%d_%H%M%S`.out


##########################################
#
# Build the Akashic WordBase for Earth.Love: /LOVE/earth.love
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

exit 0;

