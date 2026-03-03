#!/bin/bash
# Get DOMS.dat and DWEEM.dat for Published Domains and push to ELBIN

echo
echo "# Get the Public Domains based on those already SETUP at Site 1";
cat /ELDOMS/DWEEM.dat|sed -e'/^s.\./d'|grep 99.6.104|sed -e's/ .*//g'>/ELDOMS/DOMS_PUB.dat;

echo
echo "# Publish DOMS_PUB.dat to ELBIN";
cp -puv /ELDOMS/DOMS_PUB.dat ~/PATCHES/ELBIN/doms/DOMS.dat;

echo
echo "# Publish DWEEM_PUB.dat to ELBIN";
cp -puv /ELDOMS/DWEEM_PUB.dat ~/PATCHES/ELBIN/doms/DWEEM.dat;

echo
ls -l /ELDOMS/DWEEM.dat /ELDOMS/DWEEM_PUB.dat /ELDOMS/DOMS.dat /ELDOMS/DOMS_PUB.dat
wc /ELDOMS/DOMS.dat /ELDOMS/DWEEM.dat
wc /ELDOMS/DOMS_PUB.dat /ELDOMS/DWEEM_PUB.dat
wc ~/PATCHES/ELBIN/doms/*
echo

