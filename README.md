# Yoda
Simple tool to dockerize and manage deployment of your project  

![Alt text](/yoda.jpg?raw=true "Help you deploy I will")  

## What is it?
Yoda helps you to dockerize existing application and automate deployment process.

1. Only BASH. No dependency shit!
2. Requirements: git, docker, docker-compose
3. Its simple like simplicity itself
4. Runs on MACOS and Linux systems

## Installation
First you need to install Yoda on your laptop. Its supereasy:

```bash
git clone git@github.com:dmitrykuzmenkov/yoda.git
cd yoda && make check && make install
```

Remember that you need bash version 4 or higher installed at least.

## Usage example
OK. You have git repository with your project.  
Go into this folder and run this command to initialize environment.

```bash
yoda init
```

Now you will get **docker** folder created in your project.  
Next step is prepare Dockerfile that located in docker/images folder.  
You can setup docker build options in file docker/images/Buildfile.

Now you can add container to your project.

```bash
yoda add container-name
```

Change template for docker-compose.yml file in docker/containers/container-name/container.yml.  
Now add this container to Envfile file.

We are done. Build it and start with just one command now:

```bash
yoda start
```

Done!

## Structure and methodology
1. You can have several images for single project and Dockerfiles for it.
2. Each Dockerfile is located in docker/images folder and has naming convention: Dockerfile-{name}.
3. You can have several containers depends on one image.
4. Each container has own folder with separated yml template for docker-compose and custom configs in docker/containers folder.
5. You can setup and use any BASH variables in file docker/env.sh. Its pregenerated for you.
6. Envfile is main file that has all info about what should be built and in which environment.
7. Each container can be build and start multiple time.

## Yoda command line tool usage
```bash
yoda command arguments
```

Commands available:  

| Command | Description |
|---|---|
| version | Display version of Yoda |
| help | Display this information |
| init | Prepare deployment folder in project |
| add |  Add new container skeleton structure to project |
| delete | Delete existing container from project |
| build |  Build images for current project |
| compose |  Display generated compose file for current environment |
| start |  Start all services for current project |
| stop | Stop all services for current project |
| deploy | Deploy project on one or all nodes |

### yoda version
Display current Yoda version

### yoda help
Display help information

### yoda init [folder]
Prepare dockerized skeleton in project directory

| Command | Description | Default |
|---|---|---|
| folder | Initialize all structure in folder with that name | yoda |

### yoda add [CONTAINER...]
Add container or bunch of containers skeleton to project

### yoda delete [CONTAINER...]
Delete container or bunch of existing containers from project

### yoda build
Build images for current project

### yoda compose [COMPOSE_SCRIPT]
Display generated docker-compose file in stdout.

| Command | Description | Default |
|---|---|:---:|
| COMPOSE_SCRIPT | Executable script who will process each container template, replace something and return as plain text. Container templates goes to stdin and 2 addition arguments are passed: --name and --sequence so name of container and number in scale map | - |

### yoda start [CONTAINER...]
Start all containers or only passed with arguments

### yoda stop [CONTAINER...]
Stop all containers or only passed with arguments

### yoda deploy [options]
Deploy single-node or whole cluster  
Options are:

| Options | Description | Default |
|---|---|:---:|
| --host | Deploy only on this host (single-node deploy) | - |
| --env | Deploy on all nodes with that environment (Envfile will be used) | - |
| --rev | Set custom revision to be deployed or rollback to | - |
| --branch | What branch will be deployed. | master |
| --args | Custom environment arguments that will be passed to 'yoda start' command on each remote server to be deployed | - |
