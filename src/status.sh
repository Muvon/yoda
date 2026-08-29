#!/usr/bin/env bash
# shellcheck disable=SC2154  # env vars are exported by the parent yoda process
set -e

"$YODA_CMD" compose > "$COMPOSE_FILE"
docker compose ps
