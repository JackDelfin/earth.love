#!/bin/bash -e

# Fedora version of el_setup_desktop.sh
# 2026.07.16 oK Created for Fedora

echo '# -------------------------'
echo '# Setup Common Desktop Tools'
echo '#       (Fedora Linux)'
echo '# -------------------------'
echo 

echo '--'
echo '-- Firefox'
echo '--'
sudo dnf install firefox -y
echo 

echo '--'
echo '-- gparted - disk partition editor'
echo '--'
sudo dnf install gparted -y
# mtools for reading DOS partitions in gparted
sudo dnf install mtools -y
echo 

echo '--'
echo '-- Transmission BitTorrent client'
echo '--'
sudo dnf install transmission -y
echo

# Optional Editor
echo '--'
echo '-- Install GUI VI Client (gvim)'
echo '--'
sudo dnf install vim-X11 -y
echo

# Optional Directory Compare and Merge Tool
echo '--'
echo '-- Install Directory Merge Tool - meld'
echo '--'
sudo dnf install meld -y
echo

# Optional Image Editor - gimp
echo '--'
echo '-- Install Image Editor - gimp'
echo '--'
sudo dnf install gimp -y
echo

# Optional SVG (Scalable Vector Graphics) Editor - inkscape
echo '--'
echo '-- Install SVG Editor - inkscape'
echo '--'
sudo dnf install inkscape -y
echo

# Optional AutoKey - Keyboard Automation for scripting, prompting, and autofill
echo '--'
echo '-- Install AutoKey - Keyboard Automation'
echo '--'
sudo dnf install autokey-gtk -y
echo

# Optional OBS Studio - Video Recording and Live Streaming
echo '--'
echo '-- Install OBS Studio - Video Recording and Live Streaming'
echo '--'
sudo dnf install obs-studio -y
echo

# Optional OCR my PDF - Convert PDF image to PDF text
echo '--'
echo '-- Install ocrmypdf - Convert PDF image to PDF text'
echo '--'
sudo dnf install ocrmypdf -y
echo
