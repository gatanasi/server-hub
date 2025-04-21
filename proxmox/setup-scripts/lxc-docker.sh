#!/bin/sh

NEW_USER="debian"

adduser "$NEW_USER"
usermod -aG sudo "$NEW_USER" && passwd -l root
usermod -aG docker "$NEW_USER"
