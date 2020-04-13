#!/bin/bash
# Run this on the Raspberry-pi to start the container

NET="piholenet"
UNBOUND="klutchell/unbound:latest"

if ! dpkg -l | grep docker.io; then
  apt-get update
  apt-get install -y docker.io
fi

docker pull "${UNBOUND}"
docker pull pihole/pihole:latest

if ! docker network inspect "${NET}"; then 
  docker network create "${NET}"
fi

if ! docker inspect unbound > /dev/null; then
  # This is the recursive DNS server
  docker run -d \
    --name unbound \
    --network "${NET}" \
    --privileged \
    -v "$(pwd)/unbound.conf":/opt/unbound/etc/unbound/unbound.conf.d/pi-hole.conf \
    --restart=unless-stopped \
    "${UNBOUND}"
fi

if ! docker inspect pihole > /dev/null; then
  docker run -d \
    --name pihole \
    --network "${NET}" \
    --restart=unless-stopped \
    --privileged \
    --publish 80:80 \
    --publish 443:443 \
    --publish 53:53/udp \
    --publish 53:53/tcp \
    --dns=127.0.0.1 \
    --dns=1.1.1.1 \
    -e TZ="America/New York" \
    -e VIRTUAL_HOST=pihole.local \
    -e PIHOLE_DNS_1=127.0.0.1#5353 \
    -v "$(pwd)/pihole":/etc/pihole \
    -v "$(pwd)/dnsmasq":/etc/dnsmasq.d \
    pihole/pihole:latest
fi
