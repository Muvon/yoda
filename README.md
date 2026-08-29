# Yoda

[![CI](https://github.com/Muvon/yoda/actions/workflows/ci.yml/badge.svg)](https://github.com/Muvon/yoda/actions/workflows/ci.yml)

> Dockerize any project and deploy it to your servers — with pure Bash.

![Yoda — help you deploy I will](/img/yoda.jpg?raw=true)

## Why Yoda?

You have an app and a server. Yoda closes the gap: it scaffolds a Docker setup inside your project, builds images, generates a docker-compose file per environment, and deploys to one or many servers over SSH — with one-command rollback when things go sideways.

- **Zero dependencies** — 100% Bash. You only need `git` and Docker with the Compose plugin
- **Environment-aware** — dev/staging/production with per-env compose templates and env files
- **Multi-server** — deploy a whole cluster in parallel, with namespaces per host
- **Rollback built-in** — `yoda rollback` returns every node to the previous revision
- **Fully hackable** — override build, compose, start, or deploy with your own executable script

Runs on macOS and Linux. Current version: **2.4** — see [CHANGES.md](CHANGES.md) for the full history.

## Quick Start

```bash
git clone https://github.com/Muvon/yoda.git
cd yoda && make check && sudo make install
```

`make check` verifies all prerequisites; `make install` symlinks `yoda` into `/usr/local/bin` (so `git pull` in the clone keeps it up to date).

Then, inside your project:

```bash
yoda init              # creates the docker/ folder in your project
yoda add app           # adds a container skeleton
# edit docker/images/Dockerfile-base and docker/containers/app/container.yml
yoda start             # builds images and starts everything
```

Done. Full walkthrough below.

### Prerequisites

Verified automatically by `make check`:

| Requirement | Minimum |
|---|---|
| Bash | 4.0 |
| GNU sed | — (macOS: `brew install gnu-sed`) |
| Docker API | 1.41 |
| Docker Compose plugin | 1.28 |
| Git | 2.22 |

Familiarity with [Docker](https://docs.docker.com) and [Compose file syntax](https://docs.docker.com/compose/compose-file/) helps, but Yoda hides most of the plumbing.

## Usage example

You have a git repository with your project. Go into it and initialize the environment:

```bash
yoda init
```

This creates a **docker/** folder in your project. Next, prepare the Dockerfile located in `docker/images/` and set build options in `docker/Buildfile`.

Now add a container:

```bash
yoda add container-name
```

Edit the compose template in `docker/containers/container-name/container.yml`.

That's it — build and start with one command:

```bash
yoda start
```

## Deploy to your servers

Describe your servers in `docker/Envfile`, provision them once, then deploy:

```bash
yoda setup --env=production      # one-time server provisioning
yoda deploy --env=production     # deploy the whole cluster in parallel
yoda rollback --env=production   # revert every node to the previous revision
```

Setup scripts ship for **Rocky Linux 9/10, CentOS Stream 9 and CentOS 8** (see [`server/`](server/)); other distributions need manual setup. Before `yoda setup`, put your `authorized_keys` file into `docker/.ssh/`.

## Project structure

`yoda init` creates a `docker/` folder by default (pass a name to use another: `yoda init myfolder`):

| Path | Description |
|---|---|
| `containers/` | One folder per container, each with its compose template |
| `images/` | Dockerfiles for your images. Naming convention: `Dockerfile-{name}` |
| `env.sh` | BASH variables for your build context, shared by all environments. Optionally extended per environment, e.g. `env.dev.sh` |
| `Buildfile` | Declarative file describing how to build each image |
| `Envfile` | Maps servers to environments and environments to containers |
| `Startfile` | Optional start flow: ordering, chunked scaling, stop-before-start |
| `.yodarc` | Locked config with Yoda version and common variables. Don't edit — it's rewritten on `yoda upgrade` |

### containers/

When you run `yoda add container`, a folder with the same name appears here. It contains:

| File | Description |
|---|---|
| `container.yml` | A docker-compose service section (without the service name) used to generate the final `docker-compose.yml` |
| `container.[env].yml` | Optional per-environment override; e.g. `container.dev.yml` keys replace `container.yml` keys when running in `dev` |
| `entrypoint` | Optional executable entrypoint for the container — good practice to use it |

`container.yml` is a valid compose service section. `container_name` is immutable and managed by Yoda. You can reference images from `Buildfile` by key: if Buildfile defines image `base`, write `image: base` and Yoda replaces it with the built image name.

### env.sh

Declare BASH variables and use them everywhere — builds, compose templates, scripts:

```bash
IMAGE_BASE=myapp:$REVISION
```

Create `env.dev.sh` to extend `env.sh` for a specific environment. Environments support namespaces (`production.server1`, `production.server2`); since one server can't hold two namespaces, use `env.production.sh` (without the namespace part) for the shared config.

### Buildfile

One line per image — name plus arguments passed to `docker build`:

```yaml
base: -t $IMAGE_BASE --compress
db: -t postgres:9.5
```

Use `name[context]:` syntax for a custom build context. By default the current directory is the context. See `docker build --help` for available arguments.

### Envfile

Maps servers to environments and environments to containers:

```yaml
user@server: production
production: container1 container2=2
dev: container1
```

The example above deploys `user@server` as `production` with one `container1` and two `container2` instances; the `dev` environment runs only `container1`.

Multi-server with namespaces:

```yaml
user@server1: production.stack1
user@server2: production.stack2
production.stack1: container1 container2=2
production.stack2: container3 container4
dev: container1
```

The dot (`.`) separates environment from namespace, letting you customize which services run on which server while keeping a single `production` environment.

### Startfile

Controls the start flow for complex services:

```yaml
dev:
  flow: deploy container2 container1=2
  stop: container2
  wait: deploy
```

- **flow** — start order; `container=chunk` starts containers in chunks of that size
- **stop** — services stopped before starting
- **wait** — services whose exit code Yoda waits for before continuing

In the example, [yoda start](#yoda-start-options-container) first stops `container2` if running, then starts `deploy`, waits for it to exit, starts `container2`, and finally starts `container1` in chunks of 2.

With multi-server namespaces, describe each namespaced environment separately — their flows are independent.

## CLI reference

```bash
yoda command arguments
```

| Command | Description |
|---|---|
| [version](#yoda-version) | Display version of Yoda |
| [help](#yoda-help) | Display help information |
| [init](#yoda-init-folder) | Prepare deployment folder in project |
| [upgrade](#yoda-upgrade) | Upgrade initialized Yoda in project to a new version |
| [add](#yoda-add-container) | Add new container skeleton to project |
| [delete](#yoda-delete-container) | Delete existing container from project |
| [build](#yoda-build-options-images) | Build images for current project |
| [compose](#yoda-compose-compose_script) | Display generated compose file for current environment |
| [start](#yoda-start-options-container) | Start all services for current project |
| [stop](#yoda-stop-container) | Stop all services for current project |
| [status](#yoda-status) | Display current status of services |
| [log](#yoda-log-container) | Show log for a given container |
| [logs](#yoda-logs) | Show log for all containers |
| [exec](#yoda-exec-container-command) | Execute a command in a container |
| [enter](#yoda-enter-container) | Enter a container with autodetected shell: zsh, bash or sh |
| [setup](#yoda-setup-options) | Prepare a server for use with Yoda deployment |
| [deploy](#yoda-deploy-options) | Deploy project on one or all nodes |
| [rollback](#yoda-rollback-options) | Rollback project on one or all nodes to previous revision |
| [destroy](#yoda-destroy) | Remove all services, local images and volumes created by start |

> **Note:** `upgrade`, `add` and `delete` are allowed only in the `dev` environment.

### yoda version

Display current Yoda version.

### yoda help

Display help information.

### yoda init [folder]

Prepare the dockerized skeleton in your project directory.

| Argument | Description | Default |
|---|---|---|
| folder | Create the structure in a folder with this name | docker |

### yoda upgrade

Upgrade the initialized Yoda in your project to the new version.

### yoda add [CONTAINER...]

Add one or more container skeletons to the project.

### yoda delete [CONTAINER...]

Delete one or more existing containers from the project.

### yoda build [options] [IMAGES...]

Build images for the current project. Optionally pass image names to build; defaults to every image in Buildfile.

| Option | Description | Default |
|---|---|:---:|
| --rebuild | Force build even if the image already exists | omitted |
| --no-cache | Don't use Dockerfile cache when building | omitted |
| --push | Push built images to the registry if `REGISTRY_URL` is defined in [env.sh](#envsh) | omitted |

### yoda compose [COMPOSE_SCRIPT]

Display the generated docker-compose file in stdout.

| Argument | Description | Default |
|---|---|:---:|
| COMPOSE_SCRIPT | Executable script that processes each container template and returns plain text. The template comes via stdin with two extra arguments: `--name` (container name) and `--sequence` (number in the scale map) | - |

### yoda start [options] [CONTAINER...]

Start all containers, or only the ones passed as arguments.

| Option | Description | Default |
|---|---|:---:|
| --rebuild | Rebuild images even if they exist with this revision | omitted |
| --no-cache | Don't use Dockerfile cache when building (passed to build internally) | omitted |
| --recreate | Force recreate containers | omitted |
| --force | Start containers ignoring the Startfile flow | omitted |

You can manage the start/restart flow with the [Startfile](#startfile).

### yoda stop [CONTAINER...]

Stop all containers, or only the ones passed as arguments.

### yoda status

Display current status of services.

### yoda log CONTAINER...

Show log for a given container. Accepts the same options as `docker compose logs` (`-f`, `--tail`, `--timestamps`, `--no-color`).

### yoda logs

Show logs for all containers.

### yoda exec CONTAINER... command

Execute a command in a container.

### yoda enter CONTAINER...

Enter a container with one of the autodetected shells: zsh, bash or sh.

### yoda setup [options]

Prepare a server before it can be used for deployment. Setup scripts are available for Rocky Linux 9/10, CentOS Stream 9 and CentOS 8; other distributions require manual setup. Before running setup, put your `authorized_keys` into the `docker/.ssh/` folder.

| Option | Description | Default |
|---|---|:---:|
| --host | Setup a single host or hosts matching a regexp pattern (Envfile is used) | - |
| --env | Setup all servers in an environment (Envfile is used) | - |

### yoda deploy [options]

Deploy a single node or the whole cluster in parallel. Exits with code 0 on success and 1 on failure (including failures on any single node).

| Option | Description | Default |
|---|---|:---:|
| --host | Deploy on a single host or hosts matching a regexp pattern (Envfile is used) | - |
| --env | Deploy on all nodes with this environment (Envfile is used) | - |
| --stack | Deploy only this stack in the current environment | - |
| --rev | Set a custom revision to deploy or rollback to | - |
| --branch | Branch to deploy | current branch |
| --args | Custom environment arguments passed to `yoda start` on each remote server | - |
| --force | Pass this flag to [yoda start](#yoda-start-options-container) | omitted |

### yoda rollback [options]

Rollback to the previous revision. Exits with code 0 on success and 1 on failure (including failures on any single node). Options are the same as for the deploy command.

### yoda destroy

Remove all services created by the start command, plus all local images and volumes.

## Philosophy

1. A project can have several images.
2. Each image has a Dockerfile in `docker/images/` named by convention: `Dockerfile-{name}`.
3. Several containers can share one image.
4. Each container has its own folder in `docker/containers/` following the structure described above.
5. Use any BASH variables in `docker/env.sh` — it's pregenerated for you.
6. Envfile is the source of truth: what gets built, in which environment, and which server runs which environment.
7. Each container can be scaled N times from a single template with different names.
8. Customize deploy, build, compose and start stages fully — just drop your own executable script (any language) into the docker folder.

## Internals

Curious how build, compose, start and deploy flow through their stages? See [FLOW.md](FLOW.md).

## Contributing

```bash
make lint    # shellcheck + bash -n on all scripts
make test    # bats test suite
```
