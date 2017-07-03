#!/usr/bin/env bash
set -e
# shellcheck source=../lib/container.sh
source $YODA_PATH/lib/container.sh
containers=$(get_containers "$@")

$YODA_CMD compose > /dev/null
docker-compose -f $MAIN_COMPOSE_FILE -f $COMPOSE_FILE stop -t $STOP_WAIT_TIMEOUT $containers
