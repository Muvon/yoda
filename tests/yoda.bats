load helpers

setup() {
  TEST_CWD=$(mktemp -d)
  cd "$TEST_CWD"
}

teardown() {
  rm -rf "$TEST_CWD"
}

@test "fails with a hint when no command is given" {
  run "$YODA"
  [ "$status" -eq 1 ]
  grep -q "No command specified" <<<"$output"
}

@test "version prints the current source version" {
  local version
  version=$(sed -n "s/^YODA_SOURCE_VERSION='\(.*\)'$/\1/p" "$YODA")
  run "$YODA" version
  [ "$status" -eq 0 ]
  [ "$output" = "Yoda version: $version" ]
}

@test "help lists available commands" {
  run "$YODA" help
  [ "$status" -eq 0 ]
  grep -q "Commands available" <<<"$output"
  grep -q "init" <<<"$output"
}

@test "unknown commands are reported" {
  run "$YODA" definitely-not-a-command
  grep -q "Unknown command 'definitely-not-a-command'" <<<"$output"
}
