#!/bin/bash
# Last update: 14.01.2015
# Status: work in progress, it will install prerequisities, fetch repos, configure udev. It will not compile sources.
# This script automates the instalation of Gnuradio and OpenBTS
# It is still a work in progress.
# build-gnuradio.sh script is a modified version of http://www.sbrac.org/files/build-gnuradio
# Do not use the original script with this file. It will not work.
#
# install prerequisites,
# use GIT to fetch Gnu Radio and UHD,
# modify the /etc/groups and add user to group 'usrp', add UDEV rule for USRP1
#
./build-gnuradio.sh -y -l prereqs-log.txt -m prereqs 
./build-gnuradio.sh -y -l gitfetch-log.txt -m gitfetch
./build-gnuradio.sh -y -l mod-log.txt -m mod_groups mod_udev

./build-openbts.sh -l prereqs-openbts-log.txt -m prereqs 
./build-openbts.sh -l gitfetch-openbts-log.txt -m gitfetch
./build-openbts.sh -l build-openbts-log.txt -m openbts-build
