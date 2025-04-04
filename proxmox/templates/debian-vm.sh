#!/bin/sh

DISTRO="debian"
IMAGE_PATH="/var/lib/vz/template/iso/debian-12-generic-amd64.qcow2"

./create-vm.sh "$1" "$DISTRO" "$IMAGE_PATH"