load helpers

setup() {
  PROJECT_DIR=$(mktemp -d)
  cd "$PROJECT_DIR"
}

teardown() {
  rm -rf "$PROJECT_DIR"
}

# Record every docker call instead of running it: joined in $DOCKER_LOG,
# one <arg> per argument in $DOCKER_ARGV. 'docker wait' prints
# $DOCKER_WAIT_CODE (default 0) once per container.
stub_docker() {
  DOCKER_LOG="$PROJECT_DIR/docker.log"
  DOCKER_ARGV="$PROJECT_DIR/docker.argv"
  mkdir -p "$PROJECT_DIR/bin"
  printf '#!/usr/bin/env bash\necho "$*" >> %q\nprintf "<%%s>" "$@" >> %q\necho >> %q\n' \
    "$DOCKER_LOG" "$DOCKER_ARGV" "$DOCKER_ARGV" > "$PROJECT_DIR/bin/docker"
  printf '[[ $1 == wait ]] && for _ in "${@:2}"; do echo "${DOCKER_WAIT_CODE:-0}"; done\nexit 0\n' \
    >> "$PROJECT_DIR/bin/docker"
  chmod +x "$PROJECT_DIR/bin/docker"
  export PATH="$YODA_ROOT:$PROJECT_DIR/bin:$PATH"
}

