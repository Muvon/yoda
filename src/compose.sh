#!/usr/bin/env bash
set -e

compose_container() {
  if [[ -x "$COMPOSE_SCRIPT" ]]; then
    cat - | $COMPOSE_SCRIPT --name=$1 --sequence=$2
  else
    cat -
  fi
}

# Parse map
declare -A SCALE_MAP
for p in "$@"; do
  service=$(echo $p | cut -d'=' -f1)
  count=$(echo $p | cut -d'=' -f2)
  count=${count//[!0-9]/}
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
  IMAGE_MAP[$k]=$v
done

echo "# Build args $0 $*"
echo 'version: "2"'
echo 'services:'

for p in ${!SCALE_MAP[*]}; do
  for i in $(seq 0 ${SCALE_MAP[$p]:-0}); do
    echo "  $p.$i:"
    echo "    container_name: ${COMPOSE_PROJECT_NAME}.$p.$i"

    remove=0
    env_container_file="$DOCKER_ROOT/containers/$p/container.$ENV.yml"
    mapfile -t lines < "$DOCKER_ROOT/containers/$p/container.yml"
    {
      if [[ -f "$env_container_file" ]]; then
        for line in "${lines[@]}"; do
          # Check if we using shortcut for image declaration
          if [[ "$line" =~ ^image\: ]]; then
            image=$(echo $line | cut -d' ' -f2)
            echo "image: ${IMAGE_MAP[$image]:-$image}"
            continue
          fi

          # Try to find keys should be replaced with env container file
          if [[ "$line" =~ ^[a-z_]+\: ]]; then
            if cat $env_container_file | grep "${line%%:*}:" >/dev/null; then
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
        done
        cat $env_container_file
      else
        printf '%s\n' "${lines[@]}"
      fi
    } | sed "s/^/    /g;s/#/$i/g" | compose_container $p $i
  done
done
