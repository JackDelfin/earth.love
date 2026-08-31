#!/bin/bash
set -euo pipefail

# Deterministically stage the domain setup tools and their complete template
# source.  Security fixes must replace older files even when an installed copy
# has a newer or otherwise misleading mtime.

if [ "$#" -ne 2 ] || [ "${1#/}" = "$1" ] || [ "${2#/}" = "$2" ]; then
  echo "Usage: $0 /absolute/source/bin /absolute/target/SETUP_DOM" >&2
  exit 2
fi

SOURCE_BIN="${1%/}"
TARGET_SETUP="${2%/}"
SOURCE_SETUP="$SOURCE_BIN/SETUP_DOM"
SOURCE_TEMPLATES="$SOURCE_BIN/_TEMPLATES"
SOURCE_SYNC="$SOURCE_BIN/setup/el_sync_auth_templates.sh"

for source_dir in "$SOURCE_BIN" "$SOURCE_SETUP" "$SOURCE_TEMPLATES"; do
  if [ ! -d "$source_dir" ] || [ -L "$source_dir" ]; then
    echo "Refusing unsafe domain-setup package source: $source_dir" >&2
    exit 1
  fi
done
if [ ! -f "$SOURCE_SETUP/installACTIVATION.pl" ] \
   || [ -L "$SOURCE_SETUP/installACTIVATION.pl" ] \
   || [ ! -f "$SOURCE_SYNC" ] || [ -L "$SOURCE_SYNC" ]; then
  echo "Domain-setup package is missing required security tools." >&2
  exit 1
fi
if [ -e "$TARGET_SETUP" ] && { [ ! -d "$TARGET_SETUP" ] || [ -L "$TARGET_SETUP" ]; }; then
  echo "Refusing unsafe domain-setup package target: $TARGET_SETUP" >&2
  exit 1
fi

install -d -m 0755 -- "$TARGET_SETUP"
if [ -L "$TARGET_SETUP/_TEMPLATES" ]; then
  echo "Refusing symbolic-link template package target: $TARGET_SETUP/_TEMPLATES" >&2
  exit 1
fi

# No update-only option is used: installed scripts and templates always match
# this release, independent of source/destination timestamps.
cp -prv --remove-destination -- "$SOURCE_SETUP/." "$TARGET_SETUP/"
install -d -m 0755 -- "$TARGET_SETUP/_TEMPLATES"
cp -prv --remove-destination -- "$SOURCE_TEMPLATES/." "$TARGET_SETUP/_TEMPLATES/"
install -m 0755 -- "$SOURCE_SYNC" "$TARGET_SETUP/el_sync_auth_templates.sh"
