#!/usr/bin/env bash
set -e

get_containers() {
  containers=()
  for service in "$@"; do
    service=$(echo $service | sed "s|^$COMPOSE_PROJECT_NAME\.||")

    # Get real name of container
    container=$service
    if [[ "$service" =~ ^.*\.[0-9]+$ ]]; then
      container=${service%.*}
      containers+=($service)
    else
      service=$(cat $DOCKER_ROOT/Envfile | grep ^$ENV: | sed "s|^$ENV||" | grep -oE "\b$service(=[0-9]+)?\b")
      count=$(get_count "$service" 1)

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
    service=$(echo "$service" | cut -d'=' -f1)
  else
    count=$default
  fi

  echo "$count"
}
