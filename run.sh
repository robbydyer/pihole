#!/bin/bash
# Run this on the Raspberry-pi to start the container

if ! dpkg -l | grep docker.io; then
  apt-get update
  apt-get install -y docker.io
fi

docker pull mvance/unbound:latest
docker pull pihole/pihole:latest

NET="piholenet"

if ! docker network inspect "${NET}"; then 
  docker network create "${NET}"
fi

# This is the recursive DNS server
docker run -d \
  --name unbound \
  --network "${NET}" \
  --privileged \
  -v "$(pwd)/unbound.conf":/etc/unbound/unbound.conf.d/pi-hole.conf \
  --restart=unless-stopped \
  mvance/unbound:latest

docker run -d \
  --name pihole \
  --network "${NET}" \
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
