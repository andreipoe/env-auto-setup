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

### `place-files`

| Argument | Description |
|:--------:|:-----------:|
| `#TARGET overwrite` | Replace existing files |
| `#TARGET append` | Append to existing files or merge directories (replaces exisiting files inside directories) |
| `#TARGET backup` | Create a backup before overwriting or appending (ignored if neither append nor overwrite are specified) |
