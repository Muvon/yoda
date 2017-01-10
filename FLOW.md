# Flow
## Common flow for build, deploy and start commands
When you run yoda build or other commands from pool described about it goes through several stages:

| Stage | Description |
|---|---|
| Check | First we need to check if current project with source code has Yoda installed. If no – we fail here. |
| Custom script | Next step is check if there is custom script to execute. For example if you run **yoda build** command we look build file in docker folder of your project and if its exists and has executable rights we run it. If no – execution fails here with alert message. If this script exists its last point of execution and you have to call same command inside your script to make it works. |
| Execute | If no custom script found we just execute all needed stuff for current command. |

## yoda start
This main command that do all magic to run services with current environment. It has several stages:

| Stage | Description |
|---|---|
| Compose | First we run **yoda compose** command and generate docker-compose.yml file for current environment we run. Environment is in ENV variable. Default is dev. |
| Build | We building all docker images in this stage described in Buildfile. These images will be used for containers in docker-compose.yml. |
| Up | This stage runs **docker-compose up** with --no-build and some other arguments to make all services work. |

## yoda compose
Compose generates docker-compose.yml file using all containers templates sections you have for current environment and output it in stdout.

| Stage | Description |
|---|---|
| Scale map | Parse all arguments with container=#amount and create scale map that contains which container we should generate to docker-compose.yml file and how much times. |
| Merge custom env container | We merge all containers depends on scale map to one output as docker-compose.yml syntax. If we have container.ENV.yml we merge it with replacing container.yml template keys with new keys from current environment. |
| Replacements | Each template has special parameters that are replaced in generation stage. **{{name}}** – name of container, **#** – number of container in scale map starting with 0. |
| Custom composer | For each container template generation we call custom composer script if it was passed as COMPOSE_SCRIPT var with --name and --sequence arguments as name of container and number of container in scale map.  |

## yoda build
Build has very simple flow. 

| Stage | Description |
|---|---|
| Read Buildfile | First we check Buildfile with information what to build. |
| Should build image | If yoda build gets optional images passed it will check should we build that image or no. If no just skip and go next |
| Check existing image | Next we check if there was such image already built and if yes – skip it. |
| Build | Pass to docker build command arguments we found in Buildfile on first stage. |

## yoda deploy
TODO: add info about deploy stage after finish with host matching logic
