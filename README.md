# Yoda
Simple tool to dockerize and manage deployment of your project  

![Alt text](/yoda.jpg?raw=true "Help you deploy I will")  

## Under development...

## What is it?
You have application and want dockerize it in fast way? That tool can help you with it.  
Yoda makes it simple to put your source code and services into docker and separate your microservices between nodes.

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
