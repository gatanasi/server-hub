#!/bin/sh

adduser debian
adduser debian sudo
sudo passwd -l root

sudo usermod -aG docker "$USER"
exit