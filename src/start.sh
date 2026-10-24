#!/usr/bin/env bash
# shellcheck disable=SC2154  # env vars are exported by the parent yoda process
set -e
# shellcheck disable=SC1091 source=../lib/container.sh
source "$YODA_PATH/lib/container.sh"
# shellcheck disable=SC1091 source=../lib/array.sh
source "$YODA_PATH/lib/array.sh"

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
    --keep-orphans)
      keep_orphans=1
      shift
      ;;
    --wait)
      compose_wait=1
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

compose_args=('--no-build')
if [[ -z "$keep_orphans" ]]; then
  compose_args+=('--remove-orphans')
fi
if [[ -n "$recreate" ]]; then
  compose_args+=('--force-recreate')
fi
if [[ -n "$compose_wait" ]]; then
  compose_args+=('--wait')
fi

# Containers are passed as one space or newline separated string
service_stop() {
  local services=()
  read -ra services <<< "${1//$'\n'/ }"
  compose_stop "${services[@]}" || true
}

service_up() {
  local services=()
  read -ra services <<< "${1//$'\n'/ }"
  docker compose up "${compose_args[@]}" -d "${services[@]}"
}

startfile="$DOCKER_ROOT/Startfile"

# Startfile section for this run: <env>.<stack> when declared, otherwise <env>
startfile_section() {
  local name line
  test -f "$startfile" || return 0
  for name in ${STACK:+"$ENV.$STACK"} "$ENV"; do
    while IFS= read -r line || [[ -n "$line" ]]; do
      if [[ "$line" =~ ^([^[:space:]#].*):[[:space:]]*$ && "${BASH_REMATCH[1]}" == "$name" ]]; then
        echo "$name"
        return 0
      fi
    done < "$startfile"
  done
}

# Value of key $1 in the Startfile section of this run
get_config() {
  local line in_section=0 values=()
  test -n "$section" || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^[[:space:]]*(#.*)?$ ]]; then
      continue
    fi
    if [[ "$line" =~ ^[^[:space:]] ]]; then
      in_section=0
      if [[ "$line" =~ ^(.*):[[:space:]]*$ && "${BASH_REMATCH[1]}" == "$section" ]]; then
        in_section=1
      fi
      continue
    fi
    if (( in_section )) && [[ "$line" =~ ^[[:space:]]+$1:(.*)$ ]]; then
      read -ra values <<< "${BASH_REMATCH[1]}"
      echo "${values[*]}"
      return 0
    fi
  done < "$startfile"
}

# Services of Startfile key $1 that run in this stack. An unknown service
# aborts the start, except in an <env> section shared by stacks that run
# different services: there it only applies to the stacks that have it.
validate_services() {
  local key=$1 entry service
  local pool=() section_services=() stack_entries=() result=()
  read -ra section_services <<< "$(get_config "$key")"
  read -ra stack_entries <<< "$(get_stack)"
  for entry in "${stack_entries[@]}"; do
    pool+=("$(get_service "$entry")")
  done

  for entry in "${section_services[@]}"; do
    service=$(get_service "$entry")
    if [[ " ${pool[*]} " == *" $service "* ]]; then
      result+=("$entry")
    elif [[ -n "$STACK" && "$section" == "$ENV" ]]; then
      >&2 echo "Skipping service '$service' of section '$key': not in stack '$ENV.$STACK'."
    else
      >&2 echo "No service '$service' of section '$key' in pool of services: '${pool[*]}'. Check Startfile"
      exit 1
    fi
  done

  echo -n "${result[*]}"
}

# Compose services of the container $1 (itself and its scaled $1.<n>), every service when no container passed
compose_services() {
  local line name
  while read -r line; do
    name=${line#container_name: }
    name=${name#"$COMPOSE_PROJECT_NAME".}
    if [[ -z "$1" || "$name" =~ ^"$1"(\.[0-9]+)?$ ]]; then
      echo "$name"
    fi
  done < <(grep -E '^ +container_name: ' "$COMPOSE_FILE")
}

"$YODA_CMD" compose > "$COMPOSE_FILE"
containers=$(get_containers "$@")

# Build images on start only when no registry setted
if [[ -z "$REGISTRY_URL" || -n "$rebuild" ]]; then
  mapfile -t image_list < <(grep image: "$COMPOSE_FILE" | sed -r 's|[ ]*image:(.*/)?([^:]*)(:.*)?|\2|' | tr -d ' ' | sort | uniq)
  "$YODA_CMD" build "${build_args[@]}" "${image_list[@]}"
else # Pull images otherwise
  docker compose pull
fi

if [[ -z "$force" ]]; then
  running_containers=()
  section=$(startfile_section)
  # Assigned first so that an invalid Startfile aborts the start (set -e)
  flow_services=$(validate_services "flow")
  wait_services=$(validate_services "wait")
  stop_services=$(validate_services "stop")
  read -ra flow <<< "$flow_services"
  read -ra wait <<< "$wait_services"
  read -ra stop <<< "$stop_services"
  array_flip wait_index "${wait[@]}"

  # Stopping services first before recreating
  if [[ -n "${stop[*]}" ]]; then
    echo "Stopping: ${stop[*]}"
    stop_containers=()
    for service in "${stop[@]}"; do
      mapfile -t matches < <(compose_services "$service")
      stop_containers+=("${matches[@]}")
    done
    service_stop "${stop_containers[*]}"
  fi

  # Starting services using declared flow
  if [[ -n "${flow[*]}" ]]; then
    echo "Starting services by flow: ${flow[*]}"
    for service in "${flow[@]}"; do
      count=$(get_count "$service" 0)
      service=$(get_service "$service")
      service_containers=$(compose_services "$service")
      if (( count > 0 )); then
        printf -v join_string "%.0s- " $(seq 1 "$count")
        read -ra join_args <<< "$join_string"
        echo "$service_containers" | paste -d ' ' "${join_args[@]}" | while read -r chunk; do
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
        read -ra wait_list <<< "${service_containers//$'\n'/ }"
        wait_list=("${wait_list[@]/#/$COMPOSE_PROJECT_NAME.}")
        exit_codes=$(docker wait "${wait_list[@]}")
        # One exit code per line: every container must exit with 0
        if grep -qvx 0 <<< "$exit_codes"; then
          echo "Failed to wait containers: ${wait_list[*]}"
          docker logs "${wait_list[@]}"
          echo "Start is aborted due to one of containers exited with exit code $(echo "$exit_codes" | tr '\n' ' ')!= 0 while waiting"
          exit 1
        fi
      fi
      mapfile -t started <<< "$service_containers"
      running_containers+=("${started[@]}")
    done
  fi

  # Start rest of containers
  if [[ -n "${running_containers[*]}" ]]; then
    exclude_list=$(echo "${running_containers[*]}" | tr ' ' $'\n')
    other=$(compose_services | grep -vxF "$exclude_list" | tr $'\n' ' ')
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
