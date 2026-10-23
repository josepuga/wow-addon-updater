#!/usr/bin/env bash

if [ "$#" -eq 0 ]; then
    echo "USAGE: ${0##*/} AddonName1 [[AddonName2...] [AddonNameN...]]"
    exit 1
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
cd -- "$script_dir" || { >&2 echo "Unable to enter directory $script_dir"; exit 1; }

set -euo pipefail

./1-get-versions.sh
while (( "$#" )); do
    if ./2-update-addon.sh "$1"; then
        ./3-github.sh "$1"
        ./4-bigwigs.sh "$1"
    else
        status=$?
        if (( status == 3 )); then
            echo "Skipping $1: no Interface changes."
        else
            >&2 echo "ERROR: Failed to update $1"
            exit "$status"
        fi
    fi
    shift
done
