#!/usr/bin/env bash
set -e

$YODA_CMD compose > "$COMPOSE_FILE"
docker compose -f "$COMPOSE_FILE" exec "$@"

