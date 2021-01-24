#!/usr/bin/env bash
cat <<EOF
Usage: $YODA_CMD command arguments

Commands available:
  ${c_bold}version${c_normal}   Display version of Yoda
  ${c_bold}help${c_normal}      Display this information
  ${c_bold}init${c_normal}      Prepare deployment folder in project
  ${c_bold}upgrade${c_normal}   Upgrade to new version of initialized Yoda in project
  ${c_bold}add${c_normal}       Add new container skeleton structure to project
  ${c_bold}delete${c_normal}    Delete existing container from project
  ${c_bold}build${c_normal}     Build images for current project
  ${c_bold}compose${c_normal}   Display generated compose file for current environment
  ${c_bold}start${c_normal}     Start all services for current project
  ${c_bold}stop${c_normal}      Stop all services for current project
  ${c_bold}log${c_normal}       View output from containers
  ${c_bold}deploy${c_normal}    Deploy project on one or all nodes
  ${c_bold}rollback${c_normal}  Rollback is another deploy but with previous revision that detected automatic
  ${c_bold}destroy${c_normal}   Remove all created services by start command and all local images with volumes

Usage:
  ${c_bold}$YODA_CMD version${c_normal}
    Display current Yoda version

  ${c_bold}$YODA_CMD help${c_normal}
    Display help information

  ${c_bold}$YODA_CMD init [folder]${c_normal}
    Prepare dockerized skeleton in project directory
    folder    Initialize all structure in folder with that name. Default: yoda

  ${c_bold}$YODA_CMD upgrade${c_normal}
    Upgrade to new version of initialized Yoda in project

  ${c_bold}$YODA_CMD add [CONTAINER...]${c_normal}
    Add container or bunch of containers skeleton to project

  ${c_bold}$YODA_CMD delete [CONTAINER...]${c_normal}
    Delete container or bunch of existing containers from project

  ${c_bold}$YODA_CMD build [options] [IMAGES...]${c_normal}
    Build images for current project
    Options are:
      --rebuild     Force build also if image exists already. Default: not set.
      --no-cache    Dont use Dockerfile cache when building images. Default: not set.
      --push        Should we push builded images to repository if we have REPOSITORY_URL defined in env.sh file. Default: not set

  ${c_bold}$YODA_CMD compose [COMPOSE_SCRIPT]${c_normal}
    Display generated docker-compose file in stdout.
    COMPOSE_SCRIPT    executable script who will process each container template, replace something and return as plain text. Container templates goes to stdin and 2 addition arguments are passed: --name and --sequence so name of container and number in scale map

  ${c_bold}$YODA_CMD start [options] [CONTAINER...]${c_normal}
    Start all containers or only passed with arguments
    Options are:
      --rebuild     Rebuild all images also if they exist with that revision. Default: not set.
      --no-cache    Dont use Dockerfile cache on building images stage. It passes internally to build command. Default: not set.
      --recreate    Force recreate containers. Default: not set.
      --force       Should start containers excluding Startfile flow description. Default: not set.

  ${c_bold}$YODA_CMD stop [CONTAINER...]${c_normal}
    Stop all containers or only passed with arguments

  ${c_bold}$YODA_CMD log [options] [SERVICE...]${c_normal}
    View output from containers.
    Options are the same as for "docker-compose logs" command:
      --no-color          Produce monochrome output.
      -f, --follow        Follow log output.
      -t, --timestamps    Show timestamps.
      --tail="all"        Number of lines to show from the end of the logs
                          for each container.

  ${c_bold}$YODA_CMD status${c_normal}
    Display current status of services

  ${c_bold}$YODA_CMD deploy [options]${c_normal}
    Deploy single-node or whole cluster
    Options are:
      --host=host         Deploy on single host or using host regexp pattern (Envfile will be used)
      --env=environment   Deploy on all nodes with that environment (Envfile will be used)
      --stack=stack       Deploy only this stack in current environment
      --rev=revision      Set custom revision to be deployed or rollback to
      --branch=gitbranch  What branch will be deployed. Default is master
      --args=arguments    Custom environment arguments that will be passed to 'yoda start' command on each remote server to be deployed.
      --force             Should start containers excluding Startenv file

  ${c_bold}$YODA_CMD rollback [options]${c_normal}
    Rollback to previous revision on selected host or environment
    Options are the same as for deploy command.

  ${c_bold}$YODA_CMD destroy${c_normal}
    Remove all created services by start command and all local images with volumes
EOF
