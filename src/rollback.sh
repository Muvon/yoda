#!/usr/bin/env bash
set -e
for p in "$@"; do
  case $p in
    --host=*)
      host=${p#*=}
      ;;
    --env=*)
      env=${p#*=}
      ;;
    --rev=*)
      shift
      ;;
  esac
done

if [[ -z "$host" && -z "$env" ]]; then
  >&2 echo "Host or environment is required to be passed."
  exit 1
fi

# Gather servers
servers=()
if [[ -n "$host" ]]; then
  servers=(`grep -E "^(\w+@)?$host:" $DOCKER_ROOT/Envfile | cut -d':' -f1`)
else
  servers=(`grep -E ":\s*$env\b" $DOCKER_ROOT/Envfile | cut -d':' -f1`)
fi

# Get last revision
declare -A revisions
for server in ${servers[*]}; do
  revisions[$server]=$(ssh -o ControlPath=none -AT $server "
    if test -f .deploy/$COMPOSE_PROJECT_NAME.revision; then
      tail -n 2 .deploy/$COMPOSE_PROJECT_NAME.revision | head -n 1
    fi
  ")
done

rev=$(printf "%s\n" ${revisions[*]} | sort -u)
if [[ -z "$rev" ]]; then
  >&2 echo 'No revisions found to rollback.'
fi

if [[ $(echo "$rev" | wc -l | tr -d ' ') -gt 1 ]]; then
  >&2 echo 'Found inconsistency in revisions on all servers:'

  for host in "${!revisions[@]}"; do
    >&2 echo "$host:${revisions[$host]}"
  done
  exit 1
fi

if [[ -n "$host" ]]; then
  echo "Host: $host"
fi

if [[ -n "$env" ]]; then
  echo "Environment: ${env%.*}"
  echo "Namespace: ${env#*.}"
fi

if [[ -n "$rev" ]]; then
  echo "Revision: $rev"
fi

$YODA_CMD deploy "$@" --rev=$rev
