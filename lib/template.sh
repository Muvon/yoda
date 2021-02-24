#!/usr/bin/env bash
set -e

template_build() {
  file="$1"
  if [[ ! -f "$file" ]]; then
    >&2 echo "Cannot find file: $file"
  fi

  content=$(cat "$file")
  matches=( $(echo "$content" | grep -Eo "$YODA_VAR_REGEX" | cat) )

  for match in "${matches[@]}"; do
    var=$(eval echo "\$${match:2:-1}")
    content="${content//"$match"/"$var"}"
  done
  echo "$content"
}

template_compile() {
  template_build "$1" > "${1%.yoda}"
}

template_compile_dir() {
  d=$1
  if [[ ! -d "$d" ]]; then
    >&2 echo "Cannot find dir path: $d"
  fi

  find "$d" -name '*.yoda' \
    -exec bash -c 'for i do template_compile "$i"; done' \
    bash {} +
}

export -f template_build \
  template_compile \
  template_compile_dir
