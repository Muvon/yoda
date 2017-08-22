#!/usr/bin/env bash
set -e
# shellcheck source=../lib/container.sh
source $YODA_PATH/lib/container.sh
source $YODA_PATH/lib/array.sh

for p in "$@"; do
  case $p in
    --rebuild)
      rebuild=1
      shift
      ;;
    --no-cache)
      no_cache=1
      shift
      ;;
    --recreate)
      recreate=1
      shift
      ;;
    --force)
      force=1
      shift
      ;;
  esac
done

build_args=()
if [[ -n "$rebuild" ]]; then
  build_args+=('--rebuild')
fi

if [[ -n "$no_cache" ]]; then
  build_args+=('--no-cache')
fi

compose_args=('--no-build' '--remove-orphans')
if [[ -n "$recreate" ]]; then
  compose_args+=('--force-recreate')
fi

service_stop() {
  docker-compose -f $MAIN_COMPOSE_FILE -f $COMPOSE_FILE stop -t $STOP_WAIT_TIMEOUT $1 || true
}

service_up() {
  docker-compose -f $MAIN_COMPOSE_FILE -f $COMPOSE_FILE up ${compose_args[*]} -t $STOP_WAIT_TIMEOUT -d $1
}

get_config() {
  grep -A 3 "^$ENV:$" docker/Startfile | grep "$1:" | head -n 1 | cut -d ':' -f 2
}

validate_services() {
  local section=$1
  services=$(get_config "$section")
  pool=( $(cat $DOCKER_ROOT/Envfile | grep ^$ENV: | cut -d: -f2) )
  for service in $services; do
    if echo -n "${pool[*]}" | grep -Eo "\b$service\b" > /dev/null; then
      continue
    fi
    >&2 echo "No service '$service' of section '$section' in pool of services: '${pool[*]}'. Check Startfile"
    exit 1
  done

  echo -n "$services"
}

$YODA_CMD compose > /dev/null
containers=$(get_containers "$@")

# Build images on start only when no registry setted
if [[ -z "$REGISTRY_URL" || -n "$rebuild" ]]; then
  images=$(grep image: $MAIN_COMPOSE_FILE | sed -r 's|[ ]*image:(.*/)?([^:]*)(:.*)?|\2|' | tr -d ' ' | sort | uniq)
  $YODA_CMD build ${build_args[*]} $images
else # Pull images otherwise
  docker-compose -f $MAIN_COMPOSE_FILE -f $COMPOSE_FILE pull
fi

if [[ -z "$force" ]]; then
  running_containers=()
  flow=( $(validate_services "flow") )
  wait=( $(validate_services "wait") )
  stop=( $(validate_services "stop") )
  array_flip wait_index "${wait[@]}"

  # Stopping services first before recreating
  if [[ -n "${stop[*]}" ]]; then
    echo "Stopping: ${stop[*]}"
    stop_containers=()
    for service in "${stop[@]}"; do
      stop_containers+=( $(cat $MAIN_COMPOSE_FILE | grep -E "container_name: $COMPOSE_PROJECT_NAME\.$service(\.[0-9]+)?$" | cut -d':' -f2 | cut -d'.' -f2-3 | tr -d ' ') )
    done
    service_stop "${stop_containers[*]}"
  fi

  # Starting services using declared flow
  if [[ -n "${flow[*]}" ]]; then
    echo "Starting services by flow: ${flow[*]}"
    for service in "${flow[@]}"; do
      count=$(get_count "$service" 0)
      service=$(get_service "$service")
      service_containers=$(cat $MAIN_COMPOSE_FILE | grep -E "container_name: $COMPOSE_PROJECT_NAME\.$service(\.[0-9]+)?$" | cut -d':' -f2 | cut -d'.' -f2-3 | tr -d ' ')
      if (( $count > 0 )); then
        printf -v join_string "%.0s- " $(seq 1 $count)
        echo "$service_containers" | paste -d ' ' $join_string | while read chunk; do
          echo "Starting chunks of $service by $count: $chunk"
          service_up "$chunk"
        done
      else
        echo "Starting all chunks of $service: $service_containers"
        service_up "$service_containers"
      fi

      # We should wait for this container?
      if [[ -n "${wait_index[$service]}" ]]; then
        echo "Waiting for: ${service_containers[*]}"
        wait_containers=$(cat $MAIN_COMPOSE_FILE | grep -E "container_name: $COMPOSE_PROJECT_NAME\.$service(\.[0-9]+)?$" | cut -d':' -f2-3 | tr -d ' ' | tr $'\n' ' ')
        exit_code=$(docker wait $wait_containers)
        if [[ $exit_code != 0 ]]; then
          echo "Failed to wait containers: $wait_containers"
          docker logs $wait_containers
          echo "Start is aborted due to one of containers exited with exit code $exit_code != 0 while waiting"
          exit 1
        fi
      fi
      running_containers+=($service_containers)
    done
  fi

  # Start rest of containers
  if [[ -n "${running_containers[*]}" ]]; then
    exclude_list=$(echo "${running_containers[*]}" | tr ' ' $'\n')
    other=$(cat $MAIN_COMPOSE_FILE | grep -E 'container_name: [A-Za-z_\.0-9]+$' | cut -d':' -f2 | cut -d'.' -f2-3 | tr -d ' ' | grep -v "$exclude_list" | tr $'\n' ' ')
    if [[ -n "$other" ]]; then
      echo "Starting rest of containers: $other"
      service_up "$other"
    fi
  else
    service_up "$containers"
  fi
else
  service_up "$containers"
fi
