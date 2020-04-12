#!/bin/bash
# Run this on the Raspberry-pi to start the container

if ! dpkg -l | grep docker.io; then
  apt-get update
  apt-get install -y docker.io
fi

docker run -d \
  --restart=unless-stopped \
  --privileged \
  --publish 80:80 \
  --publish 443:443 \
  --publish 67:67/udp \
  --publish 53:53/udp \
  --publish 53:53/tcp \
  -e TZ="America/New York" \
  -e VIRTUAL_HOST=pihole.local \
  -v "$(pwd)/pihole":/etc/pihole \
  -v "$(pwd)/dnsmasq":/etc/dnsmasq.d \
  pihole/pihole:latest
