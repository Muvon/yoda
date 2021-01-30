#!/usr/bin/env bash
set -e

# shellcheck disable=SC1091 source=../lib/array.sh
source "$YODA_PATH/lib/array.sh"

# Usage string_replace [str?] [array of replaces]
# Example:
#  array=( 'from1/to1' 'from2/to2')
#  echo "replace here" | string_replace "${array[@]}"
#  string_replace "here we go" "${array[@]}"
string_replace() {
  local str
  if [[ -p /dev/stdin ]]; then
    str=$(cat -)
  else
    str=$1
    shift
  fi

  local replaces=("$@")
  echo "$str" | sed -E "s/$(array_join "/g;s/" "${replaces[@]}")/g"
}
