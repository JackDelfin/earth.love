#!/bin/bash
# 2022.09.16 PASH PISA

# Install IPFS Software and Daemon Service
# Update
# ipfs-update install latest
# Usage
# Visit WebUI at http://127.0.0.1:5001/webui/ , run command "ipfs" via CLI. 

echo "-- Install  IPFS Software"
cd /tmp && release=$(wget -q https://github.com/ipfs/ipfs-update/releases/latest -O - | grep "title>Release" | cut -d " " -f 4) && sudo wget -Nc https://dist.ipfs.io/ipfs-update/"$release"/ipfs-update_"$release"_linux-amd64.tar.gz

echo "-- Update  IPFS Software"
tar -xzf ipfs-update* && cd ipfs-update && sudo bash install.sh && cd -

sudo rm -rf /tmp/ipfs-update*
sudo ipfs-update install latest && ipfs --version && ipfs --help

#
# Initialize the repository ($ ipfs init)
#
echo "-- Initialize IPFS Repository"
ipfs init

#
# and launch IPFS daemon ($ ipfs daemon)
#
echo "-- Launch IPFS daemon"
ipfs daemon
# or instead of the daemon use the service to keep running and starting after boot:

echo "-- Setup IPFS Daemon Service"
echo "TEST FIRST"
# echo -e "[Unit]\n\nDescription=IPFS Daemon\nAfter=syslog.target network.target remote-fs.target nss-lookup.target\n\n[Service]\nType=simple\nExecStart=$(which ipfs) daemon --init --migrate\nUser=$(whoami)\n\n[Install]\nWantedBy=multi-user.target"|sudo tee -a /etc/systemd/system/ipfs.service

# sudo systemctl daemon-reload
# sudo systemctl restart ipfs
# sudo systemctl status ipfs
# sudo systemctl enable ipfs

