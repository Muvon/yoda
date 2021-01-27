#!/usr/bin/env bash
set -e

arg_dir="$*"

if [[ -f $DOCKER_ROOT/.yodarc ]]; then
  # shellcheck source=yoda/.yodarc
  source $DOCKER_ROOT/.yodarc
  >&2 echo "Yoda was initialized already. Yoda version: '$YODA_VERSION'. Yoda home path: '$DOCKER_ROOT'."
  exit 1
fi

yoda_dir=${arg_dir:-docker}
if [[ -e $yoda_dir ]]; then
  >&2 echo "Error while initializing Yoda. Folder '$yoda_dir' already exists."
  exit 1
fi

project_name=${arg_name:-"${PWD##*/}"}
username=$(git config --global user.name || echo 'Unknown maintainer')
useremail=$(git config --global user.email || echo 'noreply@yoda.org')

touch .dockerignore
mkdir -p $yoda_dir/{images,containers,.ssh/connections}
sed 's/{{driver}}/host/g' "$YODA_PATH/templates/networks.yml" > "$yoda_dir/containers/networks.yml"
sed 's/{{driver}}/bridge/g' "$YODA_PATH/templates/networks.yml" > "$yoda_dir/containers/networks.dev.yml"
cp $YODA_PATH/templates/env.sh $yoda_dir
cp $YODA_PATH/templates/{Env,Build,Start}file $yoda_dir
sed "s/{{user}}/$username/g;s/{{email}}/$useremail/g;" $YODA_PATH/templates/Dockerfile > $yoda_dir/images/Dockerfile-base
cp $YODA_PATH/templates/gitignore $yoda_dir/.gitignore
cp $YODA_PATH/templates/dockerignore $yoda_dir/.dockerignore
sed "s/{{name}}/$project_name/g;s/{{yoda_version}}/$YODA_VERSION/g" $YODA_PATH/templates/yodarc > $yoda_dir/.yodarc
