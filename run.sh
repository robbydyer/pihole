#!/bin/bash
# Run this on the Raspberry-pi to start the containers
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
NET="piholenet"
UNBOUND="myunbound:latest"

if ! dpkg -l | grep docker.io; then
  apt-get update
  apt-get install -y \
    docker.io \
    dnsutils \
    vim \
    lsof
fi

if [ ! -f /etc/init.d/pihole ] || ! diff /etc/init.d/pihole pihole.initd &> /dev/null; then
  echo "=> Installing /etc/init.d/pihole"
  cp pihole.initd /etc/init.d/pihole
  chmod 755 /etc/init.d/pihole
fi

img=pihole/pihole:2022.04
docker pull "${img}"
#docker build -f Dockerfile.pihole -t ${img} .

if ! docker network inspect "${NET}" &> /dev/null; then 
  docker network create "${NET}"
fi

if ! docker images | grep "${UNBOUND}"; then
  docker build -f Dockerfile.unbound -t "${UNBOUND}" .
fi

remove_container() {
  container="$1"
  if docker inspect "${container}" &> /dev/null; then
    echo "=> Killing docker container '${container}'"
    docker kill "${container}"
  fi
  echo "=> Removing docker container '${container}'"
  docker rm "${container}"
}


remove_container unbound || true

set -x
docker run -d \
  --name unbound \
  --network "${NET}" \
  --restart=unless-stopped \
  --privileged \
  --publish 5354:5354/udp \
  --publish 5354:5354/tcp \
  -v "${ROOT}/unbound.conf":/etc/unbound/unbound.conf.d/pihole.conf \
  "${UNBOUND}"
set +x

UNBOUND_IP="$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' unbound)"

remove_container pihole || true

lists_path="$(realpath ${ROOT}/../my-pihole-lists)"

set -x
  #-v "${ROOT}/sync.cron":/etc/cron.d/pihole-sync \
docker run -d \
  --name pihole \
  --network "${NET}" \
  --restart=unless-stopped \
  --privileged \
  --publish 8080:80 \
  --publish 443:443 \
  --publish 53:53/udp \
  --publish 53:53/tcp \
  -e TZ="America/New York" \
  -e PIHOLE_DNS="${UNBOUND_IP}#5354" \
  -e DNSSEC=false \
  -e CUSTOM_CACHE_SIZE=0 \
  -e WEBPASSWORD_FILE=/webpass \
  -v "${ROOT}/.webpass":/webpass \
  -v "${ROOT}/pihole":/etc/pihole \
  -v "${ROOT}/pihole-cloudsync":/usr/local/bin/pihole-cloudsync \
  -v "${lists_path}":/etc/my-pihole-lists \
  -v "${HOME}/.ssh/id_rsa":/root/.ssh/id_rsa \
  -v "${HOME}/.gitconfig":/root/.gitconfig \
  -v "${ROOT}/dnsmasq/02-lan.conf":/etc/dnsmasq.d/02-lan.conf \
  ${img}


#sleep 10
# CACHE_SIZE should be fixed now https://github.com/pi-hole/docker-pi-hole/pull/689
#docker exec pihole bash -cex "sed -i 's/cache-size.*/cache-size=0/' /etc/dnsmasq.d/01-pihole.conf && /usr/local/bin/pihole restartdns"
