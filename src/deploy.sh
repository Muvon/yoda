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
    --stack=*)
      stack=${p#*=}
      ;;
    --rev=*)
      rev=${p#*=}
      ;;
    --branch=*)
      branch=${p#*=}
      ;;
    --args=*)
      custom_args=${p#*=}
      ;;
    --force)
      force=1
      ;;
  esac
done

if [[ -z "$host" && -z "$env" ]]; then
  >&2 echo "Host or environment is required to be passed."
  exit 1
fi

# Get needed branch
cur_branch=$(git branch --show-current)
git_branch=${branch:-"$cur_branch"}
echo "GIT branch: $git_branch"

echo "Host: $host"
echo "Environment: $env"

if [[ -n "$stack" ]]; then
  echo "Stack: $stack"
fi

if [[ -n "$rev" ]]; then
  echo "Revision: $rev"
fi

if [[ -n "$custom_args" ]]; then
  # Names only: values are often secrets
  echo "Custom arguments: $(echo "$custom_args" | sed -E 's/=[^ ]*//g')"
fi

# Remote command that trusts the SSH host key of a git URL; none for http(s) URLs
keyscan_command() {
  local url=$1 host
  case "$url" in
    ''|http://*|https://*)
      return 0
      ;;
    ssh://*)
      host=${url#ssh://}
      host=${host#*@}
      host=${host%%[:/]*}
      ;;
    *)
      host=${url#*@}
      host=${host%%:*}
      ;;
  esac
  echo "grep -q '$host' ~/.ssh/known_hosts || ssh-keyscan '$host' >> ~/.ssh/known_hosts"
}

deploy() {
  host=$1
  if [[ -z "$host" ]]; then
    >&2 echo "No host specified for deploy."
    exit 1
  fi

  env=$(grep "$host:" "$DOCKER_ROOT/Envfile" | cut -d':' -f2 | tr -d ' ')

  if [[ -z "$env" ]]; then
    >&2 echo "Cant define environment for host '$host' using '$DOCKER_ROOT/Envfile'."
    exit 1
  fi

  # Redeclare env and stack cuz we get it from config
  stack=
  if [[ $env != "${env##*.}" ]]; then
    stack=${env##*.}
    env=${env%%.*}
  fi

  # First check known hosts
  grep "${host##*@}" ~/.ssh/known_hosts || ssh-keyscan "${host##*@}" >> "$_"

  # Servers clone Yoda from the origin of the local clone; release installs
  # (e.g. Homebrew) have no clone of their own, so they use upstream
  yoda_git_url=https://github.com/Muvon/yoda.git
  if [[ "$(git -C "$YODA_PATH" rev-parse --show-toplevel 2>/dev/null)" == "$(cd "$YODA_PATH" && pwd -P)" ]]; then
    yoda_git_url=$(git -C "$YODA_PATH" remote get-url origin 2>/dev/null || echo "$yoda_git_url")
  fi
  yoda_keyscan=$(keyscan_command "$yoda_git_url")
  git_keyscan=$(keyscan_command "$GIT_URL")

  # Get custom args for start command
  start_args=()
  if [[ -n "$force" ]]; then
    start_args+=('--force')
  fi

  # Deploy the passed revision itself, not the branch head tagged with it
  checkout_rev=
  if [[ -n "$rev" ]]; then
    checkout_rev="git checkout -qf --detach $rev"
  fi

  # shellcheck disable=SC2016  # $HOME/$PATH stay literal: expanded on the remote host
  yoda_remote_path='PATH=$HOME/.yoda:$PATH'
  # The remote script is expanded locally on purpose to pass values to the remote.
  # It is piped from a forked printf rather than fed as a heredoc: bash 5.x writes a
  # heredoc into a pipe before ssh starts reading, which hangs once the script
  # outgrows the pipe buffer macOS hands out under pipe-memory pressure.
  script="
    set -e
    if [[ ! -d ~/.yoda ]]; then
      if [[ ! -f ~/.ssh/known_hosts ]]; then
        touch ~/.ssh/known_hosts
      fi
      $yoda_keyscan
      git clone -q $yoda_git_url ~/.yoda

      grep -qxF '$yoda_remote_path' ~/.bashrc 2>/dev/null || echo '$yoda_remote_path' >> ~/.bashrc
    else
      echo 'Changing remote origin url of yoda git repository'
      cd ~/.yoda
      remote_url=\$(git remote get-url origin)
      if [[ \"\$remote_url\" =~ 'dmitrykuzmenkov' ]]; then
        git remote set-url origin \"\${remote_url//dmitrykuzmenkov/muvon}\"
      fi
      cd ~/
    fi

    mkdir -p ~/.deploy && cd \$_
    if [[ ! -d $COMPOSE_PROJECT_NAME ]]; then
      $git_keyscan
      git clone -q $GIT_URL $COMPOSE_PROJECT_NAME
    fi
    cd $COMPOSE_PROJECT_NAME && git fetch -p
    git checkout -f $git_branch && git reset --hard origin/$git_branch
    git pull --rebase origin $git_branch
    $checkout_rev
    git clean -fdx
    PATH=~/.yoda:\$PATH ENV=$env STACK=$stack REVISION=$rev $custom_args yoda start ${start_args[*]}
    {
      source ~/.deploy/$COMPOSE_PROJECT_NAME/*/.yodarc
      echo ${rev:-$REVISION} >> ~/.deploy/$COMPOSE_PROJECT_NAME.revision
    }
"
  printf '%s' "$script" | ssh -o ControlPath=none -AT "$host"
  echo "Deploy to $host with environment $env and git branch $git_branch finished."
}

pids=()
servers=()
mkdir -p "$DOCKER_ROOT/log"
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

for server in "${servers[@]}"; do
  ( deploy "$server" >> "$DOCKER_ROOT/log/${server//@/_}.log" 2>&1 ) &
  pids+=("$!")
done

echo "Nodes: ${#servers[*]}"
echo "Logs: $DOCKER_ROOT/log"
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
failed=()
while [[ "${#finished[@]}" != "${#pids[@]}" ]]; do
  if [[ -n "$clear" ]]; then
    sleep 1
    elapsed=$(( $(date +%s) - start_ts ))
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
        finished[pid]=0
      else
        exit_code=1
        status="${c_red}${c_bold}failed${c_normal}"
        failed+=("${servers[$idx]}")
        finished[pid]=$exit_code
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
for server in "${failed[@]}"; do
  echo "${c_red}${c_bold}$server${c_normal} log:"
  tail -n 5 "$DOCKER_ROOT/log/${server//@/_}.log" | sed 's/^/  /'
done
exit $exit_code
