#!/usr/bin/env bash
set -e

# shellcheck disable=SC1091 source=../lib/string.sh
source "$YODA_PATH/lib/string.sh"

get_stack() {
  env_stack="$ENV"
  if [[ -n "$STACK" ]]; then
    env_stack="$env_stack.$STACK"
  fi

  mapfile -t lines < "$DOCKER_ROOT/Envfile"
  local parse=0
  local stack=()
  for line in "${lines[@]}"; do
    if (( parse == 1 )); then
      if [[ $line == *:* ]]; then
        break
      fi
      container=$(string_trim "${line//-/}")
      stack+=( "$container" )
    fi

    # Find first line
    if [[ $line =~ ^$env_stack: ]]; then

      line=$(string_trim "${line##*\:}")
      if [[ -n "$line" ]]; then
        stack=( $line )
        break
      fi
      parse=1
    fi
  done
  echo -n "${stack[@]}"
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

      service=$(get_stack | grep -oE "\b$service(=[0-9]+)?\b" | cat)
      if [[ -z "$service" ]]; then
        >&2 echo "There is no $container in $ENV $STACK"
        exit 1
      fi
      count=$(get_count "$service" 1)
      service=$(get_service "$service")
      if (( count > 1 )); then
        for n in $(seq 0 $((count - 1))); do
          containers+=($service.$n)
        done
      else
        containers+=($service)
      fi
    fi

    container_file="$DOCKER_ROOT/containers/${container//./\/}/container.yml";
    if [[ ! -f "$container_file" ]]; then
      container_file="$DOCKER_ROOT/containers/${container//./\/}.yml";
    fi

    image=$(grep image: $container_file | cut -d':' -f2 | tr -d ' ')
    images+=($image)
  done

  echo "${containers[@]}"
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
