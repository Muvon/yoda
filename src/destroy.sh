#!/usr/bin/env bash
set -e

docker-compose -f $MAIN_COMPOSE_FILE -f $COMPOSE_FILE down --rmi local --volumes
