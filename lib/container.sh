#!/usr/bin/env bash
set -e

get_stack() {
  env_stack="$ENV"
  if [[ -n "$STACK" ]]; then
    env_stack="$env_stack.$STACK"
  fi
  return $(cat $DOCKER_ROOT/Envfile | grep ^$env_stack: | cut -d: -f2)
}

get_containers() {
  local containers=()
  for service in "$@"; do
    service=$(echo $service | sed "s|^$COMPOSE_PROJECT_NAME\.||")

    # Get real name of container
    container=$service
    if [[ "$service" =~ ^.*\.[0-9]+$ ]]; then
      container=${service%.*}
      containers+=($service)
    else
      service=$(get_stack | grep -oE "\b$service(=[0-9]+)?\b")
      count=$(get_count "$service" 1)
      service=$(get_service "$service")

      for n in $(seq 0 $((count - 1))); do
        containers+=($service.$n)
      done
    fi

    image=$(grep image: $DOCKER_ROOT/containers/$container/container.yml | cut -d':' -f2 | tr -d ' ')
    images+=($image)
  done

  echo ${containers[*]}
}

get_count() {
  service=$1
  default=$2

  if [[ "$service" == *"="* ]]; then
    count=$(echo "$service" | cut -d'=' -f2)
  else
    count=$default
  fi

  echo "$count"
}

get_service() {
  echo "$1" | cut -d'=' -f1
}
