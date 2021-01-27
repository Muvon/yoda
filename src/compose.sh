#!/usr/bin/env bash
set -e

compose_container() {
  if [[ -x "$COMPOSE_SCRIPT" ]]; then
    cat - | $COMPOSE_SCRIPT --name=$1 --sequence=$2
  else
    cat -
  fi
  echo
}

# Parse map
declare -A SCALE_MAP
for p in "$@"; do
  service=$(echo $p | cut -d'=' -f1)
  count=$(echo $p | cut -d'=' -f2)
  if [[ "$service" == "$count" ]]; then
    count=1
  fi
  SCALE_MAP["$service"]=$(( ${count:-1} - 1 )) # Start index using 0
done

if [[ -z "${SCALE_MAP[@]}" ]]; then
  >&2 echo "No services to build. First you should add container."
  exit 1
fi

# Parse Buildfile to get imagenames
declare -A IMAGE_MAP
mapfile -t lines < $DOCKER_ROOT/Buildfile
for line in "${lines[@]}"; do
  k=$(echo $line | cut -d: -f1)
  v=$(echo $line | grep -Eo '\-t [^ ]+' | cut -d' ' -f2)
  # @TODO: this logic used twice: compose and build
  [[ $k =~ ^([^\[]*)(\[(.*)\])?$ ]]
  k=${BASH_REMATCH[1]}

  if [[ -n "$REGISTRY_URL" ]]; then
    v="$REGISTRY_URL/$v"
  fi
  IMAGE_MAP[$k]=$v
done

echo "# Build args: $*"
echo 'version: "3.9"'

# Common services and possibility to use Yaml merge anchors
# Stick to env operated file only
test -f "$DOCKER_ROOT/containers/compose.yml" && cat "$_" || true
echo

echo 'services:'
# name, sequence
# Remove .0 suffix if we have only one container of such type
get_container_name() {
  container_name="$1.$2"
  if [[ $CONTAINER_SCALE_INDEX == 0 && ${SCALE_MAP[$1]:-0} == 0 ]]; then
    container_name=$1
  fi

  echo -n "$container_name"
}

context=
get_context() {
  if [[ "$line" =~ ^[a-z_]+: ]]; then
    echo -n "$line" | cut -d ':' -f1 | tr -d ' '
  else
    echo -n "$context"
  fi
}

for p in ${!SCALE_MAP[*]}; do
  for i in $(seq 0 ${SCALE_MAP[$p]:-0}); do
    container_name=$(get_container_name "$p" "$i")
    container_path=${p//./\/}
    container_hostname=$(echo "$container_name" | cut -c -63)
    echo "  $container_name:"
    echo "    container_name: ${COMPOSE_PROJECT_NAME}.$container_name"
    echo "    hostname: $container_hostname"

    # Try to find container file
    container_file="$DOCKER_ROOT/containers/$container_path/container.yml"
    test ! -f "$container_file" && container_file=${container_file%/*}.yml
    env_container_file=${container_file%.*}.$ENV.yml

    if [[ ! -f "$container_file" ]]; then
      >&2 echo "Cannot find configuration file for container: $p"
      exit 1
    fi

    # Check if we have common var file named compose.yml for extension from
    [[ -f "$DOCKER_ROOT/containers/$container_path/compose.yml" ]] && cat "$_" || true

    remove=0
    has_network=0
    mapfile -t lines < "$container_file"
    {
      for line in "${lines[@]}"; do
        context=$(get_context "$line")

        # Check if we using shortcut for image declaration
        if [[ "$line" =~ ^image: ]]; then
          image=$(echo "$line" | cut -d' ' -f2)
          echo "image: ${IMAGE_MAP[$image]:-$image}"
          continue
        fi
        if [[ "$line" =~ ^(network_mode|networks): ]]; then
          has_network=1
        fi

        # Try to find keys should be replaced with env container file
        if [[ -f "$env_container_file" ]]; then
          if [[ "$line" =~ ^[a-z_]+: ]]; then
            if grep "${line%%:*}:" "$env_container_file" >/dev/null; then
              remove=1
            else
              remove=0
              echo "$line"
            fi
          else
            if [[ $remove == 0 ]]; then
              echo "$line"
            fi
          fi
        else
          echo "$line"
        fi
      done

      if [[ -f "$env_container_file" ]]; then
        if [[ $has_network == 0 && -n $(grep -q \(network_mode\|networks\) "$env_container_file") ]]; then
          has_network=1
        fi
        cat "$_"
      fi

      # Set default network mode if we not redefine it
      if [[ $has_network == 0 ]]; then
        echo "<<: *default_${ENV}_networks"
      fi
    } | sed "s/^/    /g;s/%{ENV}/$ENV/g;s/%{STACK}/$STACK/g" | compose_container $p $i
  done
done
