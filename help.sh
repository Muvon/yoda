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

Usage:
  $YODA_CMD version
    Display current Yoda version

  $YODA_CMD help
    Display help information

  $YODA_CMD init
    Prepare dockerized skeleton in project directory

  $YODA_CMD add [options]
    Add container skeleton to project
    Options are:
      --name=container – name of container (required)

  $YODA_CMD build
    Build images for current project

  $YODA_CMD compose [options]
    Display generated docker-compose file in stdout
    Options are:
      --composer=path-to-script – executable script who will process each container template, replace something and return as plain text. Container templates goes to stdin and 2 addition arguments are passed: --name and --sequence so name of container and number in scale map

  $YODA_CMD start [CONTAINER...]
    Start all containers or only passed with arguments

  $YODA_CMD stop [CONTAINER...]
    Stop all containers or only passed with arguments
EOF
