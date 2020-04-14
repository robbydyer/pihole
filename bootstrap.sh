#!/bin/bash
set -euo pipefail

cd /home/pi

if ! dpkg -l | grep git-core; then
  apt-get update
  apt-get install -y git-core
fi

git clone https://github.com/robbydyer/pihole.git

cd pihole

./run.sh
