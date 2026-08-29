#!/usr/bin/env bash
# shellcheck disable=SC2154  # env vars and c_* colors are exported by the parent yoda process
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

# %C expands to a 40-char hash and ssh appends a ~17-char random suffix
# while binding, so the directory must be short enough to keep the whole
# path under the 104-char sun_path limit (macOS). $DOCKER_ROOT is usually
# too deep, and so is TMPDIR on macOS - hence the length check.
for runtime_dir in "${XDG_RUNTIME_DIR:-}" "${TMPDIR:-}" /tmp; do
  [[ -n "$runtime_dir" && ${#runtime_dir} -le 40 ]] && break
done
control_path="${runtime_dir%/}/yoda-%C"
setup() {
  local host=$1
  if [[ -z "$host" ]]; then
    >&2 echo "No host specified for deploy."
    exit 1
  fi

  env=$(grep "$host:" "$DOCKER_ROOT/Envfile" | cut -d':' -f2 | tr -d ' ')

  if [[ -z "$env" ]]; then
    >&2 echo "Cant define environment for host '$host' using '$DOCKER_ROOT/Envfile'."
    exit 1
  fi

  # Check that we support version
  centos_version=$(ssh -o ControlPath="$control_path" -o PasswordAuthentication=no -T "root@$host" "hostnamectl | grep 'Operating System' | cut -d: -f2 | xargs | cut -d. -f1")
  declare -A version_map=(
    ["CentOS Linux 7 (Core)"]=centos7
    ["CentOS Linux 8"]=centos8
    ["CentOS Stream 9"]=centos-stream9
    ["Rocky Linux 9"]=rocky-linux9
    ["Rocky Linux 10"]=rocky-linux10
  )
  install_script="${version_map[$centos_version]}"
  if [[ -z "$install_script" ]]; then
    >&2 echo "Cant find right script to run for your OS version"
    exit 1
  fi

  scp -o ControlPath="$control_path" -o PasswordAuthentication=no -r "$YODA_PATH/server" "root@$host:~/"
  scp -o ControlPath="$control_path" -o PasswordAuthentication=no "$DOCKER_ROOT/.ssh/authorized_keys" "root@$host:~/server/"
  ssh -o ControlPath="$control_path" -o PasswordAuthentication=no -T "root@$host" "bash ~/server/$install_script"
  echo "Setup of the $host with environment $env has been finished."
}

pids=()
servers=()
mkdir -p "$DOCKER_ROOT/log/setup"

# This is dirty hack same in container.yml
# @TODO: fix it
env_stack="$env"
if [[ -n "$stack" ]]; then
  env_stack="$env_stack.$stack"
fi

if [[ -n "$host" ]]; then
  mapfile -t servers < <(grep -E "^(\w+@)?$host:" "$DOCKER_ROOT/Envfile" | cut -d':' -f1)
else
  mapfile -t servers < <(grep -E ":\s*$env_stack\b" "$DOCKER_ROOT/Envfile" | cut -d':' -f1)
fi

# First do checkups that all servers have authorization by keys
echo "Check root authorization on all servers using SSH keys"
for server in "${servers[@]}"; do
  echo -n "  root@${server#*@}"
  grep "${server#*@}" ~/.ssh/known_hosts > /dev/null 2>&1 || ssh-keyscan "${server#*@}" >> "$_"
  ssh -o ControlPath="$control_path" -o ControlPersist=1800 -o ConnectTimeout=5 -AT "root@${server#*@}" "echo '...ok'"
done

echo "Setup has been started"
for server in "${servers[@]}"; do
  ( setup "${server#*@}" >> "$DOCKER_ROOT/log/setup/${server#*@}.log" 2>&1 ) &
  pids+=("$!")
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
    seq "${#pids[@]}" | xargs -I0 tput cuu1
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
