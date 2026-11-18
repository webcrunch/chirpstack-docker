#!/usr/bin/env bash
# Fails if a service publishes a port beyond 127.0.0.1, except the gateways' ports.
# Docker's published ports go around ufw, so a port without 127.0.0.1 is reachable from the internet.
# Usage: scripts/check-ports.sh [compose file]   (default docker-compose.yml)
set -euo pipefail
file="${1:-docker-compose.yml}"
# The only ports the internet may reach: the gateways (Semtech UDP, Basic Station)
ALLOWED="1700/udp 3001/tcp"
bad=$(API_SECRET=ci docker compose -f "$file" config --format json \
  | jq -r --arg allowed "$ALLOWED" '
      ($allowed | split(" ")) as $ok
      | .services | to_entries[] | .key as $s | (.value.ports // [])[]
      | select(.host_ip != "127.0.0.1")
      | select(((.published | tostring) + "/" + (.protocol // "tcp")) as $p | ($ok | index($p)) | not)
      | "\($s): \(.published)->\(.target)/\(.protocol // "tcp") host_ip=\(.host_ip // "all")"')
if [ -n "$bad" ]; then
  echo "Ports published beyond 127.0.0.1 in $file (only $ALLOWED may be):"
  echo "$bad"
  exit 1
fi
echo "$file: only $ALLOWED are public, every other port is bound to 127.0.0.1"
