#!/usr/bin/env bash
# shellcheck disable=SC2154  # YODA_VERSION and YODA_SOURCE_VERSION are exported by the parent yoda process
set -e
upgrade_path=$1
if [[ -z "$upgrade_path" || ! -d "$upgrade_path" ]]; then
  >&2 echo "Cant find directory with upgrades: '$upgrade_path'."
  exit 1
fi

# shellcheck disable=SC1091 source=../lib/migration.sh
source "$YODA_PATH/lib/migration.sh"
# shellcheck disable=SC1091 source=../lib/version.sh
source "$YODA_PATH/lib/version.sh"

project_key=$(version_key "$YODA_VERSION")
source_key=$(version_key "$YODA_SOURCE_VERSION")
if [[ ! "$source_key" > "$project_key" ]]; then
  echo 'No upgrades found. You have the latest version in this project.'
  exit 0
fi

# Run the upgrade scripts (version-X.Y or version-X.Y.Z) newer than the project, oldest first
while read -r key file; do
  if [[ "$key" > "$project_key" && ! "$key" > "$source_key" ]]; then
    echo "Upgrade: ${file#version-}"
    ( exec "$upgrade_path/$file" )
  fi
done < <(
  for path in "$upgrade_path"/version-*; do
    [[ -e "$path" ]] || continue
    file=${path##*/}
    echo "$(version_key "${file#version-}") $file"
  done | sort
)

# Pin the project to the installed version, whether or not a script ran
update_yodarc
echo "Project upgraded to Yoda version: $YODA_SOURCE_VERSION"
