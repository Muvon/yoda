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
      rev=${p#*=}
      ;;
    --branch=*)
      branch=${p#*=}
      ;;
    --args=*)
      custom_args=${p#*=}
      ;;
  esac
done

if [[ -z "$host" && -z "$env" ]]; then
  >&2 echo "Host or environment is required to be passed."
  exit 1
fi

# Get needed branch
git_branch=${branch:-"master"}
echo "GIT branch: $git_branch"

if [[ -n "$host" ]]; then
  echo "Host: $host"
fi

if [[ -n "$env" ]]; then
  echo "Environment: $env"
fi

if [[ -n "$rev" ]]; then
  echo "Revision: $rev"
fi

if [[ -n "$custom_args" ]]; then
  echo "Custom arguments: $custom_args"
fi

deploy() {
  host=$1
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
  grep ${host##*@} ~/.ssh/known_hosts || ssh-keyscan ${host##*@} >> $_

  # Detect git host to do keyscan check
  git_host=$(echo $GIT_URL | cut -d'@' -f2 | cut -d':' -f1)
  yoda_git_url=$(cd ${BASH_SOURCE%/*} && git remote get-url origin || true)

  ssh -AT $host <<EOF
    set -e

    if [[ ! -d ~/.yoda ]]; then
      git clone -q $yoda_git_url ~/.yoda
    fi

    mkdir -p ~/.deploy && cd \$_
    if [[ ! -d $COMPOSE_PROJECT_NAME ]]; then
      grep $git_host ~/.ssh/known_hosts || ssh-keyscan $git_host >> \$_
      git clone -q $GIT_URL $COMPOSE_PROJECT_NAME
    fi
    cd $COMPOSE_PROJECT_NAME && git fetch -p
    git checkout -f $git_branch && git reset --hard origin/$git_branch
    git pull --rebase origin $git_branch
    git clean -fdx
    PATH=\$PATH:~/.yoda ENV=$env REVISION=$rev $custom_args exec yoda start
EOF
  echo "Deploy to $host with environment $env and git branch $git_branch finished."
}

pids=()
servers=()
mkdir -p $DOCKER_ROOT/log

if [[ -n "$host" ]]; then
  servers=(`grep -E "^(\w+@)?$host:" $DOCKER_ROOT/Envfile | cut -d':' -f1`)
else
  servers=(`grep -E ":\s*$env\b" $DOCKER_ROOT/Envfile | cut -d':' -f1`)
fi

for server in ${servers[*]}; do
  ( deploy $server >> $DOCKER_ROOT/log/${server//@/_}.log 2>&1 ) &
  pids+=($!)
done

echo "Nodes: ${#servers[*]}"
echo "Started: $(date -u)"
start_ts=$(date +%s)
finished=()
clear=
elapsed=0
while [[ "${#finished[@]}" != "${#pids[@]}" ]]; do
  if [[ -n "$clear" ]]; then
    sleep 1
    elapsed=$((`date +%s` - $start_ts))
    echo -en "\e[${#pids[@]}A\e[1A"
  fi

  clear=1
  echo -e "\e[2K\rElapsed: $elapsed s"
  for idx in "${!pids[@]}"; do
    pid=${pids[$idx]}

    status=
    if ! ps -p $pid >/dev/null ; then
      finished[$pid]=1
      if wait $pid; then
        status="${c_green}${c_bold}succeed${c_normal}"
      else
        status="${c_red}${c_bold}failed${c_normal}"
      fi
    else
      status="${c_yellow}${c_bold}processing${c_normal}"
    fi
    echo -e "\e[2K\r${servers[$idx]} – $status"
  done
done
echo "Finished: $(date -u)"
