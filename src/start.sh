#!/usr/bin/env bash
set -e

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
images=$(grep image: $COMPOSE_FILE | sed 's|image:\(.*\)|\1|' | tr -d ' ' | sort | uniq)

images=()
services=()
for service in "$@"; do
  image=$(grep image: $DOCKER_ROOT/containers/$service/container.yml | cut -d':' -f1 | tr -d ' ')
  images+=($image)

  service=$(cat $DOCKER_ROOT/Envfile | grep ^$ENV: | grep -oE "\b$service(=[0-9]+)?\b")

  if [[ "$service" == *"="* ]]; then
    count=$(echo $service | cut -d'=' -f2)
    service=$(echo $service | cut -d'=' -f1)
  else
    count=1
  fi

  for n in $(seq 0 $((count - 1))); do
    services+=($service.$n)
  done
done

$YODA_CMD build ${build_args[*]} ${images[*]}
docker-compose up ${compose_args[*]} -t $STOP_WAIT_TIMEOUT -d ${services[*]}
