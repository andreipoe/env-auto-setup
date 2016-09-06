# Targets

This folder contains templates for each target type. Each template has information for its specific target type as a comment inside the file.

The following rules apply across all target types:
  * Each target must at least include a target name.
  * If a target type is not specified, `script` is assumed.
  * Do not use the same name for multiple targets.
  * Any target can be disabled using `#TARGET disabled`, and `disabled` targets can be force-executed using the `-f` option.
  * By default, only files with the `target` extension are included by the installer script, but any file can be included using the `-t` option.
  * Lines starting with `#` (except `#TARGET` lines) are ignored in all targets.

## Type-specific arguments

### `pkg-install`

No specific arguments.

### `script`

No specific arguments.

### `place-files`

| Argument | Description |
|:--------:|:-----------:|
| `#TARGET overwrite` | Replace existing files |
| `#TARGET append` | Append to existing files or merge directories (replaces exisiting files inside directories) |
| `#TARGET backup` | Create a backup before overwriting or appending (ignored if neither append nor overwrite are specified) |

## `batch` targets

A `batch` target allows packaging together a series of _actions_. Each action is an _instruction_ for a (non-`batch`) target. The generic synatx for an action is `type[,arguments]:instruction`, where:
  * `type` is any target type apart from `batch`.
  * `argumets` are type-specific parameters. In a dedicated target, these would be specified as `#TARGET arguments`.
    * In `script` actions, the interpreter can be specified as a parameter, e.g. `script,python:script.py`, so that it's used if the script doesn't have a shebang. There is currently no equivalent `#TARGET` option for this.
  * `instruction` is a (single) type-specific target line.

For example, a `batch` target to install `vim`, copy `.vimrc` in place and download plugins could look like this:

```
#TARGET name setup-vim
#TARGET type batch

pkg-install:vim
place-files,overwrite,backup:vimrc > .vimrc
script:get-vim-plugins.sh
```

The same rules apply to instructions as to targets of their dedicated type. In particular, note that
  * All packages in a `pkg-install` instruction are sent to the package manager in one command, so the whole request might fail if even one package cannot be found.
  * Relative paths in `script` instructions are start in the goodies directory.
  * Relative paths in `place-files` instructions start in the goodies directory for the source and in the user's home directory for the destination.
