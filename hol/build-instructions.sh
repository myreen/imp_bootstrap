#!/bin/sh

## Instructions for building Poly/ML, HOL4, and this development.
## Adapted from https://github.com/CakeML/cakeml/blob/master/build-instructions.sh
## Run the commands in order, adjusting installation paths as needed.

set -e
project_hol_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

## Build Poly/ML (requires a C/C++ compiler, Make, and GMP headers/libraries).

cd
git clone https://github.com/polyml/polyml
cd polyml
git checkout 4557554077078decce4ce5f90da00a713cfc32e4 # Poly/ML 5.9.2
./configure --prefix=/usr --enable-intinf-as-int
## --enable-intinf-as-int uses GMP for arbitrary-precision integers.

## On Debian/Ubuntu, use --prefix=/usr or add the following to ~/.profile:
# export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH

## For other installation locations (e.g. /usr/local on macOS), use:
# ./configure --prefix=<dir> --enable-intinf-as-int
## If needed, add the installation's executables to PATH:
# export PATH=<dir>/bin:$PATH

make
make compiler
## Use sudo for this step if the installation directory requires it.
make install

## Build HOL4: Trindemossen-2-v7.
## https://github.com/HOL-Theorem-Prover/HOL/releases/tag/trindemossen-2-v7

cd
git clone https://github.com/HOL-Theorem-Prover/HOL
cd HOL
git checkout e395eb6e69054ff6f7cef9d1107fd1a04dd5848f
poly --script tools/smart-configure.sml
bin/build

## Set HOLDIR and add the HOL4 tools to PATH.
## If running this file as a script, repeat these exports in your shell
## before using the README's Holmake commands.
export HOLDIR="$HOME/HOL"
export PATH="$HOLDIR/bin:$PATH"

## Build this development, including its dependencies.

cd "$project_hol_dir"
"$HOME/HOL/bin/Holmake" -r

## If the HOL4 tools are on PATH, the equivalent command is:
# Holmake -r
