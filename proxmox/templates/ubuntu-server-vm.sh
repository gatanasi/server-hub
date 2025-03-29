#!/bin/sh

VMID="$1"
IMAGE_PATH="/var/lib/vz/template/iso/oracular-server-cloudimg-amd64.img"
DISTRO="ubuntu"

. ./create-vm.sh