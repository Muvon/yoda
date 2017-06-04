#!/usr/bin/env bash
set -e

lock_file="$DOCKER_ROOT/.build.lock"
lock() {
  touch $lock_file
}

unlock() {
  test -f $lock_file && rm -f $_
}

if [[ -f $lock_file ]]; then
  >&2 echo "Build is already in progress."
  >&2 echo "If something went wrong you should just remove lock file: $lock_file"
  exit 1
fi

trap unlock EXIT
lock

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
  esac
done

# Get images we should build
declare -A images
for image in "$@"; do
  images[$image]=1
done

if [[ -n "$REGISTRY_URL" ]]; then
  echo "Using docker registry: $REGISTRY_URL"
fi

mapfile -t lines < $DOCKER_ROOT/Buildfile
for line in "${lines[@]}"; do
  build_image=$(echo $line | grep -Eo '\-t [^ ]+' | cut -d' ' -f2)
  image=$(eval echo $build_image)
  echo -n "Image '$image' is "
  build_id=${line%%:*}
  # Skip images that we dont need to build
  if [[ -n "${images[*]}" && -z "${images[$build_image]}" && -z "${images[$build_id]}" ]]; then
    echo 'skipped.'
    continue
  fi

  image_id=$(docker images -q $image)
  if [[ -z "$image_id" || -n "$rebuild" ]]; then
    name=${line%%:*}
    build_args=${line#*:}
    extra_args=()
    if [[ -n "$no_cache" ]]; then
      extra_args+=('--no-cache')
    fi
    echo 'building.'
    docker build --network host ${extra_args[*]} $(eval echo $build_args) -f "$DOCKER_ROOT/images/Dockerfile-$name" .
  else
    echo 'built already.'
  fi

  # If we had setup REPOSITORY_URL and should push
  if [[ -n "$push" && -n "$REGISTRY_URL" ]]; then
    docker tag "$image" "$REGISTRY_URL/$image"
    docker push "$REGISTRY_URL/$image"
  fi
done
