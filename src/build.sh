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
mapfile -t lines < $DOCKER_ROOT/Buildfile
for line in "${lines[@]}"; do
  image=$(echo $line | grep -Eo '\-t [^ ]+' | cut -d' ' -f2)
  image_id=$(eval echo $image)
  name=${line%%:*}
  image_ids[$name]=$image_id

  args=$(eval echo ${line#*:})
  extra_args=()
  if [[ -n "$no_cache" ]]; then
    extra_args+=('--no-cache')
  fi
  image_build_args[$name]="${extra_args[*]} $(eval echo ${line#*:})"
  image_names[$name]=$name
done

builded() {
  if grep "^$@$" $lock_file $2>1 ; then
    return 0
  fi
  return 1
}

if [[ ! -n "$@" ]]; then
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
    if $(builded $image_for_build) || [[ ! -f $DOCKER_ROOT/images/Dockerfile-$image_for_build ]] ; then
      continue
    else
      newline=$'\n'
      build_instructions=""
      mapfile -t deps < $DOCKER_ROOT/images/Dockerfile-$image_for_build
      for line in "${deps[@]}"; do
        if [[ $line =~ ^FROM.* ]]; then
          dep_name=$(echo $line | grep -Eo 'FROM [^ ]+' | cut -d' ' -f2)
          if [[ "${image_names[$dep_name]}" == $dep_name ]]; then
            if ! $(builded $dep_name) ; then
              args=('--force')
              if [[ -n "$rebuild" ]]; then
                args+=('--rebuild')
              fi
              if [[ -n "$no_cache" ]]; then
                args+=('--no-cache')
              fi
              if [[ -n "$push" ]]; then
                args+='--push'
              fi

              $YODA_CMD build ${args[*]} $dep_name
            fi

            new_line=$(echo $line | sed -e "s@$dep_name@${image_ids[$dep_name]}@")
            build_instructions+="$new_line${newline}"
          else
            build_instructions+="$line${newline}"
          fi
        else
          build_instructions+="$line${newline}"
        fi
      done

      echo -n "Image '${image_ids[$image_for_build]}' is "

      docker_image_id=$(docker images -q "${image_ids[$image_for_build]}")
      if [[ -z "$docker_image_id" || -n "$rebuild" ]]; then
        echo 'building.'
        echo "$build_instructions" | docker build --network host ${image_build_args[$image_for_build]} -f - .
      else
        echo 'built already.'
      fi

    fi

    # If we had setup REPOSITORY_URL and should push
    if [[ -n "$push" && -n "$REGISTRY_URL" ]]; then
      docker tag "${image_ids[$image_for_build]}" "$REGISTRY_URL/${image_ids[$image_for_build]}"
      docker push "$REGISTRY_URL/${image_ids[$image_for_build]}"
    fi

    echo $image_for_build >> $lock_file
  done
fi
