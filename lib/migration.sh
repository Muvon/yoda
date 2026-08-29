#!/usr/bin/env bash
# shellcheck disable=SC2154  # env vars are exported by the parent yoda process
set -e

update_yodarc() {
  sed "s/{{name}}/$COMPOSE_PROJECT_NAME/g;s/{{yoda_version}}/$YODA_SOURCE_VERSION/g" "$YODA_PATH/templates/yodarc" > "$DOCKER_ROOT/.yodarc"

}
