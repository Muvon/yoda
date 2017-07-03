#!/usr/bin/env bash
set -e

$YODA_CMD compose > /dev/null
docker-compose -f $MAIN_COMPOSE_FILE -f $COMPOSE_FILE logs "$@"
