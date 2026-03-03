#!/bin/bash -e

# 2022.09.14 PISA PASH

echo '# -------------------------'
echo '# Setup Common Desktop Tools'
echo '# -------------------------'
echo 

echo '--'
echo '-- Firefox-esr'
echo '--'
# Debian (Raspberry Pi)
sudo apt install firefox-esr -y
# Ubuntu
sudo apt install firefox -y
echo 

echo '--'
echo '-- gparted - disk partition editor'
echo '--'
sudo apt install gparted -y
# mtools for reading DOS partitions in gparted
sudo apt install mtools -y
echo 

echo '--'
echo '-- Transmission BitTorrent client'
echo '--'
sudo apt install transmission -y
echo

# Optional Messaging
#echo '--'
#echo '-- Discord'
#echo '--'
#sudo snap install discord
#echo

# Optional Editor
echo '--'
echo '-- Install GUI VI Client'
echo '--'
sudo apt install vim-gui-common -y
echo

# Optional Directory Compare and Merge Tool
echo '--'
echo '-- Install Directory Merge Tool - meld'
echo '--'
sudo apt install meld -y
echo

# Optional Image Editor - gimp
echo '--'
echo '-- Install Image Editor - gimp'
echo '--'
sudo apt install gimp -y
echo

# Optional SVG (Scalable Vector Graphics) Editor - inkscape
echo '--'
echo '-- Install SVG Editor - inkscape'
echo '--'
sudo apt install inkscape -y
echo

# Optional AutoKey - Keyboard Automation for scripting, prompting, and autofill
echo '--'
echo '-- Install AutoKey - Keyboard Automation'
echo '--'
sudo apt-get install autokey-gtk -y
echo

# Optional OBS Studio - Video Recording and Live Streaming
echo '--'
echo '-- Install OBS Studio - Video Recording and Live Streaming'
echo '--'
sudo apt install obs-studio -y
echo

# Optional OCR my PDF - Convert PDF image to PDF text
echo '--'
echo '-- Install ocrmypdf - Convert PDF image to PDF text'
echo '--'
sudo apt install ocrmypdf -y
echo

# Optional Font Creator
#echo '--'
#echo '-- Install fontforge - Font Creator'
#echo '--'
#sudo apt install fontforge -y
#echo

