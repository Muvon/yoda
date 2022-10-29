#!/usr/bin/env bash
set -e
# shellcheck disable=SC1091 source=../lib/container.sh
source "$YODA_PATH/lib/container.sh"
containers=$(get_containers "$@")

$YODA_CMD compose > "$COMPOSE_FILE"
docker compose stop -t "$STOP_WAIT_TIMEOUT" $containers
