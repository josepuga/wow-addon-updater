#!/usr/bin/env bash

if [ "$#" -eq 0 ]; then
    cat << EOF 
This script uses BigWigs Packager to publish the indicated addon.
USAGE: ${0##*/} AddonName
Addon Name must be the same as directory name. 
Set the addons_path variable to your addon path
Set the api_keys_file to your secrets api key file

EOF
    exit 1
fi
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
cd -- "$script_dir" || { >&2 echo "Unable to enter directory $script_dir"; exit 1; }

set -eou pipefail

source "$script_dir/configuration"


[[ -d "$addons_path" ]] || { >&2 echo "Addons directory not found"; exit 1; }
addon_name="$1"
addon_path="$addons_path/$addon_name"
[[ -d "$addon_path" ]] || { >&2 echo "Addon $addon_name directory not found"; exit 1; }
toc_file="$addons_path/$addon_name/$addon_name.toc"
[[ -f "$toc_file" ]] || { >&2 echo "TOC File $toc_file does not exists"; exit 1; }



# Check TOC version against the latest Git tag
version=$(grep '^## Version:' "$toc_file" | cut -d: -f2)
version="${version// /}"

if ! git_tag=$(git -C "$addon_path" describe --tags --abbrev=0); then
    >&2 echo "ERROR: Unable to determine Git tag for $addon_name"
    exit 1
fi

git_version="${git_tag#v}"

[[ "$version" == "$git_version" ]] || {
    >&2 echo "ERROR: TOC version ($version) differs from Git tag ($git_tag)"
    exit 1
}

# Ensure HEAD points to the tagged commit
if [[ "$(git -C "$addon_path" rev-parse HEAD)" != \
      "$(git -C "$addon_path" rev-parse "${git_tag}^{commit}")" ]]; then
    >&2 echo "ERROR: HEAD does not match Git tag $git_tag"
    exit 1
fi

# Ensure working tree is clean
if [[ -n "$(git -C "$addon_path" status --porcelain)" ]]; then
    >&2 echo "ERROR: Uncommitted changes found in $addon_name"
    exit 1
fi


## BigWigs

# Load API keys
[[ -f "$api_keys_file" ]] || {
    >&2 echo "ERROR: API keys file not found: $api_keys_file"
    exit 1
}

set -a
source "$api_keys_file"
set +a

# -d => Skip uploading
# -r => Destination directory
# -t => Target Directory
if ! "$script_dir/release.sh" \
    -t "$addon_path" \
    -r "$script_dir/releases"
then
    >&2 echo "ERROR: Failed to package $addon_name"
    exit 1
fi
#TODO: DELETE DIRECTORY AND ZIP
