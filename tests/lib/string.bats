load ../helpers
source "$YODA_ROOT/lib/string.sh"

@test "string_replace applies replacements passed as arguments" {
  [ "$(string_replace 'hello big world' 'big/small' </dev/null)" = "hello small world" ]
}

@test "string_replace applies multiple replacements in one pass" {
  [ "$(string_replace 'a b c' 'a/1' 'b/2' </dev/null)" = "1 2 c" ]
}

@test "string_replace reads from stdin when piped" {
  [ "$(echo 'hello big world' | string_replace 'big/small')" = "hello small world" ]
}

@test "string_replace leaves text without matches untouched" {
  [ "$(string_replace 'nothing here' 'x/y' </dev/null)" = "nothing here" ]
}

@test "string_trim strips surrounding whitespace" {
  [ "$(string_trim '   hello   ')" = "hello" ]
}
