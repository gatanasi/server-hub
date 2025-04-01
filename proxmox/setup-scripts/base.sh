#!/bin/sh

sudo apt install -y qemu-guest-agent
sudo systemctl start qemu-guest-agent
