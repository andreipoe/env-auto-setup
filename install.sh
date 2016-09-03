#!/bin/bash

function print_help() {
    cat << EOF
Usage: install [-h]
       install [-g goodies-dir] [-d target-dir] [-l|-p] [-t target-file] [target1 [target2 ... ]]

Options:
    -h                 print this help message
    -g goodies-dir    set the directory where the goodies are located. Targets will receive this through the GOODIES_DIR variable. Default: goodies
    -d target-dir     set the directory where the targets are located. Default: install-targets
    -l                only list available targets, do not run them
    -p                print information about each target. Implies -l
    -t                explicitly consider a target, even if the file doesn't have the "target" extension or the target specifies the disabled flag

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
            install="sudo apt-get install"
            # [ "$verbose" != "yes" ] && install="$install -y" # TODO: debugging
        fi
    fi

    if [ -z "$install" ]; then
        echo "${FUNCNAME[0]}: no known package manager found." >&2
        return 2
    fi

    # update_pkg_list TODO: debugging

    # Install the requested packages
    local cmd="$install $packages"
    [ "$verbose" != "yes" ] && cmd="$cmd >/dev/null"

    while read -r pkgs; do
        echo "$cmd $pkgs" # TODO: Debuggign
    done < <(grep -v '^#' "$file")
}

# ------------------------

target_dir="install-targets/"
goodies_dir="goodies/"
show_help="no"
list="no"
print_info="no"
verbose="no"

target_files=()
updated_pkg_list="no"

# TODO: add -a flag
while getopts ":hlpvd:g:t:" opt; do
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

# Get the targets in the target directory
# TODO: only do this for -a; by default, use the targets specified by the user
# TODO: maybe change -t to -f
# TODO: handle disabled targets
for target_file in "$target_dir"/*.target ; do
    cleaned_target_file=$(readlink -m "$target_file")
    if grep -q -e "^#TARGET" "$cleaned_target_file"; then
        target_files+=("$cleaned_target_file")
    else
        echo "Skipping target file $cleaned_target_file: no target information found." >&2
    fi
done

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

# Process targets
[ "$verbose" == "yes" ] && echo_cmd="echo" || echo_cmd="echo -n"

for target_file in ${target_files[@]}; do
    name=$(grep "^#TARGET name" "$target_file" | sed 's/^#TARGET name //')
    type=$(grep "^#TARGET type" "$target_file" | sed 's/^#TARGET type //')
    [ -z "$type" ] && type="script"

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
            pkg-install "$target_file"
            ;;
    esac

    if [ "$?" == 0 -a "$verbose" != "yes" ]; then
        echo "Done"
    fi
done
