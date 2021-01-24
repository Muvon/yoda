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

if [[ ! -f "$DOCKER_ROOT/server/authorized_keys" ]]; then
  >&2 echo "Cannot find authorized_keys file. Please add it to server folder before  setup."
  exit 1
fi

control_path=$DOCKER_ROOT/.ssh/%r@%h-%p
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

  # First check known hosts
  grep "${host##*@}" ~/.ssh/known_hosts || ssh-keyscan "${host##*@}" >> "$_"
  yoda_git_url=$(cd ${BASH_SOURCE%/*} && git remote get-url origin || true)
  yoda_git_host=$(echo $yoda_git_url | cut -d'@' -f2 | cut -d':' -f1)

  ssh -o ControlPath=$control_path -o PasswordAuthentication=no -AT "root@$host" <<EOF
    set -e

    # already deployed?
    which docker || exit 0

    if [[ ! -d ~/.yoda ]]; then
      grep $yoda_git_host ~/.ssh/known_hosts || ssh-keyscan $yoda_git_host >> \$_
      git clone -q $yoda_git_url ~/.yoda
    fi

    bash ~/.yoda/server/centos8
EOF
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
  echo -n '  '
  ssh -o ControlPath=$control_path -o ControlPersist=1800 -o ConnectTimeout=5 -AT "root@$host" "echo root@$host...ok"
done

echo "Setup has been started"
for server in ${servers[*]}; do
  ( setup "$server" >> "$DOCKER_ROOT/log/setup/${server//@/_}.log" 2>&1 ) &
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
    echo "${servers[$idx]} – $status"
    clear=1
  done
done
echo "Finished: $(date -u)"
exit $exit_code
