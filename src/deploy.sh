#!/usr/bin/env bash
set -e

for p in $*; do
  case $p in
    --host=*)
      host=${p##*=}
      ;;
    --env=*)
      env=${p##*=}
      ;;
    --rev=*)
      rev=${p##*=}
      ;;
    --branch=*)
      branch=${p##*=}
      ;;
    --args=*)
      custom_args=${p##*=}
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

  exec ssh -AT $host <<EOF
    set -e
    (
      set -x
      which git
    ) >/dev/null

    if [[ ! -d ~/.yoda ]]; then
      git clone -q $yoda_git_url ~/.yoda
      echo "PATH=\$PATH:~/.yoda" >> ~/.bashrc
      source ~/.bashrc
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

    ENV=$env REVISION=$rev $custom_args exec yoda start
EOF
  echo "Deploy to $host with environment $env and git branch $git_branch finished."
}

pids=()
servers=()
mkdir -p $DOCKER_ROOT/log

if [[ -n "$host" ]]; then
  servers=(`grep -E "^$host:" $DOCKER_ROOT/Envfile | cut -d':' -f1`)
else
  servers=(`grep $env$ $DOCKER_ROOT/Envfile | cut -d':' -f1`)
fi

for server in ${servers[*]}; do
  ( deploy $host >> $DOCKER_ROOT/log/${server//@/_}.log 2>&1 ) &
  pids+=($!)
done

echo "Deploying to ${#servers[*]} nodes"
for idx in ${!pids[@]}; do
  if wait ${pids[$idx]}; then
    echo "${servers[$idx]} – succeed"
  else
    echo "${servers[$idx]} – failed"
  fi
done
