#!/usr/bin/env bash

if [ "$#" -eq 0 ]; then
    echo "USAGE: ${0##*/} AddonName1 [[AddonName2...] [AddonNameN...]]"
    exit 1
fi 


script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
cd -- "$script_dir" || { >&2 echo "Unable to enter directory $script_dir"; exit 1; }

set -eou pipefail

./1-get-versions.sh
while (( "$#" )); do
    ./2-update-addon.sh "$1"
    ./3-github.sh "$1"
    ./4-bigwigs.sh "$1"
    shift
done