#!/bin/bash
# Run this on the Raspberry-pi to start the containers
set -euo pipefail

NET="piholenet"
#UNBOUND="mvance/unbound:latest"
UNBOUND="myunbound:latest"

if ! dpkg -l | grep docker.io; then
  apt-get update
  apt-get install -y \
    docker.io \
    dnsutils \
    lsof
fi

docker pull pihole/pihole:latest

if ! docker network inspect "${NET}" &> /dev/null; then 
  docker network create "${NET}"
fi

if ! docker images | grep "${UNBOUND}"; then
  docker build -f Dockerfile.unbound -t "${UNBOUND}" .
fi

# Restart unbound each time
if docker inspect unbound &> /dev/null; then
  if docker ps | grep unbound &> /dev/nulll; then
    docker kill unbound
  fi
  docker rm unbound
fi

touch /var/log/unbound.log

docker run -d \
  --name unbound \
  --network "${NET}" \
  --privileged \
  --publish 5354:5354/udp \
  --publish 5354:5354/tcp \
  -v "$(pwd)/unbound.conf":/etc/unbound/unbound.conf.d/pihole.conf \
  "${UNBOUND}"

UNBOUND_IP="$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' unbound)"

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
    -e TZ="America/New York" \
    -e VIRTUAL_HOST=pihole.local \
    -e PIHOLE_DNS_1="${UNBOUND_IP}#5354" \
    -v "$(pwd)/pihole":/etc/pihole \
    -v "$(pwd)/dnsmasq":/etc/dnsmasq.d \
    pihole/pihole:latest
fi
