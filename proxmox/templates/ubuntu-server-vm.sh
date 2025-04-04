#!/bin/sh

DISTRO="ubuntu"
IMAGE_PATH="/var/lib/vz/template/iso/noble-server-cloudimg-amd64.img"

./create-vm.sh "$1" "$DISTRO" "$IMAGE_PATH"