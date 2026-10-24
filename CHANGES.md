# Yoda change log

## Unreleased

1. License Yoda under the Apache License 2.0
2. Fix the version switch to the project's pinned Yoda version: it checks out the tag only when it holds that version, runs only inside Yoda's own git clone (never a parent repository such as Homebrew's), and prints its messages to stderr so they no longer end up in `yoda compose` output
3. `yoda deploy` from a release install (e.g. Homebrew) clones Yoda on new servers from upstream instead of an unrelated or empty URL; `ssh-keyscan` is skipped for http(s) git URLs; the `~/.bashrc` PATH line is added only once
4. Startfile is read from the configured Yoda folder instead of `docker/` only
5. Startfile supports `<env>.<stack>` sections; a shared `<env>` section applies to each stack only for the services it runs
6. (!) An unknown service in the Startfile aborts `yoda start` instead of silently skipping the whole flow
7. Fix Startfile `flow` chunks (`web=2`) failing validation when the Envfile count differs, and `wait` on scaled services
8. Hooks may `exec yoda <command>` without looping; the recursion guard uses `YODA_HOOK` instead of the parent process
9. `yoda add worker.mail` creates the nested `containers/worker/mail/` folder that compose expects, and keeps a block-list `dev` environment in the Envfile as a list
10. `yoda delete` removes only exact container names (deleting `web` no longer turns `webapp` into `app`)
11. `yoda rollback` fails with fewer than two recorded deploys instead of redeploying the current revision or the branch head
12. `make check` requires the Docker Compose plugin v2

## Version 2.5

1. Add `yoda start --keep-orphans` to keep containers that are no longer in the compose file running (drops `--remove-orphans`)
2. Fix `yoda start` and Startfile `stop` with several containers: each container is passed to compose as its own argument
3. `yoda deploy --rev` (and `yoda rollback`) checks out that git revision instead of deploying the branch head tagged with it
4. `yoda compose COMPOSE_SCRIPT` fails when the script is missing or not executable instead of silently skipping it
5. Add `yoda start --wait` to return only once started containers are running and healthy (Compose `up --wait`)
6. Stop grace belongs to the service: with an empty `STOP_WAIT_TIMEOUT` (new default in `.yodarc`) stop omits `-t`, so each service's `stop_grace_period` applies (Compose default 10 s, as before)
7. Fix Startfile `stop`/`flow`/`wait` for project and container names with dots: names are taken by stripping the project prefix instead of cutting on dots

## Version 2.4

Coming soon :)

## Version 2.3

1. Fix issue with merged anchors due to docker yaml parser update
2. Add stale config

## Version 2.2

1. Correct diverse problems related to the server setup scripts.
2. Transition to using the Docker Compose plugin rather than the Docker-Compose script.
3. Implement support for the Rocky Linux 9 server setup.
4. Configure server setup scripts to utilize the UTC timezone.

## Version 2.1

### New v2.1

1. Install tuned
2. Add sysctl.conf file for tuning setup

### Bugs v2.1

1. Fix issue with PowerTools repo in some Centos installations (due to case sensitive filename)

## Version 2.0

### New v2.0

1. Add *daemon.json* and change the way we use for setup server with docker
2. Add possibility to setup new server with **yoda** before use it for deploy by running:

    ```bash
    yoda setup --env=production
    ```

3. Add possibility of nested containers with dot (.) as delimeter of paths. Useful to use for daemons.
4. Links are deprecated. Use networks instead for each environment and assign it in compose.yml file
5. Introduce usage of YAML merge anchors. Set default anchor network_mode globally to use in auto append to all containers that do not have network_mode setuped
6. Add support of templates vars in container yml files. You can use %{ENV} and %{STACK} for dropin replacements depends on current env
7. Add support or array syntax of env stack definition in Envfile
8. Templated configs possible with extension of .yoda on docker folder. In that case .yoda will be removed and env vars replaced to final file before its built.

### Changes v2.0

1. Various code refactoring and optimizations
2. Change logic how we handle **--env** in **deploy**/**rollback** commands and introduce **--stack**. ENV contains only environment now. You have to change

    ```bash
      yoda deploy --env=production.stack
    ```

    to

    ```bash
      yoda deploy --env=production --stack=stack
    ```

3. Centos 7 setup script is deprecated and removed
4. If you have server with production.stack now Yoda reads 2 files: common production config *env.production.sh* & stack config in production *env.production.stack.sh*
5. **yoda deploy/rollback** command shows 5 lines of failed servers after in console output now.
6. Back to compose file version 2.4 instead of 3.x cuz 3.x is made for swarm mode that we do not use

## Version 1.2

### New v1.2

1. Add automatic support of git-secret on deployment
2. Add startup server script for Centos 8 to setup ready to deploy node
3. Add log command to follow output of containers
4. Add --no-cache argument for build command
5. Add possibility to use custom context with Buildfile

### Changes v1.2

1. Upgrade min version of docker api to 1.41
2. Upgrade min version of compose to 1.28
3. Upgrade built compose file version to 3.9
4. Dont use shared ssh connection to prevent failure of deploys in some casess
5. Add validatation of services in Startfile. It closes #46

### Bugs

1. Dont run service up with empty rest of containers. It closes #47
2. Fix various missprints in docs and logic

## Version: 1.1

### New v1.1

1. Add startup server script for Centos 7 to setup ready to deploy node
2. New GIT_BRANCH environment parameter with current git branch
3. Add possibility of using docker registry and building nodes with pushing there
4. Startfile possibility to manage flow of starting service and waiting custom container before going next while `yoda start`

### Changes v1.1

1. Minimum version of docker 17.04 or 1.12 for docker-compose
2. Use default network mode host for building. It requires new Docker version 1.13+
3. Display absolute log path where deploy logs is stored on `yoda deploy`
4. New way of upgrading .yodarc files on `yoda upgrade`: it replaces changed lines now on upgrade
5. Remove suffix .0 from container name if its only one container built
6. Links section is now expand from name into all services with its suffixes
7. Generate compose file with version: "2.1"

### Bugs v1.1

1. Fix Issue #37: not a child of this shell
2. Fix `yoda upgrade` bug while it ignore right versions

## Version: 1.0

First release of Yoda.
It supports next commands:

- init
- upgrade
- add
- delete
- compose
- build
- start
- stop
- status
- deploy
- version
- help
