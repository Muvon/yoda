# Yoda change log

## Version 1.3

*Coming soon*
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

3. Something else

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
3. Upgrade builded compose file version to 3.9
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
