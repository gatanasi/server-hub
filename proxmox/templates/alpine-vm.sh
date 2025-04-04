#!/bin/sh

DISTRO="alpine"
IMAGE_PATH="/var/lib/vz/template/iso/generic_alpine-3.21.2-x86_64-uefi-cloudinit-r0.qcow2"

./create-vm.sh "$1" "$DISTRO" "$IMAGE_PATH"