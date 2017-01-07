#!/usr/bin/env bash
set -e

if [[ ! -f $COMPOSE_FILE ]]; then
  >&2 echo "Services were not built. Run '$YODA_CMD start' first."
  exit 1
fi
docker-compose ps
