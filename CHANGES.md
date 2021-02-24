# Yoda change log

## Version 2.0

**New**
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

**Changes**
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
**New:**
1. Add automatic support of git-secret on deployment
2. Add startup server script for Centos 8 to setup ready to deploy node
3. Add log command to follow output of containers
4. Add --no-cache argument for build command
5. Add possibility to use custom context with Buildfile

**Changes**
1. Upgrade min version of docker api to 1.41
2. Upgrade min version of compose to 1.28
3. Upgrade built compose file version to 3.9
4. Dont use shared ssh connection to prevent failure of deploys in some casess
5. Add validatation of services in Startfile. It closes #46

**Bugs**
1. Dont run service up with empty rest of containers. It closes #47
2. Fix various missprints in docs and logic

## Version: 1.1
**New:**
1. Add startup server script for Centos 7 to setup ready to deploy node
2. New GIT_BRANCH environment parameter with current git branch
3. Add possibility of using docker registry and building nodes with pushing there
4. Startfile possibility to manage flow of starting service and waiting custom container before going next while `yoda start`

**Changes:**
1. Minimum version of docker 17.04 or 1.12 for docker-compose
2. Use default network mode host for building. It requires new Docker version 1.13+
3. Display absolute log path where deploy logs is stored on `yoda deploy`
4. New way of upgrading .yodarc files on `yoda upgrade`: it replaces changed lines now on upgrade
5. Remove suffix .0 from container name if its only one container built
6. Links section is now expand from name into all services with its suffixes
7. Generate compose file with version: "2.1"

**Bugs:**
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
