#!/bin/sh

# Install docker and start daemon at boot
apk add docker docker-cli-compose
rc-update add docker default
rc-service docker start

# Add doas user to the docker group
addgroup ${DOAS_USER} docker

# Isolate containers with a user namespace
adduser -SDHs /sbin/nologin dockremap
addgroup -S dockremap
sh -c 'echo dockremap:$(cat /etc/passwd|grep dockremap|cut -d: -f3):65536 >> /etc/subuid'
sh -c 'echo dockremap:$(cat /etc/passwd|grep dockremap|cut -d: -f4):65536 >> /etc/subgid'

mkdir /etc/docker/
echo '{ "userns-remap": "dockremap", "ipv6": false }' | jq '.' | tee /etc/docker/daemon.json

reboot
