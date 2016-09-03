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

There are templates for each target type in the install-targets directory.

Inside targets, the `GOODIES_DIR` variable specifies the goodies directory. This is set to `goodies` by default, but can be specified using `-g`.

## Command-line usage
```
install [-h]
install [-g goodies-dir] [-d target-dir] [-l|-p] [-t target-file] [target1 [target2 ... ]]
```
```
Options:
    -h                print this help message
    -g goodies-dir    set the directory where the goodies are located. Targets will receive this through the GOODIES_DIR variable. Default: goodies
    -d target-dir     set the directory where the targets are located. Default: install-targets
    -l                only list available targets, do not run them
    -p                print information about each target. Implies -l
    -t                explicitly consider a target, even if the file doesn't have the "target" extension or the target specifies the disabled flag
    -v                print all actions taken
```