# Record the script deploy sends over ssh in $SSH_LOG instead of running it;
# a command passed as an argument (rollback) runs locally in the fake $HOME
stub_deploy() {
  SSH_LOG="$PROJECT_DIR/ssh.log"
  mkdir -p "$PROJECT_DIR/bin" "$PROJECT_DIR/home/.ssh"
  cat > "$PROJECT_DIR/bin/ssh" <<EOF
#!/usr/bin/env bash
while [[ \$1 == -* ]]; do [[ \$1 == -o ]] && shift; shift; done
shift
if [[ \$# -gt 0 ]]; then cd "\$HOME" && bash -c "\$*"; else cat >> "$SSH_LOG"; fi
EOF
  printf '#!/usr/bin/env bash\n' > "$PROJECT_DIR/bin/tput"
  chmod +x "$PROJECT_DIR/bin/ssh" "$PROJECT_DIR/bin/tput"
  printf 'node.example.com\ngit.example.com\n' > "$PROJECT_DIR/home/.ssh/known_hosts"
  export HOME="$PROJECT_DIR/home" PATH="$YODA_ROOT:$PROJECT_DIR/bin:$PATH"

  git init -q .
  git remote add origin git@git.example.com:acme/app.git
  printf 'box@node.example.com: production\nproduction: nginx\n' >> docker/Envfile
}

# Copy Yoda without its .git, the way a release tarball (e.g. Homebrew) installs it
release_copy() {
  YODA_RELEASE="$PROJECT_DIR/release"
  mkdir -p "$YODA_RELEASE"
  cp -R "$YODA_ROOT"/{yoda,lib,src,templates,upgrades} "$YODA_RELEASE"
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

@test "add creates a nested container in a nested folder that compose finds" {
  "$YODA" init >/dev/null
  "$YODA" add worker worker.mail >/dev/null
  [ -f docker/containers/worker/mail/container.yml ]
  [ -f docker/containers/worker/mail/entrypoint ]
  grep -Fq "entrypoint: /src/docker/containers/worker/mail/entrypoint" docker/containers/worker/mail/container.yml
  grep -Fq "role=worker.mail" docker/containers/worker/mail/container.yml

  run "$YODA" compose
  [ "$status" -eq 0 ]
  grep -Fq "  worker.mail:" <<<"$output"
  grep -Fq "x-worker_mail: &worker_mail" <<<"$output"
}

@test "add appends to a block list dev environment" {
  "$YODA" init >/dev/null
  printf 'dev:\n  - nginx\nproduction: nginx\n' > docker/Envfile
  "$YODA" add php >/dev/null
  [ "$(cat docker/Envfile)" = "$(printf 'dev:\n  - nginx\n  - php\nproduction: nginx')" ]
}

@test "delete removes only the exact container name from every environment" {
  "$YODA" init >/dev/null
  printf 'box@node: production\ndev: webapp web=2 php\nproduction:\n  - web\n  - webapp\n' > docker/Envfile
  run "$YODA" delete web
  [ "$status" -eq 0 ]
  [ "$(cat docker/Envfile)" = "$(printf 'box@node: production\ndev: webapp php\nproduction:\n  - webapp')" ]
}

@test "start reads the Startfile of a custom yoda folder" {
  "$YODA" init deploy >/dev/null
  "$YODA" add nginx >/dev/null
  printf 'dev:\n  stop: nginx\n  flow:\n  wait:\n' > deploy/Startfile
  stub_docker

  STOP_WAIT_TIMEOUT= run "$YODA" start
  [ "$status" -eq 0 ]
  grep -qx "<compose><stop><nginx>" "$DOCKER_ARGV"
}

@test "start prefers the env.stack section of the Startfile" {
  "$YODA" init >/dev/null
  "$YODA" add web worker >/dev/null
  printf 'production.front: web\nproduction.back: worker\n' > docker/Envfile
  printf 'production:\n  stop: worker\n  flow:\n  wait:\nproduction.front:\n  stop: web\n  flow:\n  wait:\n' > docker/Startfile
  stub_docker

  ENV=production STACK=front STOP_WAIT_TIMEOUT= run "$YODA" start
  [ "$status" -eq 0 ]
  grep -qx "<compose><stop><web>" "$DOCKER_ARGV"
}

@test "start applies a shared env section only to the services a stack runs" {
  "$YODA" init >/dev/null
  "$YODA" add web worker >/dev/null
  printf 'production.front: web\nproduction.back: worker\n' > docker/Envfile
  printf 'production:\n  stop: worker\n  flow: web\n  wait:\n' > docker/Startfile
  stub_docker

  ENV=production STACK=front STOP_WAIT_TIMEOUT= run "$YODA" start
  [ "$status" -eq 0 ]
  grep -q "Skipping service 'worker' of section 'stop'" <<<"$output"
  grep -q "Starting services by flow: web" <<<"$output"
  ! grep -q "<compose><stop>" "$DOCKER_ARGV"
}

@test "start aborts on a Startfile service that does not exist" {
  "$YODA" init >/dev/null
  "$YODA" add nginx >/dev/null
  printf 'dev:\n  stop:\n  flow: nginz\n  wait:\n' > docker/Startfile
  stub_docker

  run "$YODA" start
  [ "$status" -eq 1 ]
  grep -q "No service 'nginz' of section 'flow'" <<<"$output"
  ! grep -q "compose up" "$DOCKER_LOG"
}

@test "start starts flow chunks whatever the Envfile count" {
  "$YODA" init >/dev/null
  "$YODA" add nginx >/dev/null
  printf 'dev: nginx=4\n' > docker/Envfile
  printf 'dev:\n  stop:\n  flow: nginx=2\n  wait:\n' > docker/Startfile
  stub_docker

  run "$YODA" start
  [ "$status" -eq 0 ]
  grep -qx "<compose><up><--no-build><--remove-orphans><-d><nginx.0><nginx.1>" "$DOCKER_ARGV"
  grep -qx "<compose><up><--no-build><--remove-orphans><-d><nginx.2><nginx.3>" "$DOCKER_ARGV"
}

@test "start waits for every container of a scaled wait service" {
  "$YODA" init >/dev/null
  "$YODA" add job web >/dev/null
  printf 'dev: job=2 web\n' > docker/Envfile
  printf 'dev:\n  stop:\n  flow: job web\n  wait: job\n' > docker/Startfile
  stub_docker

  run "$YODA" start
  [ "$status" -eq 0 ]
  grep -qx "<wait><${PROJECT_DIR##*/}.job.0><${PROJECT_DIR##*/}.job.1>" "$DOCKER_ARGV"
  grep -qx "<compose><up><--no-build><--remove-orphans><-d><web>" "$DOCKER_ARGV"
}

@test "start aborts when a wait container exits with an error" {
  "$YODA" init >/dev/null
  "$YODA" add job web >/dev/null
  printf 'dev: job web\n' > docker/Envfile
  printf 'dev:\n  stop:\n  flow: job web\n  wait: job\n' > docker/Startfile
  stub_docker

  DOCKER_WAIT_CODE=3 run "$YODA" start
  [ "$status" -eq 1 ]
  grep -q "Start is aborted" <<<"$output"
  ! grep -q "<web>" "$DOCKER_ARGV"
}

@test "a hook that execs yoda runs the built-in step once" {
  "$YODA" init >/dev/null
  "$YODA" add nginx >/dev/null
  export PATH="$YODA_ROOT:$PATH"
  printf '#!/usr/bin/env bash\necho run >> %q\n[[ $(wc -l < %q) -gt 1 ]] && exit 1\nexec yoda compose "$@"\n' \
    "$PROJECT_DIR/hook.runs" "$PROJECT_DIR/hook.runs" > docker/compose
  chmod +x docker/compose

  run "$YODA" compose
  [ "$status" -eq 0 ]
  grep -q "^services:" <<<"$output"
  [ "$(wc -l < hook.runs | tr -d ' ')" -eq 1 ]
}

@test "a hook that calls yoda as a child runs the built-in step once" {
  "$YODA" init >/dev/null
  "$YODA" add nginx >/dev/null
  export PATH="$YODA_ROOT:$PATH"
  printf '#!/usr/bin/env bash\necho run >> %q\n[[ $(wc -l < %q) -gt 1 ]] && exit 1\nyoda compose "$@"\n' \
    "$PROJECT_DIR/hook.runs" "$PROJECT_DIR/hook.runs" > docker/compose
  chmod +x docker/compose

  run "$YODA" compose
  [ "$status" -eq 0 ]
  grep -q "^services:" <<<"$output"
  [ "$(wc -l < hook.runs | tr -d ' ')" -eq 1 ]
}

@test "deploy clones Yoda from its own origin and trusts the git host key" {
  [ "$(git -C "$YODA_ROOT" rev-parse --show-toplevel 2>/dev/null)" = "$(cd "$YODA_ROOT" && pwd -P)" ] \
    || skip "Yoda is not a git clone here"
  "$YODA" init >/dev/null
  stub_deploy

  run "$YODA" deploy --env=production --branch=master
  [ "$status" -eq 0 ]
  grep -Fq "git clone -q $(git -C "$YODA_ROOT" remote get-url origin) ~/.yoda" "$SSH_LOG"
  grep -Fq "ssh-keyscan 'git.example.com'" "$SSH_LOG"
}

@test "deploy from a release install clones Yoda from upstream" {
  "$YODA" init >/dev/null
  stub_deploy
  release_copy

  run "$YODA_RELEASE/yoda" deploy --env=production --branch=master
  [ "$status" -eq 0 ]
  grep -Fq "git clone -q https://github.com/Muvon/yoda.git ~/.yoda" "$SSH_LOG"
  ! grep -q "ssh-keyscan 'https" "$SSH_LOG"
}

@test "rollback refuses to run without two recorded deploys" {
  "$YODA" init >/dev/null
  stub_deploy
  mkdir -p home/.deploy
  printf 'aaa1111\n' > "home/.deploy/${PROJECT_DIR##*/}.revision"

  run "$YODA" rollback --env=production --branch=master
  [ "$status" -eq 1 ]
  grep -q "No revisions found to rollback" <<<"$output"
  [ ! -s "$SSH_LOG" ]
}

@test "rollback deploys the previous recorded revision" {
  "$YODA" init >/dev/null
  stub_deploy
  mkdir -p home/.deploy
  printf 'aaa1111\nbbb2222\n' > "home/.deploy/${PROJECT_DIR##*/}.revision"

  run "$YODA" rollback --env=production --branch=master
  [ "$status" -eq 0 ]
  grep -qx "    git checkout -qf --detach aaa1111" "$SSH_LOG"
}

@test "a failed version switch warns on stderr and leaves other repositories alone" {
  "$YODA" init >/dev/null
  "$YODA" add nginx >/dev/null
  release_copy
  # The release copy sits inside a repository that has a matching tag
  printf "YODA_SOURCE_VERSION='0.1'\n" > yoda
  git init -q . && git add -A && git -c user.name=t -c user.email=t@t commit -qm one && git tag 0.1
  git rm -q yoda && git -c user.name=t -c user.email=t@t commit -qm two
  local head
  head=$(git rev-parse HEAD)
  sed -i.bak 's/^  YODA_VERSION=.*/  YODA_VERSION="0.1" \\/' docker/.yodarc

  "$YODA_RELEASE/yoda" compose > out.yml 2> err.log
  grep -q "^services:" out.yml
  [ "$(grep -c "Yoda version" out.yml)" -eq 0 ]
  grep -q "Failed to switch version to '0.1'" err.log
  [ "$(git rev-parse HEAD)" = "$head" ]
  git symbolic-ref -q HEAD
}
