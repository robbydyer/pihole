#!/bin/bash
# Run this on the Raspberry-pi to start the container
set -euo pipefail

NET="piholenet"
UNBOUND="klutchell/unbound:latest"

if ! dpkg -l | grep docker.io; then
  apt-get update
  apt-get install -y \
    docker.io \
    lsof
fi

docker pull "${UNBOUND}"
docker pull pihole/pihole:latest

if ! docker network inspect "${NET}"; then 
  docker network create "${NET}"
fi

# Restart unbound each time
if docker inspect unbound > /dev/null; then
  docker kill unbound
  docker rm unbound
fi

touch /var/log/unbound.log

docker run -d \
  --name unbound \
  --network "${NET}" \
  --privileged \
  --publish 5353:5353/udp \
  --publish 5353:5353/tcp \
  -v "$(pwd)/unbound-entrypoint.sh":/unbound-entrypoint.sh \
  -v /var/log/unbound.log:/var/log/unbound.log \
  --restart=unless-stopped \
  --entrypoint=/unbound-entrypoint.sh \
  "${UNBOUND}" \
  /unbound-entrypoint.sh

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
