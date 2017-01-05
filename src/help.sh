#!/usr/bin/env bash
cat <<EOF
Usage: $YODA_CMD command arguments

Commands available:
  version   Display version of Yoda
  help      Display this information
  init      Prepare deployment folder in project
  upgrade   Upgrade to new version of initialized Yoda in project
  add       Add new container skeleton structure to project
  delete    Delete existing container from project
  build     Build images for current project
  compose   Display generated compose file for current environment
  start     Start all services for current project
  stop      Stop all services for current project
  deploy    Deploy project on one or all nodes

Usage:
  $YODA_CMD version
    Display current Yoda version

  $YODA_CMD help
    Display help information

  $YODA_CMD init [folder]
    Prepare dockerized skeleton in project directory
    folder    Initialize all structure in folder with that name. Default: yoda

  $YODA_CMD upgrade
    Upgrade to new version of initialized Yoda in project

  $YODA_CMD add [CONTAINER...]
    Add container or bunch of containers skeleton to project

  $YODA_CMD delete [CONTAINER...]
    Delete container or bunch of existing containers from project

  $YODA_CMD build [options]
    Build images for current project
    Options are:
      --rebuild     Force build also if image exists already. Default: not set.

  $YODA_CMD compose [COMPOSE_SCRIPT]
    Display generated docker-compose file in stdout.
    COMPOSE_SCRIPT    executable script who will process each container template, replace something and return as plain text. Container templates goes to stdin and 2 addition arguments are passed: --name and --sequence so name of container and number in scale map

  $YODA_CMD start [options] [CONTAINER...]
    Start all containers or only passed with arguments
    Options are:
      --rebuild     Rebuild all images also if they exist with that revision. Default: not set.

  $YODA_CMD stop [CONTAINER...]
    Stop all containers or only passed with arguments

  $YODA_CMD deploy [options]
    Deploy single-node or whole cluster
    Options are:
      --host=host         Deploy only on this host (single-node deploy)
      --env=environment   Deploy on all nodes with that environment (Envfile will be used)
      --rev=revision      Set custom revision to be deployed or rollback to
      --branch=gitbranch  What branch will be deployed. Default is master
      --args=arguments    Custom environment arguments that will be passed to 'yoda start' command on each remote server to be deployed.
EOF
