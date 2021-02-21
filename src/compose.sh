#!/usr/bin/env bash
set -e

# shellcheck disable=SC1091 source=../lib/array.sh
source "$YODA_PATH/lib/string.sh"

compose_container() {
  if [[ -x "$COMPOSE_SCRIPT" ]]; then
    cat - | $COMPOSE_SCRIPT --name=$1 --sequence=$2
  else
    cat -
  fi
  echo
}

compile_config() {
  local lines=()
  local remove=0
  local container_file=$1
  local env_container_file=${container_file%.*}.$ENV.yml

  # Prepare replacements
  local replaces=(
    "^/$(printf "%${2:-4}s")"
    "$YODA_VAR_REGEX/\$\1"
  )

  local compiled=()
  mapfile -t lines < "$container_file"
  {
    for line in "${lines[@]}"; do
      # Check if we using shortcut for image declaration
      if [[ "$line" =~ ^image: ]]; then
        image=$(echo "$line" | cut -d' ' -f2)
        compiled+=( "image: ${IMAGE_MAP[$image]:-$image}" )
        continue
      fi

      # Try to find keys should be replaced with env container file
      if [[ -f "$env_container_file" ]]; then
        if [[ "$line" =~ ^[a-z_]+: ]]; then
          if grep "${line%%:*}:" "$env_container_file" >/dev/null; then
            remove=1
          else
            remove=0
            compiled+=("$line")
          fi
        else
          if [[ $remove == 0 ]]; then
            compiled+=("$line")
          fi
        fi
      else
        compiled+=("$line")
      fi
    done

    if [[ -f "$env_container_file" ]]; then
      compiled+=( "$( cat "$env_container_file" )" )
    fi

    printf "%s\n" "${compiled[@]}"
  } | string_replace "${replaces[@]}" | compose_container $p $i
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
echo 'version: "2.4"'

# Common services and possibility to use Yaml merge anchors
# Stick to env operated file only
test -f "$DOCKER_ROOT/containers/compose.yml" && cat "$_" || true
echo

echo 'services:'
# name, sequence
# Remove .0 suffix if we have only one container of such type
get_container_name() {
  container_name="$1.$2"
  if [[ ${SCALE_MAP[$1]:-0} == 0 ]]; then
    container_name=$1
  fi

  echo -n "$container_name"
}

for p in ${!SCALE_MAP[*]}; do
  for i in $(seq 0 ${SCALE_MAP[$p]:-0}); do
    output=()
    container_name=$(get_container_name "$p" "$i")
    container_path=${p//./\/}
    output+=(
      "  $container_name:"
      "    container_name: ${COMPOSE_PROJECT_NAME}.$container_name"
    )

    # Try to find container file
    container_file="$DOCKER_ROOT/containers/$container_path/container.yml"
    test ! -f "$container_file" && container_file=${container_file%/*}.yml

    if [[ ! -f "$container_file" ]]; then
      >&2 echo "Cannot find configuration file for container: $p"
      exit 1
    fi

    # If we have nested container we check syntax that this file used only for YAML anchors
    root_container_file="$DOCKER_ROOT/containers/${container_path%%/*}/container.yml"
    yaml_anchor=
    if [[ -f "$root_container_file" && "$root_container_file" != "$container_file" ]]; then
      yaml_anchor="${container_name//./_}"
      output+=( "    x-$yaml_anchor: &$yaml_anchor" )
      output+=( "$( compile_config "$root_container_file" 6 )" )
    fi

    output+=( "$( compile_config "$container_file" 4 )" )

    # Extend root container if we have namespaces
    if [[ -n "$yaml_anchor" ]]; then
      output+=( "    <<: *${yaml_anchor}" )
    fi

    # Set default network mode if we not redefine it
    if [[ ${output[*]} != *network_mode:* && ${output[*]} != *networks:* ]]; then
      output+=( "    <<: *default_${ENV}_networks" )
    fi

    # Set default restart mode if we not redefine it
    if [[ ${output[*]} != *restart:* ]]; then
      output+=( "    <<: *default_${ENV}_restart" )
    fi

    # Set default hostname if not set
    if [[ ${output[*]} != *hostname:* ]]; then
        container_hostname=$(echo "$container_name" | cut -c -63)
        output+=( "    hostname: $container_hostname" )
    fi

    echo
    printf "%s\n" "${output[@]}"
  done
done
