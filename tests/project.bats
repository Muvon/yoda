load helpers

setup() {
  PROJECT_DIR=$(mktemp -d)
  cd "$PROJECT_DIR"
}

teardown() {
  rm -rf "$PROJECT_DIR"
}

# Record every docker call instead of running it: joined in $DOCKER_LOG,
# one <arg> per argument in $DOCKER_ARGV
stub_docker() {
  DOCKER_LOG="$PROJECT_DIR/docker.log"
  DOCKER_ARGV="$PROJECT_DIR/docker.argv"
  mkdir -p "$PROJECT_DIR/bin"
  printf '#!/usr/bin/env bash\necho "$*" >> %q\nprintf "<%%s>" "$@" >> %q\necho >> %q\n' \
    "$DOCKER_LOG" "$DOCKER_ARGV" "$DOCKER_ARGV" > "$PROJECT_DIR/bin/docker"
  chmod +x "$PROJECT_DIR/bin/docker"
  export PATH="$YODA_ROOT:$PROJECT_DIR/bin:$PATH"
}

# Record the script deploy sends over ssh in $SSH_LOG instead of running it
stub_deploy() {
  SSH_LOG="$PROJECT_DIR/ssh.log"
  mkdir -p "$PROJECT_DIR/bin" "$PROJECT_DIR/home/.ssh"
  printf '#!/usr/bin/env bash\ncat >> %q\n' "$SSH_LOG" > "$PROJECT_DIR/bin/ssh"
  printf '#!/usr/bin/env bash\n' > "$PROJECT_DIR/bin/tput"
  chmod +x "$PROJECT_DIR/bin/ssh" "$PROJECT_DIR/bin/tput"
  printf 'node.example.com\ngit.example.com\n' > "$PROJECT_DIR/home/.ssh/known_hosts"
  export HOME="$PROJECT_DIR/home" PATH="$YODA_ROOT:$PROJECT_DIR/bin:$PATH"

  git init -q .
  git remote add origin git@git.example.com:acme/app.git
  printf 'box@node.example.com: production\nproduction: nginx\n' >> docker/Envfile
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

@test "compose pipes each container template through the compose script" {
  "$YODA" init >/dev/null
  "$YODA" add nginx >/dev/null
  printf '#!/usr/bin/env bash\nsed "s/role=nginx/role=$1 $2/"\n' > docker/compose-slot
  chmod +x docker/compose-slot

  run "$YODA" compose "$PROJECT_DIR/docker/compose-slot"
  [ "$status" -eq 0 ]
  grep -Fq "role=--name=nginx --sequence=0" <<<"$output"
}

@test "compose fails when the compose script is not executable" {
  "$YODA" init >/dev/null
  "$YODA" add nginx >/dev/null
  printf '#!/usr/bin/env bash\ncat\n' > docker/compose-slot

  run "$YODA" compose "$PROJECT_DIR/docker/compose-slot"
  [ "$status" -eq 1 ]
  grep -Fq "compose-slot is found but its not executable" <<<"$output"
  ! grep -q "^services:" <<<"$output"
}

@test "compose fails when the compose script is missing" {
  "$YODA" init >/dev/null
  "$YODA" add nginx >/dev/null

  run "$YODA" compose "$PROJECT_DIR/docker/compose-slot"
  [ "$status" -eq 1 ]
  grep -Fq "Compose script $PROJECT_DIR/docker/compose-slot is not found." <<<"$output"
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
  stub_docker

  run "$YODA" start
  [ "$status" -eq 0 ]
  grep -qx "compose up --no-build --remove-orphans -d" "$DOCKER_LOG"
}

@test "start brings up only the named service" {
  "$YODA" init >/dev/null
  "$YODA" add nginx >/dev/null
  stub_docker

  run "$YODA" start nginx
  [ "$status" -eq 0 ]
  grep -qx "compose up --no-build --remove-orphans -d nginx" "$DOCKER_LOG"
}

@test "start passes every named container to compose as its own argument" {
  "$YODA" init >/dev/null
  "$YODA" add nginx php >/dev/null
  stub_docker

  run "$YODA" start nginx php
  [ "$status" -eq 0 ]
  grep -qx "<compose><up><--no-build><--remove-orphans><-d><nginx><php>" "$DOCKER_ARGV"
}

@test "start --keep-orphans leaves orphan containers running" {
  "$YODA" init >/dev/null
  "$YODA" add nginx >/dev/null
  stub_docker

  run "$YODA" start --rebuild --keep-orphans nginx
  [ "$status" -eq 0 ]
  grep -qx "compose up --no-build -d nginx" "$DOCKER_LOG"
  ! grep -q -- "--remove-orphans" "$DOCKER_LOG"
}

@test "start --wait waits for started containers to be running and healthy" {
  "$YODA" init >/dev/null
  "$YODA" add nginx >/dev/null
  stub_docker

  run "$YODA" start --wait nginx
  [ "$status" -eq 0 ]
  grep -qx "compose up --no-build --remove-orphans --wait -d nginx" "$DOCKER_LOG"
}

@test "start stops Startfile stop services with each service's own grace" {
  "$YODA" init >/dev/null
  "$YODA" add nginx >/dev/null
  printf 'dev:\n  stop: nginx\n  flow:\n  wait:\n' > docker/Startfile
  stub_docker

  STOP_WAIT_TIMEOUT= run "$YODA" start
  [ "$status" -eq 0 ]
  grep -qx "<compose><stop><nginx>" "$DOCKER_ARGV"
}

@test "start stops Startfile stop services within STOP_WAIT_TIMEOUT" {
  "$YODA" init >/dev/null
  "$YODA" add nginx >/dev/null
  printf 'dev:\n  stop: nginx\n  flow:\n  wait:\n' > docker/Startfile
  stub_docker

  STOP_WAIT_TIMEOUT=30 run "$YODA" start
  [ "$status" -eq 0 ]
  grep -qx "<compose><stop><-t><30><nginx>" "$DOCKER_ARGV"
}

@test "start resolves Startfile services of a dotted project name" {
  "$YODA" init >/dev/null
  "$YODA" add nginx php >/dev/null
  printf 'dev: nginx=2 php\n' > docker/Envfile
  printf 'dev:\n  stop: nginx\n  flow: nginx\n  wait:\n' > docker/Startfile
  stub_docker
  export COMPOSE_PROJECT_NAME=my.app

  STOP_WAIT_TIMEOUT= run "$YODA" start
  [ "$status" -eq 0 ]
  grep -qx "<compose><stop><nginx.0><nginx.1>" "$DOCKER_ARGV"
  grep -qx "<compose><up><--no-build><--remove-orphans><-d><nginx.0><nginx.1>" "$DOCKER_ARGV"
  grep -qx "<compose><up><--no-build><--remove-orphans><-d><php>" "$DOCKER_ARGV"
}

@test "stop leaves the grace to each service when STOP_WAIT_TIMEOUT is empty" {
  "$YODA" init >/dev/null
  "$YODA" add nginx >/dev/null
  stub_docker

  STOP_WAIT_TIMEOUT= run "$YODA" stop
  [ "$status" -eq 0 ]
  grep -qx "<compose><stop>" "$DOCKER_ARGV"
}

@test "stop waits STOP_WAIT_TIMEOUT for only the named container" {
  "$YODA" init >/dev/null
  "$YODA" add nginx php >/dev/null
  stub_docker

  STOP_WAIT_TIMEOUT=90 run "$YODA" stop nginx
  [ "$status" -eq 0 ]
  grep -qx "<compose><stop><-t><90><nginx>" "$DOCKER_ARGV"
}

@test "deploy checks out the passed revision" {
  "$YODA" init >/dev/null
  stub_deploy

  run "$YODA" deploy --env=production --branch=master --rev=abc1234
  [ "$status" -eq 0 ]
  grep -qx "    git checkout -qf --detach abc1234" "$SSH_LOG"
  grep -Fq "REVISION=abc1234 " "$SSH_LOG"
}

@test "deploy without a revision deploys the branch head" {
  "$YODA" init >/dev/null
  stub_deploy

  run "$YODA" deploy --env=production --branch=master
  [ "$status" -eq 0 ]
  grep -Fq "git checkout -f master && git reset --hard origin/master" "$SSH_LOG"
  ! grep -q -- "--detach" "$SSH_LOG"
}
