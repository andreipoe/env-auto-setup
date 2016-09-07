#!/bin/bash

# ------------------------
# utils

function print_help() {
    cat << EOF
Usage: install [-h]
       install [-s] [-v] [-g goodies-dir] [-d target-dir] [-l|-p] [-t target-file] [target1 [target2 ... ]]

Options:
    -h                 print this help message
    -g goodies-dir    set the directory where the goodies are located. Targets will receive this through the GOODIES_DIR variable. Default: goodies
    -d target-dir     set the directory where the targets are located. Default: install-targets
    -l                only list available targets, do not run them
    -p                print information about each target. Implies -l
    -t                explicitly include a target file, even if the file doesn't have the "target" extension
    -f                force running of targets even if they have the disabled flag
    -v                print all actions taken
    -s                only echo commands, do not execute them. This is meant for testing only

EOF

}

# Find the available package manager
function find_pkg_manager () {
    if [ -z "$install" ]; then
        if hash apt-get 2>/dev/null; then
            install="sudo apt-get install -y"
        fi
    fi
}

function update_pkg_list () {
    [ "$updated_pkg_list" == "yes" ] && return

    find_pkg_manager

    if [ -z "$install" ]; then
        echo "${FUNCNAME[1]}: no known package manager found." >&2
        return 2
    fi

    if [ "$verbose" == "yes" ]; then
        echo "Updating package repositories."
    fi

    # Find the available package manager
    if hash apt-get 2>/dev/null; then
        local update="sudo apt-get update"
        [ "$verbose" != "yes" ] && update="$update >/dev/null"
    fi

    [ "$verbose" == "yes" ] && echo "$update"
    if [ "$simulate" == "yes" ]; then
        echo "$simtag: $update"
    else
        eval $update
    fi
    [ "$?" == 0 ] && updated_pkg_list="yes"
}

function call_pkg_installer () {
    local packages="$@"

    find_pkg_manager

    if [ -z "$install" ]; then
        echo "${FUNCNAME[1]}: no known package manager found." >&2
        return 2
    fi

    # Install the requested packages
    local cmd="$install"
    [ "$verbose" != "yes" ] && cmd="$cmd >/dev/null"

    if [ -n "$packages" ]; then
        [ "$verbose" == "yes" ] && echo "$cmd $packages"
        if [ "$simulate" == "yes" ]; then
            echo "$simtag: $cmd $pkgs"
        else
            eval "$cmd $packages"
        fi
    fi
}

# end utils
# ------------------------
# target types

function pkg-install () {
    local file="$1"
    shift
    local args=("${@}")

    if [ -z "$file" ]; then
        echo "${FUNCNAME[0]}: no file specified." >&2
        return 1
    fi

    # Target type pkg-install takes no arguments
    for arg in "${args[@]}"; do
        case "$arg" in
            "")
                ;; # Skip empty args
            *)
                echo "${FUNCNAME[0]}: ignoriong unknown argument $arg"
                ;;
        esac
    done

    find_pkg_manager
    update_pkg_list

    if [ -z "$install" ]; then
        echo "${FUNCNAME[0]}: no known package manager found." >&2
        return 2
    fi



    while read -r pkgs; do
        [ -n "$pkgs" ] && call_pkg_installer "$pkgs"
    done < <(grep -v '^#' "$file")
}

function script () {
    local file="$1"
    shift
    local args=("${@}")

    # Target type script takes no arguments
    for arg in "${args[@]}"; do
        case "$arg" in
            "")
                ;; # Skip empty args
            *)
                if [ "$arg" == "${args[0]}" ] && hash "$arg" 2>/dev/null; then
                    # TODO: This is a workaround to avoid "ignoring unknow argument python"-type messages. It's not great, but it works for now.
                    [ "$verbose" == "yes" ] && echo "Found interpreter argument: $arg"
                else
                    echo "${FUNCNAME[0]}: ignoriong unknown argument $arg"
                fi
                ;;
        esac
    done

    local first_line=$(head -1 "$file")

    # If the script has a shebang, respect it
    if grep -q "^#!" <<<"$first_line"; then
        local shebang=$(echo "$first_line" | sed 's/^#!//')
        local cmd="$shebang"
    elif hash "$1" 2>/dev/null; then  # Otherwise check if an interpreter has been passed as the first argument
        cmd="$1"
    else # otherwise pass it to bash
        local cmd="bash"
    fi

    cmd="$cmd $file"
    [ "$verbose" != "yes" ] && cmd="$cmd >/dev/null"

    if [ "$simulate" == "yes" ]; then
        echo "$simtag: GOODIES_DIR=$goodies_dir $cmd"
    else
        GOODIES_DIR="$goodies_dir" eval "$cmd"
    fi
}

