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
  esac
done

if [[ -z "$host" && -z "$env" ]]; then
  >&2 echo "Host or environment is required to be passed."
  exit 1
fi

if [[ ! -f "$DOCKER_ROOT/.ssh/authorized_keys" ]]; then
  >&2 echo "Cannot find authorized_keys file. Please add it to '$DOCKER_ROOT/.ssh/authorized_keys'."
  exit 1
fi

control_path=$DOCKER_ROOT/.ssh/connections/%r@%h-%p
setup() {
  local host=$1
  if [[ -z "$host" ]]; then
    >&2 echo "No host specified for deploy."
    exit 1
  fi

  env=$(grep $host: $DOCKER_ROOT/Envfile | cut -d':' -f2 | tr -d ' ')

  if [[ -z "$env" ]]; then
    >&2 echo "Cant define environment for host '$host' using '$DOCKER_ROOT/Envfile'."
    exit 1
  fi

  scp -o ControlPath="$control_path" -o PasswordAuthentication=no -r "$YODA_PATH/server" "root@$host:~/"
  scp -o ControlPath="$control_path" -o PasswordAuthentication=no "$DOCKER_ROOT/.ssh/authorized_keys" "root@$host:~/server/"
  ssh -o ControlPath="$control_path" -o PasswordAuthentication=no -T "root@$host" "bash ~/server/centos8"
  echo "Setup of the $host with environment $env has been finished."
}

pids=()
servers=()
mkdir -p "$DOCKER_ROOT/log/setup"

if [[ -n "$host" ]]; then
  servers=( $(grep -E "^(\w+@)?$host:" $DOCKER_ROOT/Envfile | cut -d':' -f1 | cut -d'@' -f2) )
else
  servers=( $(grep -E ":\s*$env\b" $DOCKER_ROOT/Envfile | cut -d':' -f1) )
fi

# First do checkups that all servers have authorization by keys
echo "Check root authorization on all servers using SSH keys"
for server in ${servers[*]}; do
  echo -n "  root@${server#*@}"
  grep "${server#*@}" ~/.ssh/known_hosts > /dev/null 2>&1 || ssh-keyscan "${server#*@}" >> "$_"
  ssh -o ControlPath="$control_path" -o ControlPersist=1800 -o ConnectTimeout=5 -AT "root@${server#*@}" "echo '...ok'"
done

echo "Setup has been started"s
for server in ${servers[*]}; do
  ( setup "${server#*@}" >> "$DOCKER_ROOT/log/setup/${server#*@}.log" 2>&1 ) &
  pids+=($!)
done

echo "Nodes: ${#servers[*]}"
echo "Logs: $DOCKER_ROOT/log/setup"
echo "Started: $(date -u)"
start_ts=$(date +%s)

finished=()
is_succeed() {
  if [[ "${finished[$1]}" == "0" ]]; then
    return 0
  else
    return 1
  fi
}

clear=
elapsed=0
exit_code=0

while [[ "${#finished[@]}" != "${#pids[@]}" ]]; do
  if [[ -n "$clear" ]]; then
    sleep 1
    elapsed=$(( $(date +%s) - start_ts))
    tput cuu1
    seq ${#pids[@]} | xargs -I0 tput cuu1
  fi

  tput el
  echo "Elapsed: $elapsed s"
  for idx in "${!pids[@]}"; do
    pid=${pids[$idx]}

    status=
    if ! ps -p "$pid" >/dev/null ; then
      # Check array first to prevent "not a child of this shell"
      if is_succeed "$pid" || wait "$pid"; then
        status="${c_green}${c_bold}succeed${c_normal}"
        finished[$pid]=0
      else
        exit_code=1
        status="${c_red}${c_bold}failed${c_normal}"
        finished[$pid]=$exit_code
      fi
    else
      status="${c_yellow}${c_bold}processing${c_normal}"
    fi
    tput el
    server="${servers[$idx]}"
    echo "root@${server#*@} – $status"
    clear=1
  done
done
echo "Finished: $(date -u)"
exit $exit_code
