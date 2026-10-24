load helpers

setup() {
  DOCKER_ROOT=$(mktemp -d)
  UPGRADES=$(mktemp -d)
  export DOCKER_ROOT COMPOSE_PROJECT_NAME=proj
  # Each fake upgrade script records that it ran
  local v
  for v in 2.4 2.5 2.6.0 2.9.1 2.10.0 2.11.0; do
    printf '#!/usr/bin/env bash\necho %s >> %q\n' "$v" "$UPGRADES/ran" > "$UPGRADES/version-$v"
    chmod +x "$UPGRADES/version-$v"
  done
}

teardown() {
  rm -rf "$DOCKER_ROOT" "$UPGRADES"
}

@test "upgrade runs the scripts newer than the project, oldest first" {
  YODA_VERSION=2.5 YODA_SOURCE_VERSION=2.10.0 run bash "$YODA_ROOT/src/upgrade.sh" "$UPGRADES"
  [ "$status" -eq 0 ]
  [ "$(cat "$UPGRADES/ran")" = "$(printf '2.6.0\n2.9.1\n2.10.0')" ]
  grep -Fq 'YODA_VERSION="2.10.0"' "$DOCKER_ROOT/.yodarc"
}

@test "upgrade pins the installed version when no script matches" {
  YODA_VERSION=2.11.0 YODA_SOURCE_VERSION=2.11.1 run bash "$YODA_ROOT/src/upgrade.sh" "$UPGRADES"
  [ "$status" -eq 0 ]
  [ ! -e "$UPGRADES/ran" ]
  grep -Fq 'YODA_VERSION="2.11.1"' "$DOCKER_ROOT/.yodarc"
}

@test "upgrade treats x.y and x.y.0 as the same version" {
  YODA_VERSION=2.5 YODA_SOURCE_VERSION=2.5.0 run bash "$YODA_ROOT/src/upgrade.sh" "$UPGRADES"
  [ "$status" -eq 0 ]
  grep -q "No upgrades found" <<<"$output"
  [ ! -e "$DOCKER_ROOT/.yodarc" ]
}
