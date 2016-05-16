# Yoda
## Installation guide

### Get yoda package first
1. First clone it to any directory.
2. Open that directory in shell.
3. Run make && make install commands
4. Enjoy


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
docker daemon -D -g /var/lib/docker -H unix:// -H tcp://0.0.0.0:2376 --tls=false
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
There is one main bin file to manipulate all Yoda possibilities. Its called yoda.
Use it like this: yoda [command] [arguments]
For more help run yoda [command] --help

### Create new container
```bash
yoda create --image=[docker-image] --ip=[container-ip] --expose=[expose-ports] --options=[more-docker-args] [--args=cmd-args] [container-name]
```

container-name - name of container to run
--ip - (optional) ip for container in subnet 172.10.0.0/16. If not provided docker will assign it automatic
--image - (optional) docker image to use for container creation
--expose - (optional) expose selected ports from container to host
--options - (optional) other args that will be passed to docker create command
--args - (optional) arguments to be passed to entrypoint of container

### Start container
```bash
yoda start [container-name]
```

### Stop container
```bash
yoda stop [container-name]
```

### Entering running container
```bash
yoda enter [container-name]
```

Its easy to enter using bash into specific container

### Remove container
```bash
yoda remove [container-name]
```

Container config will be moved into trash folder. But all other data will be destoyed by docker.


### Init script for container

You can create special bash script which will be run as you start your new container.
If you want to make docker named test, you should create init script bash-init /docker/containers/test which will be executed asap container started.
Dont forget to make it executable.


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