function place-files () {
    local file="$1"
    shift
    local args=("${@}")

    # Read the type-specific options
    local overwrite=no
    local append=no
    local backup=no

    for arg in "${args[@]}"; do
        case "$arg" in
            overwrite)
                overwrite=yes
                ;;
            append)
                append=yes
                ;;
            backup)
                backup=yes
                ;;
            "")
                ;; # Skip empty args
            *)
                echo "${FUNCNAME[0]}: ignoriong unknown argument $arg"
                ;;
        esac
    done

    # Don't make a backup if neither appending nor overwriting
    if [ "$overwrite" != "yes" -a "$append" != "yes" -a "$backup" == "yes" ]; then
        echo "Ignoring #TARGET backup: neither overwrite nor append specified." >&2
        backup=no
    fi

    while IFS='>' read -ra parts; do
        [ -z "${parts[*]}" ] && continue # Skip empty lines
        if [ "${#parts[*]}" != 2 ]; then
            echo -n "Skipping improprely formatted line: ${parts[0]} " >&2
            for p in ${parts[@]:1}; do
                echo -n "> $p " >&2
            done
            echo >&2
            continue
        fi

        # Parse the source
        local source=$(echo ${parts[0]} | xargs) # Remove leading and trailing whitespace
        [[ "$source" == /* ]] && source=$(readlink -m "$source") || source=$(readlink -m "$goodies_dir/$source") # Convert to full path

        if [ ! -e "$source" ]; then
            echo "Cannot find source file: $source." >&2
            continue
        fi

        # Parse the destination
        local dest=$(echo ${parts[1]} | xargs) # Remove leading and trailing whitespace
        [[ "$dest" == /* ]] && dest=$(readlink -m "$dest") || dest=$(readlink -m "$HOME/$dest") # Convert to full path

        # Prepare the operations
        local cmd=""
        if [ -e "$dest" ]; then
            if [ "$overwrite" == "yes" ]; then
                [ "$backup" == "yes" ] && cmd="mv $dest $dest.bak && "
                cmd="$cmd cp -a $source $dest"
            elif [ "$append" == "yes" ]; then
                [ "$backup" == "yes" ] && cmd="cp -a $dest $dest.bak && "
                if [ -f "$source" -a -f "$dest" ]; then
                    cmd="$cmd cat $source >> $dest"
                else
                    cmd="$cmd cp -a $source $dest"
                fi
            else
                echo -n "Destination file already exists: $dest. " >&2
                echo "Use #TARGET overwrite or append if this is intended." >&2
                continue
            fi
        else
            cmd="$cmd cp -a $source $dest"
        fi

        # Copy the files
        [ "$verbose" == "yes" ] && echo "$cmd"
        eval "$cmd"

    done < <(grep -v '^#' "$file")
}

function batch () {
    local file="$1"
    shift
    local args=("${@}")

    while IFS=':' read -ra parts; do
        [ -z "${parts[*]}" ] && continue # Skip empty lines
        if [ "${#parts[*]}" != 2 ]; then
            echo "Skipping improprely formatted line: \"${parts[*]}\"" >&2
            continue
        fi

        # Figure out the instruction type and arguments
        local type=$(echo ${parts[0]} | cut -d ',' -f1)
        local instr_args=$(echo ${parts[0]} | cut -d ',' -s --complement -f1 | tr ',' ' ')

        # Run the instruction
        case "$type" in
            pkg-install)
                call_pkg_installer "${parts[1]}"
                ;;
            script)
                [[ "${parts[1]}" == /* ]] && local script_file=$(readlink -m "${parts[1]}") || local script_file=$(readlink -m "$goodies_dir/${parts[1]}") # Convert to full path
                script "$script_file" "${instr_args[@]}"
                ;;
            place-files)
                # TODO: This is a hack because I think refactoring place-files would lead to even worse and more wet code. It's not ideal and should be replaced with something more clever
                # Create a temp file and feed it to place-files
                local tmpfile="/tmp/env-auto-setup_batch-place-files"
                echo "${parts[1]}" > "$tmpfile"
                eval "$type $tmpfile ${instr_args[@]}"
                rm "$tmpfile"
                ;;
            batch)
                echo "Skipping instruction \"${parts[1]}\": recursive batch actions are not supported" >&2
                ;;
            *)
                echo "Skipping instruction \"${parts[1]}\": unknown type $type" >&2
                ;;
        esac

    done < <(grep -v '^#' "$file")
}

# end target types
# ------------------------
# main

target_dir="install-targets/"
goodies_dir="goodies/"
show_help="no"
list="no"
print_info="no"
verbose="no"
all="no"
force_disabled="no"

simulate="no"
simtag="simulated"

target_files=()
selected_target_files=()
manual_targets=()
updated_pkg_list="no"

while getopts ":hlpvafsd:g:t:" opt; do
    case $opt in
        l)
            list=yes
            ;;
        p)
            list=yes
            print_info=yes
            ;;
        h)
            show_help=yes
            ;;
        v)
            verbose=yes
            ;;
        a)
            all=yes
            ;;
        f)
            force_disabled=yes
            ;;
        s)
            simulate=yes
            echo "This is only a simulation. Your system will not be modified."
            ;;
        d)
            target_dir="$OPTARG"
            echo "Target directory: $target_dir"
            ;;
        g)
            goodies_dir="$OPTARG"
            echo "Goodies directory: $goodies_dir"
            ;;
        t)
            file=$(readlink -m "$OPTARG")
            if [ -f "$file" ]; then
                target_files+=("$file")
                name=$(grep "#TARGET name" "$file" | sed 's/#TARGET name //')
                manual_targets+=("$name")
            else
                echo "Ignoring target $OPTARG: file does not exist." >&2
            fi
            ;;
        \?)
            echo "Invalid option: -$OPTARG. Use -h for help." >&2
            exit 1
            ;;
        :)
            echo "Option -$OPTARG requires an argument. Use -h for help." >&2
            exit 1
            ;;
    esac
done

if [ "$show_help" == "yes" ]; then
    print_help
    exit 0
fi

echo "Targets directory: $target_dir"
echo "Goodies directory: $goodies_dir"
echo

# Get the available targets in the target directory
for target_file in "$target_dir"/*.target ; do
    cleaned_target_file=$(readlink -m "$target_file")
    if grep -q -e "^#TARGET" "$cleaned_target_file"; then
        target_files+=("$cleaned_target_file")
    else
        echo "Skipping target file $cleaned_target_file: no target information found." >&2
    fi
done
shift "$((OPTIND-1))"

# Select the reuqested targets
found_targets=()
for target_file in ${target_files[@]}; do
    name=$(grep "#TARGET name" "$target_file" | sed 's/#TARGET name //')
    found=no
    if [ "$all" == "yes" ]; then
        found=yes
        selected_target_files+=("$target_file")
    else
        for target in "$@" "${manual_targets[@]}"; do
            if [ "$name" == "$target" ]; then
                selected_target_files+=("$target_file")
                found=yes
                found_targets+=("$name")
                break
            fi
        done
    fi

    [ "$found" == "yes" ] && echo "Selected target: $name"
done

# Report unavailable targets
if [ "$all" != "yes" ]; then
    for target in $@; do
        [[ ! " ${found_targets[@]} " =~ " $target " ]] && echo "Could not find target $target" >&2
    done
fi

# Print target info if requested with -l or -p
if [ "$list" == "yes" ]; then
    [ "$print_info" == "yes" ] && echo_cmd="echo" || echo_cmd="echo -n"

    $echo_cmd "Available targets: "
    for target_file in ${target_files[@]}; do
        name=$(grep "#TARGET name" "$target_file" | sed 's/#TARGET name //')

        if [ "$print_info" == "yes" ]; then
            echo "$name"
            grep -e '^#TARGET' "$target_file" | sed 's/^#TARGET /    /'
        else
            if grep -q -e "^#TARGET disabled" "$target_file"; then
                echo -n "$name[disabled] "
            else
                echo -n "$name "
            fi
        fi
    done

    if [ "$print_info" != "yes" ]; then
        echo -e "\n\nUse -p to print information about each target."
    fi

    exit 0
fi

# Check there are selected targets
if [ "${#selected_target_files[*]}" == 0 ]; then
    echo "No target specified. Use -h for help and -l to print available targets."
    exit 0
fi

echo

# Process targets
[ "$verbose" == "yes" ] && echo_cmd="echo" || echo_cmd="echo -n"

for target_file in ${selected_target_files[@]}; do
    name=$(grep "^#TARGET name" "$target_file" | sed 's/^#TARGET name //')
    type=$(grep "^#TARGET type" "$target_file" | sed 's/^#TARGET type //')
    args=$(grep "^#TARGET " "$target_file" | grep -Ev "^#TARGET name|^#TARGET type" | sed 's/^#TARGET //' | tr '\n' ' ')
    [ -z "$type" ] && type="script"

    # Don't run disabled targets, unless forcing with -f
    if [[ ${args[*]} =~ "disabled" ]]; then
        if [ "$force_disabled" != "yes" ]; then
            echo "Skipping target $name: target is disabled"
            continue
        else
            echo "Forced running diasbled target $name"
        fi
    fi

    # Run recognised target types
    case "$type" in
        script|pkg-install|place-files|batch)
            echo "------------------------------"
            echo "Running $type target $name... "
            ;;
        *)
            echo "Skipping target $name: unkown type $type." >&2
            continue
            ;;
    esac

    eval "$type $target_file ${args[@]}"
done

# end main
# ------------------------
