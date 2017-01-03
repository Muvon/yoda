# Yoda
Simple tool to dockerize and manage deployment of your project  

![Alt text](/img/yoda.jpg?raw=true "Help you deploy I will")  

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
You can setup docker build options in file docker/Buildfile.

Now you can add container to your project.

```bash
yoda add container-name
```

Change template for docker-compose.yml file in docker/containers/container-name/container.yml.

We are done. Build it and start with just one command now:

```bash
yoda start
```

Done!

## Philosophy
1. You can have several images for single project.
2. Each image you use must have Dockerfile located in docker/images folder and named by convetion: Dockerfile-{name}.
3. You can have several containers depends on one image.
4. Each container has own folder in docker/containers with structure followed by convention in this README.
5. You can setup and use any BASH variables in file docker/env.sh. Its pregenerated for you.
6. Envfile is main file that has all info about what should be built and in which environment, also what server runs which environment for deploy.
7. Each container can be scaled N times and started using single template but different names.
8. You can fully customize deploy, build, compose stages just wrapping in your own script using any language.

##  Init folder structure
When you do yoda init in your project it creates by default yoda folder. This folder has following structure

| Path | Descrition |
|---|---|
| containers | This folder contains all containers with templates in your project |
| images | It contains Dockerfiles for you images. Common naming is: Dockerfile-name. Where is name is just name of image you build with that dockerfile |
| env.sh | Its environment for your building context. You can define custom variables and use it everywhere in builds and other scripts |
| Buildfile | It is declarative file that describes how to build each image you have. It has simple structure **name: arguments for docker build command** where is name is your image in images folder with same name |
| Envfile | It describes all environments and link servers for deploy with its environments you have. No limitation. You can create own environments and describe what containers must be built there |

### Path: containers
When you adding new container folder is created here with same name. For example if you add container with name **container**. Same folder will appear here.  
This folder will contain some files.
 
| File | Description |
|---|---|
| container.yml | Its docker-compose section without section name that describes how to build container. This file used to generate whole docker-compose.yml file for starting services |
| container.[env].yml | Optional you can create file with template that will be used when docker-compose.yml is generated for this environment. For example if you have container.dev.yml and starting services in dev environment will use all keys from this file replacing common container.yml keys|
| entrypoint | Its entrypoint for you container. Its optional but good practise to use this file as executable for your container starting point |

### Path: env.sh
Here you can declare BASH environment variables and use it everywhere.  
For example you can write here IMAGE_NAME to set image name with revision and other staff and use it in Buildfile and container.yml.

### Path: Buildfile
Its simple file that have following structure:

```yaml
base: -t $IMAGE_BASE --compress
db: -t postgres:9.5
```

Each line contains image name and build args that will be passed in **docker build** command. See more info in **docker build --help**.

### Path: Envfile
Its simple file YAML like with environment and server description:
  
```yaml
user@server: production
production: container1 container2=2
dev: container1
```

Example file above declare server **user@server** that will be deployed as **production**. And production will contain one container1 and two container2 instances.  
ANd in dev environment only one container with name container1 will be started.

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

### yoda build [options]
Build images for current project
Options are:

| Options | Description | Default |
|---|---|:---:|
| --rebuild | Force build also if image exists already | omited |

### yoda compose [COMPOSE_SCRIPT]
Display generated docker-compose file in stdout.

| Command | Description | Default |
|---|---|:---:|
| COMPOSE_SCRIPT | Executable script who will process each container template, replace something and return as plain text. Container templates goes to stdin and 2 addition arguments are passed: --name and --sequence so name of container and number in scale map | - |

### yoda start [options] [CONTAINER...]
Start all containers or only passed with arguments
Options are:

| Options | Description | Default |
|---|---|:---:|
| --rebuild | Rebuild all images also if they exist with that revision | omited |

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
