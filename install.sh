#!/bin/bash

function print_help() {
    cat << EOF
Usage: install [-h]
       install [-v] [-g goodies-dir] [-d target-dir] [-l|-p] [-t target-file] [target1 [target2 ... ]]

Options:
    -h                 print this help message
    -g goodies-dir    set the directory where the goodies are located. Targets will receive this through the GOODIES_DIR variable. Default: goodies
    -d target-dir     set the directory where the targets are located. Default: install-targets
    -l                only list available targets, do not run them
    -p                print information about each target. Implies -l
    -t                explicitly include a target file, even if the file doesn't have the "target" extension
    -f                force running of targets even if they have the disabled flag
    -v                print all actions taken

EOF

}

function update_pkg_list () {
    [ "$updated_pkg_list" == "yes" ] && return

    if [ "$verbose" == "yes" ]; then
        echo "Updating package repositories."
    fi

    # Find the available package manager
    if hash apt-get 2>/dev/null; then
        local update="sudo apt-get update"
        [ "$verbose" != "yes" ] && update="$update >/dev/null"
    fi

    [ "$verbose" == "yes" ] && echo "$update"
    eval $update && updated_pkg_list="yes"
}

# ------------------------

function pkg-install () {
    local file="$1"
    if [ -z "$file" ]; then
        echo "${FUNCNAME[0]}: no file specified." >&2
        return 1
    fi

    # Find the available package manager
    if [ -z "$install" ]; then
        if hash apt-get 2>/dev/null; then
            install="sudo apt-get install -y"
        fi
    fi

    if [ -z "$install" ]; then
        echo "${FUNCNAME[0]}: no known package manager found." >&2
        return 2
    fi

    update_pkg_list

    # Install the requested packages
    local cmd="$install $packages"
    [ "$verbose" != "yes" ] && cmd="$cmd >/dev/null"

    while read -r pkgs; do
        if [ -n "$pkgs" ]; then
            [ "$verbose" == "yes" ] && echo "$cmd $pkgs"
            eval "$cmd $pkgs"
        fi
    done < <(grep -v '^#' "$file")
}

function script () {
    local file="$1"
    local first_line=$(head -1 "$file")

    # If the script has a shebang, then respect it, otherwise pass it to bash
    local shebang=$(echo "$first_line" | sed 's/^#!//')
    if [ -n "$shebang" ]; then
        local cmd="$shebang"
    else
        local cmd="bash"
    fi

    cmd="$cmd $file"
    [ "$verbose" != "yes" ] && cmd="$cmd >/dev/null"

    eval "$cmd"
}

# ------------------------

target_dir="install-targets/"
goodies_dir="goodies/"
show_help="no"
list="no"
print_info="no"
verbose="no"
all="no"
force_disabled="no"

target_files=()
selected_target_files=()
updated_pkg_list="no"

while getopts ":hlpvafd:g:t:" opt; do
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
                selected_target_files+=("$file")
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

# Targets specified with -t are selected by default
for target_file in ${selected_target_files[@]}; do
     name=$(grep "#TARGET name" "$target_file" | sed 's/#TARGET name //')
     echo "Selected target: $name"
done

# Select the reuqested targets
found_targets=()
for target_file in ${target_files[@]}; do
    name=$(grep "#TARGET name" "$target_file" | sed 's/#TARGET name //')
    found=no
    if [ "$all" == "yes" ]; then
        found=yes
    else
        for target in $@; do
            if [ "$name" == "$target" ]; then
                selected_target_files+=("$target_file")
                found=yes
                found_targets+=("$name")
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

# Process targets
[ "$verbose" == "yes" ] && echo_cmd="echo" || echo_cmd="echo -n"

for target_file in ${selected_target_files[@]}; do
    name=$(grep "^#TARGET name" "$target_file" | sed 's/^#TARGET name //')
    type=$(grep "^#TARGET type" "$target_file" | sed 's/^#TARGET type //')
    [ -z "$type" ] && type="script"

    if grep -q "^#TARGET disabled" "$target_file"; then
        if [ "$force_disabled" != "yes" ]; then
            echo "Skipping target $name: target is disabled"
            continue
        else
            echo "Forced running diasbled target $name"
        fi
    fi

    case "$type" in
        script|pkg-install|place-files)
            $echo_cmd "Running $type target $name... "
            ;;
        *)
            echo "Skipping target $name: unkown type $type." >&2
            continue
            ;;
    esac

    case "$type" in
        pkg-install)
            # pkg-install "$target_file" # TODO: debugging
            ;;
        script)
            script "$target_file"
            ;;
        # TODO: copy
    esac

    if [ "$?" == 0 -a "$verbose" != "yes" ]; then
        echo "Done"
    fi
done
