#!/usr/bin/env bash
set -e

for p in $*; do
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

compose_args=('--no-build')
if [[ -n "$recreate" ]]; then
  compose_args+=('--force-recreate')
fi

$YODA_CMD compose > $COMPOSE_FILE
# Get images we need to build
images=$(grep image: $COMPOSE_FILE | sed 's|image:\(.*\)|\1|' | tr -d ' ' | sort | uniq)
$YODA_CMD build ${build_args[*]} $images
docker-compose up ${compose_args[*]} -t $STOP_WAIT_TIMEOUT -d $*
