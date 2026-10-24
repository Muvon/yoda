#!/usr/bin/env bash
set -e

# Full x.y.z form of a version: 2.5 and 2.5.0 are the same release
version_normalize() {
  if [[ "$1" =~ ^[0-9]+\.[0-9]+$ ]]; then
    echo "$1.0"
  else
    echo "$1"
  fi
}

# Zero-padded key that orders versions as plain text: 2.10.0 sorts after 2.9.1.
# A missing patch counts as 0 and a -prerelease/+build suffix is ignored.
version_key() {
  local major minor patch
  IFS=. read -r major minor patch _ <<< "$1"
  patch=${patch%%[-+]*}
  printf '%06d%06d%06d\n' "$((10#${major:-0}))" "$((10#${minor:-0}))" "$((10#${patch:-0}))"
}
