#!/bin/sh

VMID="$1"
IMAGE_PATH="/var/lib/vz/template/iso/debian-12-generic-amd64.qcow2"
DISTRO="debian"

. ./create-vm.sh