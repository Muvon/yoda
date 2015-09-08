# Docker manage scripts
## Installation guide

### Get docker scripts package

Just clone it from git in /docker/ directory:
```bash
git clone git@github.com:dmitrykuzmenkov/docker.git
```

### MACOS
1. Install coreutils: brew install coreutils
2. Download docker-machine and install it: docker-machine create --driver virtualbox --virtualbox-hostonly-cidr "172.16.1.1/16" dev
3. Enter machine (docker-machine ssh dev) and edit config /var/lib/boot2docker/profile add to EXTRA_FLAGS: -bip=172.17.42.1/16 -dns 172.17.42.1 -dns 8.8.8.8
4. Add route to docker via machine: sudo route add 172.17.0.0 172.16.0.100
5. Add to ~/.profile autoload docker-machine environment: eval (docker-machine env dev) 

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

## Utils for inspect containers and more

### Get id of container
```bash
/docker/utils/id [container-name]
```

### Get ip of running container

```bash
/docker/utils/ip [container-name]
```

### Get state of container

If you need to know state of container - running or not, just use the speical command

```bash
/docker/utils/running [container-name]
```

### Create custop IP-range bridge for docker

If you wanna assign ips to containers by self you can create custom IP-range bridge to use for it

```bash
/docker/utils/create-bridge [ip-range-with-cidr]
```

### Resize fixed size of your docker

If you wanna resize docker container use helper script
```bash
/docker/utils/resize container size-in-gb
```
