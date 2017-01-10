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

for p in $*; do
  case $p in
    --rebuild)
      rebuild=1
      shift
      ;;
  esac
done

# Get images we should build
declare -A images
for image in $*; do
  images[$image]=1
done

mapfile -t lines < $DOCKER_ROOT/Buildfile
for line in "${lines[@]}"; do
  build_image=$(echo $line | grep -Eo '\-t [^ ]+' | cut -d' ' -f2)
  image=$(eval echo $build_image)
  build_id=${line%%:*}
  # Skip images that we dont need to build
  if [[ -n "${images[*]}" && -z "${images[$build_image]}" && -z "${images[$build_id]}" ]]; then
    echo "Image '$image' is skipped."
    continue
  fi

  image_id=$(docker images -q $image)
  if [[ -z "$image_id" || -n "$rebuild" ]]; then
    name=${line%%:*}
    build_args=${line#*:}
    docker build $(eval echo $build_args) -f "$DOCKER_ROOT/images/Dockerfile-$name" .
  else
    echo "Image '$image' exists already."
  fi
done
