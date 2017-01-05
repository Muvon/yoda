#!/usr/bin/env bash
set -e
upgrade_path=$1
if [[ -z "$upgrade_path" || ! -d "$upgrade_path" ]]; then
  >&2 echo "Cant find directory with upgrades: '$upgrade_path'."
  exit 1
fi

declare -A upgrades
proj_major=${YODA_VERSION%.*}
proj_minor=${YODA_VERSION#*.}
for file in $upgrade_path/*; do
  file=${file##*/}
  version=${file#version-*}
  major=${version%.*}
  minor=${version#*.}

  if [[ $major -gt $proj_major || ( $major -eq $proj_major && $minor -gt $proj_minor ) ]]; then
    echo "Upgrade: $version"
    upgrades[$version]=1
    exec $upgrade_path/$file
  fi
done
if [[ -z "${upgrades[@]}" ]]; then
  echo 'No upgrades found. You have the latest version in this project.'
fi
