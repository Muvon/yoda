#!/usr/bin/env bash
set -e

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

if [[ -n "$REGISTRY_URL" ]]; then
  echo "Using docker registry: $REGISTRY_URL"
fi

declare -A image_names
declare -A image_ids
declare -A image_build_args
declare -A image_build_context
mapfile -t lines < "$DOCKER_ROOT/Buildfile"
for line in "${lines[@]}"; do
  image=$(echo $line | grep -Eo '\-t [^ ]+' | cut -d' ' -f2)
  image_id=$(eval echo $image)
  name=${line%%:*}
  args=$(eval echo ${line#*:})

  [[ $name =~ ^([^\[]*)(\[(.*)\])?$ ]]
  name=${BASH_REMATCH[1]}
  context=${BASH_REMATCH[3]:-.}

  image_ids[$name]=$image_id

  extra_args=()
  if [[ -n "$no_cache" ]]; then
    extra_args+=('--no-cache')
  fi
  image_build_args[$name]="${extra_args[*]} $args"
  image_build_context[$name]="$context"
  image_names[$name]=$name
done

if [[ -z "$*" ]]; then
  for name in "${image_names[@]}"; do
    original_args+=" $name"
  done
  $YODA_CMD build $original_args
else
  if [[ ! $force ]]; then
    trap unlock EXIT
  fi
  lock

  for image_for_build in "$@"; do
    echo -n "Image '${image_ids[$image_for_build]}' is "
    docker_image_id=$(docker images -q "${image_ids[$image_for_build]}")
    if [[ -z "$docker_image_id" || -n "$rebuild" ]]; then
      echo 'building.'
      docker build --network host "${image_build_args[$image_for_build]}" -f "$DOCKER_ROOT/images/Dockerfile-$image_for_build" "${image_build_context[$image_for_build]}"
    else
      echo 'built already.'
    fi

    # If we had setup REPOSITORY_URL and should push
    if [[ -n "$push" && -n "$REGISTRY_URL" ]]; then
      docker tag "${image_ids[$image_for_build]}" "$REGISTRY_URL/${image_ids[$image_for_build]}"
      docker push "$REGISTRY_URL/${image_ids[$image_for_build]}"
    fi
  done
fi
