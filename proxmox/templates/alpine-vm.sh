#!/bin/sh

VMID="$1"
IMAGE_PATH="/var/lib/vz/template/iso/generic_alpine-3.21.2-x86_64-uefi-cloudinit-r0.qcow2"
DISTRO="alpine"

. ./create-vm.sh