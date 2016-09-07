#!/usr/bin/env python3

import random
import re
import subprocess as sp
import os
import sys

base_dir       = os.path.realpath("../")
test_dir       = os.path.realpath("./")
targets_dir    = "install-targets/"
goodies_dir    = "goodies/"
install_script = "install.sh"

install_script_cmd = ["./" + install_script, "-s", "-t"]

TARGET_TYPE_PKG_INSTALL = "pkg-install"
TARGET_TYPE_LIST        = [TARGET_TYPE_PKG_INSTALL]

PKG_INSTALL_MAX_LINES         = 5
PKG_INSTALL_MAX_PKGS_PER_LINE = 5
PKG_INSTALL_CMD_PREFIX        = "sudo apt-get install -y >/dev/null"

words        = []
RE_NON_ALPHA = r"[^a-zA-Z0-9]"

SIMTAG          = "simulated"
TEST_TARGET_EXT = ".testtarget"

# Read a dictionary of words
def get_words():
    global words

    with open("/usr/share/dict/words", 'r') as f:
        words = f.read().splitlines()

def print_error(target, type, expected, found, output=None):
    print("FAIL:", type, "target", target, file=sys.stderr)
    print("Expected:", expected, file=sys.stderr)
    print("Found:", found, file=sys.stderr)

    if output != None:
        print("", file=sys.stderr)
        print("############## Raw output ##############", file=sys.stderr)
        print(output, file=sys.stderr)
        print("############## End raw output ##############", file=sys.stderr)

# Create a target file
def create_test_target(type):
    name      = re.sub(RE_NON_ALPHA, "-", random.choice(words))
    file_name = name + TEST_TARGET_EXT

    if type not in TARGET_TYPE_LIST:
        print("Cannot test unknown target type " + type + ".")
        return None

    with open(file_name, 'w') as f:
        print("#TARGET name " + name, file=f)
        print("#TARGET type " + type, file=f)
        f.write("\n")

        if type == TARGET_TYPE_PKG_INSTALL:
            for lines in range(random.randint(1,PKG_INSTALL_MAX_LINES)):
                for pkg in range(random.randint(1,PKG_INSTALL_MAX_PKGS_PER_LINE)):
                    f.write(re.sub(RE_NON_ALPHA, "-", random.choice(words)) + " ")
                f.write("\n")

    return file_name

# Verify results
def check_output(type, file, output):
    with open(file, 'r') as f:
        if type == TARGET_TYPE_PKG_INSTALL:
            output_lines=output.split("\n")
            i = 0

            try:
                # Find the first output line
                while not output_lines[i].startswith(SIMTAG):
                    i += 1

                expected = SIMTAG + ": sudo apt-get update >/dev/null"
                if output_lines[i].strip() != expected:
                    print_error(file[:-len(TEST_TARGET_EXT)], type, expected, output_lines[i].strip(), output)
                    return False
                i += 1

                # Check them against the target input
                for line in f:
                    if line.startswith('#') or line.strip() == "":
                        continue

                    trimmed_output = output_lines[i].strip()[len(SIMTAG)+2:]
                    expected       = PKG_INSTALL_CMD_PREFIX + " " + line.strip()

                    if trimmed_output != expected:
                        print_error(file[:-len(TEST_TARGET_EXT)], type, expected, trimmed_output, output)
                        return False

                    i += 1
            except IndexError:
                print_error(file[:-len(TEST_TARGET_EXT)], type, "[???]", "[Not enough output]", output)
                return False

    return True

# Initialise
get_words()
all_ok=True

# Run a test for each type
for type in TARGET_TYPE_LIST:
    target = create_test_target(type)
    output = sp.check_output(install_script_cmd + [test_dir+"/"+target], universal_newlines=True, cwd=base_dir)
    ok     = check_output(type, target, output)

    if ok:
        os.remove(target)
    else:
        all_ok = False

if all_ok:
    print("All tests passed.")

# TODO: print errors to a unique file
# TODO: script
# TODO: place-files
# TODO: batch
# TODO: run several tests
# TODO: add a README
