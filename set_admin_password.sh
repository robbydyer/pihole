#!/bin/bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
PASSFILE="${ROOT}/.webpass"

if [ -n "${1:-}" ]; then
  pass="$1"
elif [ -f "${PASSFILE}" ]; then
  pass="$(cat "${PASSFILE}")"
else
  echo "Please pass a password as arg, or set password in ${PASSFILE}"
  exit 1
fi

docker exec -it pihole pihole -a -p "${pass}"
