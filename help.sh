#!/usr/bin/env bash
cat <<EOF
Usage: $YODA_CMD command arguments

Commands available:
  version   Display version of Yoda
  help      Display this information
  init      Prepare deployment folder in project
  add       Add new container skeleton structure to project
  build     Build images for current project
  compose   Display generated compose file for current environment
  start     Start all services for current project
  stop      Stop all services for current project
echo
Usage:
  $YODA_CMD version
    Display current Yoda version
echo
  $YODA_CMD help
    Display help information
echo
  $YODA_CMD init
    Prepare dockerized skeleton in project directory
echo
  $YODA_CMD add [options]
    Add container skeleton to project
echo
    Options are:
      --name=container – name of container (required)
echo
  $YODA_CMD build
    Build images for current project
echo
  $YODA_CMD compose
    Display generated docker-compose file in stdout
echo
  $YODA_CMD start [CONTAINER...]
    Start all containers or only passed with arguments
echo
  $YODA_CMD stop [CONTAINER...]
    Stop all containers or only passed with arguments
EOF
