#!/usr/bin/env bash
echo "Usage: $YODA_CMD command arguments"
echo
echo "Commands available:"
echo "  version   Display version of Yoda"
echo "  help      Display this information"
echo "  init      Prepare deployment folder in project"
echo "  add       Add new container skeleton structure to project"
echo "  build     Build images for current project"
echo "  compose   Display generated compose file for current environment"
echo "  start     Start all services for current project"
echo "  stop      Stop all services for current project"
echo
echo "Usage:"
echo "  $YODA_CMD version"
echo "    Display current Yoda version"
echo
echo "  $YODA_CMD help"
echo "    Display help information"
echo
echo "  $YODA_CMD init"
echo "    Prepare dockerized skeleton in project directory"
echo
echo "  $YODA_CMD add [options]"
echo "    Add container skeleton to project"
echo
echo "    Options are:"
echo "      --name=container – name of container (required)"
echo
echo "  $YODA_CMD build"
echo "    Build images for current project"
echo
echo "  $YODA_CMD compose"
echo "    Display generated docker-compose file in stdout"
echo
echo "  $YODA_CMD start [CONTAINER...]"
echo "    Start all containers or only passed with arguments"
echo
echo "  $YODA_CMD stop [CONTAINER...]"
echo "    Stop all containers or only passed with arguments"
