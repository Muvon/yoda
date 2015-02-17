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

### Start container

Just run:
```bash
/docker/start [container-name]
```

### Stop container

If you want to stop running container you should execute in shell
```bash
/docker/stop [container-name]
```

### How to create and start a container

If you wanna create and start container asap you can use shortcut for it
```bash
/docker/run [container-name] [container-image]
```

### How to enter running container

Running container starting special init script and sleep inifity after configure. If you wanna enter it you should use special command
```bash
/docker/enter [container-name]
```

### Remove container

If you wanna remove container just run:
```bash
/docker/remove [container-name]
```
The init file will be moved to trash folder

## Inspect scripts

### Get ip of running container

```bash
/docker/inspect/ip [container-name]
```

### Get state of container

If you need to know state of container - running or not, just use the speical command

```bash
/docker/inspect/running [container-name]
```
