#!/usr/bin/env bash
set -e

name="$*"
container_path="$DOCKER_ROOT/containers/${name//./\/}"
test -d "$container_path" && rm -fr "$_"

# Remove the container from every environment: only exact name or name=N entries
envfile="$DOCKER_ROOT/Envfile"
mapfile -t lines < "$envfile"
out=()
for line in "${lines[@]}"; do
  # Block list item
  if [[ "$line" =~ ^[[:space:]]+-[[:space:]]*([^[:space:]]+)[[:space:]]*$ && "${BASH_REMATCH[1]%%=*}" == "$name" ]]; then
    continue
  fi

  # Inline list; host lines (user@host) are left as they are
  if [[ "$line" =~ ^([^[:space:]#@]+):(.*)$ ]]; then
    key=${BASH_REMATCH[1]}
    read -ra entries <<< "${BASH_REMATCH[2]}"
    kept=()
    for entry in "${entries[@]}"; do
      [[ "${entry%%=*}" == "$name" ]] || kept+=("$entry")
    done
    if (( ${#kept[@]} < ${#entries[@]} )); then
      line="$key:"
      if (( ${#kept[@]} > 0 )); then
        line+=" ${kept[*]}"
      fi
    fi
  fi
  out+=("$line")
done
printf '%s\n' "${out[@]}" > "$envfile"
