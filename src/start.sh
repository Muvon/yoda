#!/usr/bin/env bash
set -e

for p in $*; do
  case $p in
    --rebuild)
      rebuild=1
      shift
      ;;
  esac
done

build_args=()
if [[ -n "$rebuild" ]]; then
  build_args+=('--rebuild')
fi

$YODA_CMD compose > $COMPOSE_FILE
$YODA_CMD build ${build_args[*]}
docker-compose up --no-build --remove-orphans -t $STOP_WAIT_TIMEOUT -d "$*"
