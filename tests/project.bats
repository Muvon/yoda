load helpers

setup() {
  PROJECT_DIR=$(mktemp -d)
  cd "$PROJECT_DIR"
}

teardown() {
  rm -rf "$PROJECT_DIR"
}

@test "init creates the deployment skeleton" {
  run "$YODA" init
  [ "$status" -eq 0 ]
  local f
  for f in .yodarc env.sh Envfile Buildfile Startfile .gitignore .dockerignore \
           containers/compose.yml images/Dockerfile-base; do
    [ -f "docker/$f" ]
  done
  [ -d docker/images ]
  [ -d docker/containers ]
  [ -d docker/.ssh ]
}

@test "init renders .yodarc with the project name and current version" {
  run "$YODA" init
  [ "$status" -eq 0 ]
  local version
  version=$(sed -n "s/^YODA_SOURCE_VERSION='\(.*\)'$/\1/p" "$YODA")
  grep -Fq "\"${PROJECT_DIR##*/}\"" docker/.yodarc
  grep -Fq "YODA_VERSION=\"$version\"" docker/.yodarc
}

@test "init refuses to overwrite an initialized project" {
  "$YODA" init >/dev/null
  run "$YODA" init
  [ "$status" -eq 1 ]
  grep -q "initialized already" <<<"$output"
}

@test "init refuses an existing folder name" {
  mkdir docker
  run "$YODA" init
  [ "$status" -eq 1 ]
  grep -q "already exists" <<<"$output"
}

@test "add creates a container skeleton and registers it in the Envfile" {
  "$YODA" init >/dev/null
  run "$YODA" add nginx
  [ "$status" -eq 0 ]
  [ -f docker/containers/nginx/container.yml ]
  [ -f docker/containers/nginx/entrypoint ]
  grep -q "role=nginx" docker/containers/nginx/container.yml
  grep -q "nginx" docker/Envfile
}

@test "add skips containers that already exist" {
  "$YODA" init >/dev/null
  "$YODA" add nginx >/dev/null
  run "$YODA" add nginx
  [ "$status" -eq 0 ]
  grep -q "Container exists" <<<"$output"
}

@test "add without a name suggests the usage" {
  "$YODA" init >/dev/null
  run "$YODA" add
  [ "$status" -eq 1 ]
  grep -q "Did you mean" <<<"$output"
}

@test "delete removes the container skeleton and unregisters it" {
  "$YODA" init >/dev/null
  "$YODA" add nginx >/dev/null
  run "$YODA" delete nginx
  [ "$status" -eq 0 ]
  [ ! -e docker/containers/nginx ]
  ! grep -q "nginx" docker/Envfile
}

@test "compose renders services for the current environment" {
  "$YODA" init >/dev/null
  "$YODA" add nginx >/dev/null
  run "$YODA" compose
  [ "$status" -eq 0 ]
  grep -q "^services:" <<<"$output"
  grep -Fq "x-dev-networks: &default_dev_networks" <<<"$output"
  grep -Fq "  nginx:" <<<"$output"
  grep -Fq "container_name: ${PROJECT_DIR##*/}.nginx" <<<"$output"
  grep -Fq 'image: ${COMPOSE_PROJECT_NAME}/base:${REVISION}' <<<"$output"
  grep -Fq "<<: [*default_dev_networks,*default_dev_restart]" <<<"$output"
  grep -Fq "hostname: nginx" <<<"$output"
}

@test "compose fails when the stack has no services" {
  "$YODA" init >/dev/null
  run "$YODA" compose
  [ "$status" -eq 1 ]
  grep -q "No services to build" <<<"$output"
}

@test "start brings up every service when none is named" {
  "$YODA" init >/dev/null
  "$YODA" add nginx >/dev/null

  DOCKER_LOG="$PROJECT_DIR/docker.log"
  mkdir "$PROJECT_DIR/bin"
  printf '#!/usr/bin/env bash\necho "$*" >> %q\n' "$DOCKER_LOG" > "$PROJECT_DIR/bin/docker"
  chmod +x "$PROJECT_DIR/bin/docker"
  export PATH="$YODA_ROOT:$PROJECT_DIR/bin:$PATH"

  run "$YODA" start
  [ "$status" -eq 0 ]
  grep -qx "compose up --no-build --remove-orphans -d" "$DOCKER_LOG"
}

@test "start brings up only the named service" {
  "$YODA" init >/dev/null
  "$YODA" add nginx >/dev/null

  DOCKER_LOG="$PROJECT_DIR/docker.log"
  mkdir "$PROJECT_DIR/bin"
  printf '#!/usr/bin/env bash\necho "$*" >> %q\n' "$DOCKER_LOG" > "$PROJECT_DIR/bin/docker"
  chmod +x "$PROJECT_DIR/bin/docker"
  export PATH="$YODA_ROOT:$PROJECT_DIR/bin:$PATH"

  run "$YODA" start nginx
  [ "$status" -eq 0 ]
  grep -qx "compose up --no-build --remove-orphans -d nginx" "$DOCKER_LOG"
}

@test "stop stops every service when none is named" {
  "$YODA" init >/dev/null
  "$YODA" add nginx >/dev/null

  DOCKER_LOG="$PROJECT_DIR/docker.log"
  mkdir "$PROJECT_DIR/bin"
  printf '#!/usr/bin/env bash\necho "$*" >> %q\n' "$DOCKER_LOG" > "$PROJECT_DIR/bin/docker"
  chmod +x "$PROJECT_DIR/bin/docker"
  export PATH="$YODA_ROOT:$PROJECT_DIR/bin:$PATH"

  run "$YODA" stop
  [ "$status" -eq 0 ]
  grep -qx "compose stop -t 10" "$DOCKER_LOG"
}
