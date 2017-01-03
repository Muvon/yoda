#!/usr/bin/env bash
set -e

docker-compose stop -t $STOP_WAIT_TIMEOUT $*
