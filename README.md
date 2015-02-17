# Docker manage scripts
## Installation guide

### Get docker scripts package

Just clone it from git in /docker/ directory:
```bash
git clone git@github.com:dmitrykuzmenkov/docker.git
```

## Usage

### Create new container

To create new container just use the command
```bash
/docker/create [container-name] [container-image]
```

container-name - choose the name for container, for example: test
container-image - the image used to create container, default is centos:7

### Init script for container

You can create special bash script which will be run as you start your new container.
If you want to make docker named test, you should create init script bash-init /docker/containers/test which will be executed asap container started.
Dont forget to make it executable.

### Remove container

If you wanna remove container just run:
```bash
/docker/remove [container-name]
```
The init file will be moved to trash folder


