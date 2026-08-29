load ../helpers
source "$YODA_ROOT/lib/template.sh"

@test "template_build substitutes %{VAR} placeholders from the environment" {
  local dir
  dir=$(mktemp -d)
  printf 'Hello %%{NAME} from %%{PLACE}\n' > "$dir/tpl"
  export NAME=yoda PLACE=earth
  run template_build "$dir/tpl"
  [ "$status" -eq 0 ]
  [ "$output" = "Hello yoda from earth" ]
  rm -rf "$dir"
}

@test "template_build reports missing files" {
  # Exit code depends on the caller's errexit policy; the stderr
  # message is the contract
  run template_build "$(mktemp -d)/missing"
  grep -q "Cannot find file" <<<"$output"
}

@test "template_compile renders next to the source file" {
  local dir
  dir=$(mktemp -d)
  printf 'value=%%{VAL}\n' > "$dir/app.yoda"
  export VAL=42
  run template_compile "$dir/app.yoda"
  [ "$status" -eq 0 ]
  [ -f "$dir/app" ]
  [ "$(cat "$dir/app")" = "value=42" ]
  rm -rf "$dir"
}

@test "template_compile_dir renders every .yoda file in a tree" {
  local dir
  dir=$(mktemp -d)/nested
  mkdir -p "$dir"
  printf 'a=%%{VAL}\n' > "$dir/one.yoda"
  printf 'b=%%{VAL}\n' > "$dir/two.yoda"
  export VAL=7
  run template_compile_dir "$dir"
  [ "$status" -eq 0 ]
  [ "$(cat "$dir/one")" = "a=7" ]
  [ "$(cat "$dir/two")" = "b=7" ]
  rm -rf "${dir%/*}"
}

@test "template_compile_dir reports missing dirs" {
  run template_compile_dir "$(mktemp -d)/nope"
  [ "$status" -ne 0 ]
  grep -q "Cannot find dir path" <<<"$output"
}
