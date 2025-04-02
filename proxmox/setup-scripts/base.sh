#!/bin/sh

sudo apt install -y qemu-guest-agent
sudo systemctl start qemu-guest-agent

sudo apt install -y unattended-upgrades
sudo dpkg-reconfigure unattended-upgrades
