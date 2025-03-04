#!/bin/sh

# Install basic dependencies
doas apk add qemu-guest-agent jq curl
doas rc-update add qemu-guest-agent
doas rc-service qemu-guest-agent start
