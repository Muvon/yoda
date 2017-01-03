#!/usr/bin/env bash
set -e

compose_container() {
  if [[ -x "$COMPOSE_SCRIPT" ]]; then
    cat - | $COMPOSE_SCRIPT --name=$1 --sequence=$2
  else
    cat -
  fi
}

# Parse map
declare -A SCALE_MAP
for p in "$@"; do
  service=$(echo $p | cut -d'=' -f1)
  count=$(echo $p | cut -d'=' -f2)
  count=${count//[!0-9]/}
  SCALE_MAP["$service"]=$(( ${count:-1} - 1)) # Start index using 0
done

if [[ -z "${SCALE_MAP[@]}" ]]; then
  >&2 echo "No services to build. First you should add container."
  exit 1
fi

echo "# Build args $0 $*"
echo 'version: "2"'
echo 'networks:'
echo "  ${COMPOSE_PROJECT_NAME}:"
echo '    driver: host'
echo 'services:'

for p in ${!SCALE_MAP[*]}; do
  for i in $(seq 0 ${SCALE_MAP[$p]:-0}); do
    sed "s/^/  /g;s/#/$i/g" "$DOCKER_ROOT/containers/$p/container.yml" | compose_container $p $i
  done
done
