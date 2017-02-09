#!/usr/bin/env bash
set -e

change_version() {
  old=$1
  new=$2

  if [[ -z "$old" || -z "$new" ]]; then
    >&2 echo 'Usage: change_version "1.0" "1.1"'
    return 1
  fi

  rcfile=$DOCKER_ROOT/.yodarc
  cat $rcfile | sed 's|\(YODA_VERSION=\)"'$old'"|\1"'$new'"|g' > $rcfile.swp
  mv -f $rcfile.swp $rcfile
}
