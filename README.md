# Docker manage scripts
## Installation guide

### Get docker scripts package

Just clone it from git in /docker/ directory:
```bash
git clone git@github.com:dmitrykuzmenkov/docker.git
```

Dont forget to install docker running

```bash
curl -sSL https://get.docker.com/ | sh
```

### Linux
Use native docker in your distribution. Just install it and run as is.

### MACOS
There are known issues running docker on VirtualBox and VMWare fusion. I advice to use Parallels.

1. First you have to install virtual machine with linux distribution and docker inside it.
2. Open port 2376 on your linux destribution and run docker on your virtual machine using command:
```
docker -d -D -g /var/lib/docker -H unix:// -H tcp://0.0.0.0:2376 --tls=false
```
Use -s aufs for setup storage driver.
3. Install docker of same version on your MACOS
4. Install coreutils: brew install coreutils
5. Add route to docker via machine: sudo route add 172.17.0.0 #HERE IP OF YOUR VM#
6. Add custom config to your bash environment:
```
set -x DOCKER_TLS_VERIFY "";
set -x DOCKER_HOST "tcp://#HERE IP OF YOUR VM#:2376";
set -x DOCKER_CERT_PATH "";
```

### Windows
Are you kidding? Still working on Windows? Drop it and replace with Linux or OS X.

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
