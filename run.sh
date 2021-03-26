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

docker pull pihole/pihole:latest
img=mypihole
docker build -f Dockerfile.pihole -t ${img} .

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
  -v "$(pwd)/unbound.conf":/etc/unbound/unbound.conf.d/pihole.conf \
  "${UNBOUND}"
set +x

UNBOUND_IP="$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' unbound)"

remove_container pihole || true

lists_path="$(realpath $(pwd)/../my-pihole-lists)"

tok=""
[ -f "${HOME}/.ghtoken" ] && tok="$(cat ${HOME}/.ghtoken)"

set -x
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
  -e DNS1="${UNBOUND_IP}#5354" \
  -e DNS2="${UNBOUND_IP}#5354" \
  -e DNSSEC=false \
  -e GH_TOKEN="${tok}" \
  -v "$(pwd)/pihole":/etc/pihole \
  -v "$(pwd)/dnsmasq":/etc/dnsmasq.d \
  -v "$(pwd)/pihole-cloudsync":/usr/local/bin/pihole-cloudsync \
  -v "${lists_path}":/etc/my-pihole-lists \
  -v "${HOME}/.ssh/id_rsa":/root/.ssh/id_rsa \
  -v "${HOME}/.gitconfig":/root/.gitconfig \
  -v "$(pwd)/sync.cron":/etc/cron.d/pihole-sync \
  ${img}

if [ -f "${ROOT}/.webpass" ]; then
  "${ROOT}/set_admin_password.sh"
fi
