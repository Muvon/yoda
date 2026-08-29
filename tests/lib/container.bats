load ../helpers

setup() {
  DOCKER_ROOT=$(mktemp -d)
  export DOCKER_ROOT ENV=dev STACK=''
  mkdir -p "$DOCKER_ROOT/containers/php" "$DOCKER_ROOT/containers/nginx"
  printf 'image: php:8.2\n' > "$DOCKER_ROOT/containers/php/container.yml"
  printf 'image: nginx:1.25\n' > "$DOCKER_ROOT/containers/nginx/container.yml"
  source "$YODA_ROOT/lib/container.sh"
}

teardown() {
  rm -rf "$DOCKER_ROOT"
}

@test "get_stack reads an inline service list" {
  printf 'dev: php nginx\n' > "$DOCKER_ROOT/Envfile"
  run get_stack
  [ "$status" -eq 0 ]
  [ "$output" = "php nginx" ]
}

@test "get_stack reads a block list until the next environment" {
  cat > "$DOCKER_ROOT/Envfile" <<'EOF'
dev:
  - php
  - nginx=2
prod:
  - solo
EOF
  run get_stack
  [ "$status" -eq 0 ]
  [ "$output" = "php nginx=2" ]
}

@test "get_stack prefers the env.stack section when STACK is set" {
  cat > "$DOCKER_ROOT/Envfile" <<'EOF'
dev:
  - nginx
dev.api:
  - php
EOF
  export STACK=api
  run get_stack
  [ "$status" -eq 0 ]
  [ "$output" = "php" ]
}

@test "get_count extracts the =N suffix or falls back to the default" {
  run get_count 'nginx=2' 1
  [ "$output" = "2" ]
  run get_count 'php' 3
  [ "$output" = "3" ]
}

@test "get_service strips the =N suffix" {
  run get_service 'nginx=2'
  [ "$output" = "nginx" ]
}

@test "get_containers expands stack entries with counts" {
  printf 'dev: php nginx=2\n' > "$DOCKER_ROOT/Envfile"
  export COMPOSE_PROJECT_NAME=proj
  run get_containers php nginx
  [ "$status" -eq 0 ]
  [ "$output" = "php nginx.0 nginx.1" ]
}

@test "get_containers strips the compose project prefix" {
  printf 'dev: php\n' > "$DOCKER_ROOT/Envfile"
  export COMPOSE_PROJECT_NAME=proj
  run get_containers proj.php
  [ "$status" -eq 0 ]
  [ "$output" = "php" ]
}

@test "get_containers keeps explicit name.sequence services as is" {
  printf 'dev: php\n' > "$DOCKER_ROOT/Envfile"
  run get_containers php.1
  [ "$status" -eq 0 ]
  [ "$output" = "php.1" ]
}

@test "get_containers fails for services missing from the stack" {
  printf 'dev: php\n' > "$DOCKER_ROOT/Envfile"
  run get_containers mysql
  [ "$status" -eq 1 ]
  grep -q "There is no mysql in dev" <<<"$output"
}
