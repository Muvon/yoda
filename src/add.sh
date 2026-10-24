#!/usr/bin/env bash
set -e

name="$*"
# Nested containers live in nested folders: worker.mail -> containers/worker/mail
path=${name//./\/}
container_path="$DOCKER_ROOT/containers/$path"
if [[ -d "$container_path" ]]; then
  echo "Container exists: '$name'. Skipping: '$container_path'."
  exit 0
fi

mkdir -p "$container_path"
sed "s/{{name}}/$name/g;s|{{path}}|$path|g" "$YODA_PATH/templates/container.yml" > "$container_path/container.yml"
cp "$YODA_PATH/templates/entrypoint" "$container_path"

# Add the container to the dev environment, keeping its inline or block list style
envfile="$DOCKER_ROOT/Envfile"
mapfile -t lines < "$envfile"
out=()
block_indent=
added=
for i in "${!lines[@]}"; do
  line=${lines[$i]}
  if [[ -n "$block_indent" && ! "$line" =~ ^[[:space:]]+- ]]; then
    out+=("$block_indent- $name")
    block_indent=
    added=1
  fi

  if [[ -z "$added" && "$line" =~ ^dev:(.*)$ ]]; then
    value=${BASH_REMATCH[1]}
    if [[ "$value" =~ ^[[:space:]]*$ && "${lines[$((i + 1))]:-}" =~ ^([[:space:]]+)- ]]; then
      block_indent=${BASH_REMATCH[1]}
    else
      line="dev:$value $name"
      added=1
    fi
  fi
  out+=("$line")
done

if [[ -n "$block_indent" ]]; then
  out+=("$block_indent- $name")
fi
printf '%s\n' "${out[@]}" > "$envfile"
