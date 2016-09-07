# env-auto-setup

A simple tool to quickly set up a linux environment with packages and cofiguration files.

## Description
The `install` script uses _targets_. By default, target files are in the `install-targets` directory and have the `target` extension.

Each target can to specify its parameters using `#TARGET` lines. At the very least, each target specify a name before any other contents (but possibly after a shebang). If a target does not specify a type, it is assumed to be `script`.

The currently supported parameters are:

| Parameter                                   | Description |
|:-------------------------------------------:|:-------------:|
| `#TARGET name <target_name>`                  | Specifies the target's name |
| `#TARGET type script|pkg-install|place-files` | Specifies the target's type |
| `#TARGET disabled`                            | Disables the target, preventing it from running unless manualy passed with `-t` |

The types are used as follows:

| Type                                    | Description |
|:---------------------------------------:|:-------------:|
| `script`      | For executable scripts. Note these will be executed as-is, so make sure you have execute permission on them. |
| `pkg-install` | For list of packages that should be installed using the distribution's default package manager. Only apt-get is supported for now. |
| `place-files` | For copying files to specified locations. |
| `batch`       | For running a series of other targets in one go. |

There are templates for each target type in the install-targets directory.

The goodies directory is set to `goodies` by default, but can be specified using `-g`. Inside `script` targets, the `GOODIES_DIR` variable specifies the goodies directory. `place-file` targets use paths relative to the goodies directory to copy files (see the template for more info).

## Command-line usage
```
install [-h]
install [-s] [-v] [-g goodies-dir] [-d target-dir] [-l|-p] [-t target-file] [-f] [target1 [target2 ... ]]
```
```
Options:
    -h                print this help message
    -g goodies-dir    set the directory where the goodies are located. Targets will receive this through the GOODIES_DIR variable. Default: goodies
    -d target-dir     set the directory where the targets are located. Default: install-targets
    -l                only list available targets, do not run them
    -p                print information about each target. Implies -l
    -t                explicitly include a target file, even if the file doesn't have the "target" extension
    -f                force running of targets even if they have the disabled flag
    -v                print all actions taken
    -s                only echo commands, do not execute them. This is meant for testing only
```
