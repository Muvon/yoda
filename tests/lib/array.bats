load ../helpers
source "$YODA_ROOT/lib/array.sh"

@test "array_flip maps values to their indexes" {
  local items=(one two three)
  array_flip index "${items[@]}"
  [ "${index[one]}" = "0" ]
  [ "${index[two]}" = "1" ]
  [ "${index[three]}" = "2" ]
}

@test "array_flip keeps the last index for duplicate values" {
  local items=(a b a)
  array_flip index "${items[@]}"
  [ "${index[a]}" = "2" ]
  [ "${index[b]}" = "1" ]
}

@test "array_join joins elements with a separator" {
  local items=(a b c)
  [ "$(array_join ',' "${items[@]}")" = "a,b,c" ]
}

@test "array_join supports multi-char separators" {
  local items=(x y)
  [ "$(array_join ' -> ' "${items[@]}")" = "x -> y" ]
}

@test "array_join passes a single element through" {
  [ "$(array_join ',' only)" = "only" ]
}
