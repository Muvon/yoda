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
  if [[ -n "$REGISTRY_URL" ]]; then
    v="$REGISTRY_URL/$v"
  fi
  IMAGE_MAP[$k]=$v
done

echo "# Build args: $*"
echo 'version: "2.1"'
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

adapt_link() {
  link_with_alias=$(echo "$1" | sed -E 's/^[ -]+(.*)$/\1/' | tr -d $'\n')
  link=${link_with_alias%:*}
  alias=${link_with_alias#*:}
  for n in $(seq 0 ${SCALE_MAP[$link]:-0}); do
    echo -n '  - '
    get_container_name "$link" "$n"
    if [[ $alias != $link_with_alias ]]; then
      echo -n ":$alias"
    fi
    echo
  done
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

    echo "  $container_name:"
    echo "    container_name: ${COMPOSE_PROJECT_NAME}.$container_name"
    echo "    hostname: ${HOSTNAME}.${COMPOSE_PROJECT_NAME}.$container_name"

    remove=0
    env_container_file="$DOCKER_ROOT/containers/$p/container.$ENV.yml"
    mapfile -t lines < "$DOCKER_ROOT/containers/$p/container.yml"
    {
      for line in "${lines[@]}"; do
        context=$(get_context "$line")

        # Check if we using shortcut for image declaration
        if [[ "$line" =~ ^image: ]]; then
          image=$(echo "$line" | cut -d' ' -f2)
          echo "image: ${IMAGE_MAP[$image]:-$image}"
          continue
        fi

        # Convert links container name to fully qualified names
        if [[ "$context" == "links" ]]; then
          if [[ "$line" =~ ^\ *- ]]; then
            adapt_link "$line"
            continue
          fi
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

      # Add env file data?
      if [[ -f "$env_container_file" ]]; then
        # Little shit with duplicated code
        mapfile -t lines < "$env_container_file"
        for line in "${lines[@]}"; do
          context=$(get_context "$line")

          # Convert links container name to fully qualified names
          if [[ "$context" == "links" ]]; then
            if [[ "$line" =~ ^\ *- ]]; then
              adapt_link "$line"
              continue
            fi
          fi

          echo "$line"
        done
      fi
    } | sed "s/^/    /g" | compose_container $p $i
  done
done
