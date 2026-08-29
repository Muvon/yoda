load ../helpers
source "$YODA_ROOT/lib/migration.sh"

@test "update_yodarc renders .yodarc with project name and yoda version" {
  local dir
  dir=$(mktemp -d)
  export DOCKER_ROOT="$dir" COMPOSE_PROJECT_NAME=myproj YODA_SOURCE_VERSION=9.9
  run update_yodarc
  [ "$status" -eq 0 ]
  grep -Fq 'COMPOSE_PROJECT_NAME=${COMPOSE_PROJECT_NAME:-"myproj"}' "$dir/.yodarc"
  grep -Fq 'YODA_VERSION="9.9"' "$dir/.yodarc"
  rm -rf "$dir"
}
