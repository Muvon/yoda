#!/usr/bin/env bash
set -e

# shellcheck disable=SC1091 source=../lib/array.sh
source "$YODA_PATH/lib/string.sh"

lock_file="$DOCKER_ROOT/.build.lock"
lock() {
  touch $lock_file
}

unlock() {
  test -f $lock_file && rm -f $_
}

original_args=$@

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
    --push)
      push=1
      shift
      ;;
    --force)
      force=1
      shift
      ;;
  esac
done

if [[ -f $lock_file && ! $force ]]; then
  >&2 echo "Build is already in progress."
  >&2 echo "If something went wrong you should just remove lock file: $lock_file"
  exit 1
fi

if [[ ! $force ]]; then
  trap unlock EXIT
fi
lock

# Get images we should build
declare -A images
for image in "$@"; do
  images[$image]=1
done

if [[ -n "$REGISTRY_URL" ]]; then
  echo "Using docker registry: $REGISTRY_URL"
fi

mapfile -t lines < "$DOCKER_ROOT/Buildfile"
for line in "${lines[@]}"; do
  image=$(echo "$line" | grep -Eo '\-t [^ ]+' | cut -d' ' -f2)
  image_id=$(eval echo "$image")

  name=${line%%:*}
  [[ $name =~ ^([^\[]*)(\[(.*)\])?$ ]]
  name=${BASH_REMATCH[1]}
  context=${BASH_REMATCH[3]:-.}

  echo -n "Image '$image_id' is "
  if [[ -n "${images[*]}" && -z "${images[$name]}" ]]; then
    echo 'skipped.'
    continue
  fi

  docker_image_id=$(docker images -q "$image_id")
  if [[ -z "$docker_image_id" || -n "$rebuild" ]]; then
    echo 'building.'

    build_args=$(eval echo ${line#*:})
    extra_args=()
    if [[ -n "$no_cache" ]]; then
      extra_args+=('--no-cache')
    fi

    content="$(cat "$DOCKER_ROOT/images/Dockerfile-$name")"
    matches=( "$(echo "$content" | grep -Eo "$YODA_VAR_REGEX" | cat)" )

    for match in "${matches[@]}"; do
      var=$(eval echo "\$${match:2:-1}")
      content="${content//"$match"/"$var"}"
    done
    echo "$content" | \
      docker build --network host ${extra_args[*]} $(eval echo "$build_args") -f - "$context"
  else
    echo 'built already.'
  fi

  # If we had setup REPOSITORY_URL and should push
  if [[ -n "$push" && -n "$REGISTRY_URL" ]]; then
    docker tag "$image_id" "$REGISTRY_URL/$image_id"
    docker push "$REGISTRY_URL/$image_id"
  fi
done
