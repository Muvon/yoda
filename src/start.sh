#!/usr/bin/env bash
set -e
# shellcheck source=../lib/container.sh
source $YODA_PATH/lib/container.sh

for p in "$@"; do
  case $p in
    --rebuild)
      rebuild=1
      shift
      ;;
    --recreate)
      recreate=1
      shift
      ;;
  esac
done

build_args=()
if [[ -n "$rebuild" ]]; then
  build_args+=('--rebuild')
fi

compose_args=('--no-build' '--remove-orphans')
if [[ -n "$recreate" ]]; then
  compose_args+=('--force-recreate')
fi

$YODA_CMD compose > $COMPOSE_FILE
# Get images we need to build
compose_images=$(grep image: $COMPOSE_FILE | sed 's|image:\(.*\)|\1|' | tr -d ' ' | sort | uniq)

images=$(get_images "$@")
containers=$(get_containers "$@")

$YODA_CMD build ${build_args[*]} ${images:-$compose_images}
docker-compose up ${compose_args[*]} -t $STOP_WAIT_TIMEOUT -d $containers
