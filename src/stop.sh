#!/usr/bin/env bash
# shellcheck disable=SC2154  # env vars are exported by the parent yoda process
set -e
# shellcheck disable=SC1091 source=../lib/container.sh
source "$YODA_PATH/lib/container.sh"
containers=$(get_containers "$@")

$YODA_CMD compose > "$COMPOSE_FILE"
read -ra container_list <<< "$containers"
docker compose stop -t "$STOP_WAIT_TIMEOUT" "${container_list[@]}"
