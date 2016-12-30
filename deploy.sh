#!/usr/bin/env bash
for p in "$@"; do
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

if [[ -z "$host" || -z "$env" ]]; then
  echo "Host or environment is required to be passed."
  exit
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

if [[ -n "$host" ]]; then
  env=$(cat $DOCKER_ROOT/Envfile | grep $host: | cut -d':' -f2 | tr -d ' ')
  if [[ -z "$env" ]]; then
    echo "Cant define environment for host '$host' using '$DOCKER_ROOT/Envfile'."
    exit 1
  fi

  # First check known hosts
  cat ~/.ssh/known_hosts | grep $host || ssh-keyscan $host >> ~/.ssh/known_hosts

  # Detect git host to do keyscan check
  git_host=$(echo $GIT_URL | cut -d'@' -f2 | cut -d':' -f1)

  exec ssh -AT $host <<EOF
    set -e
    (
      set -x
      which git
    ) >/dev/null

    mkdir -p ~/.yoda && cd \$_
    if [[ ! -d $COMPOSE_PROJECT_NAME ]]; then
      cat ~/.ssh/known_hosts | grep $git_host || ssh-keyscan $git_host >> ~/.ssh/known_hosts
      git clone -q $GIT_URL $COMPOSE_PROJECT_NAME
    fi
    cd $COMPOSE_PROJECT_NAME && git fetch -p
    git checkout -f $git_branch && git reset --hard origin/$git_branch
    git pull --rebase origin $git_branch
    git clean -fdx

    ENV=$env REVISION=$rev $custom_args exec yoda start
EOF

  echo "Deploy to $host with environment $env and git branch $git_branch finished."
else
  pids=()
  servers=()

  for server in `cat $DOCKER_ROOT/Envfile | grep $env$ | cut -d':' -f1`; do
    ( yoda deploy --host=$server --branch=$git_branch --rev=$rev $custom_args >> $DOCKER_ROOT/deploy/${server//@/_}.log 2>&1 ) &
    pids+=($!)
    servers+=($server)
  done

  echo "Deploying to ${#servers[*]} nodes"
  for idx in ${!pids[@]}; do
    if wait ${pids[$idx]}; then
      echo "${servers[$idx]} – succeed"
    else
      echo "${servers[$idx]} – failed"
    fi
  done
fi
