#!/usr/bin/env bash

# Commit and push a WoW addon's updated Interface version.
# By José Puga 2026. Under MIT license.

if [[ "$#" -ne 1 ]]; then
    cat << EOF_HELP
Commit and push an addon's updated Interface version to GitHub.
USAGE: ${0##*/} AddonName
AddonName must match its directory name.
Set addons_path in configuration.
EOF_HELP
    exit 1
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
cd -- "$script_dir" || { >&2 echo "Unable to enter directory $script_dir"; exit 1; }

set -euo pipefail

source "$script_dir/configuration"

[[ -d "$addons_path" ]] || { >&2 echo "ERROR: Addons directory not found: $addons_path"; exit 1; }
addon_name="$1"
addon_path="$addons_path/$addon_name"
toc_file="$addon_path/$addon_name.toc"
[[ -d "$addon_path" ]] || { >&2 echo "ERROR: Addon directory not found: $addon_path"; exit 1; }
[[ -f "$toc_file" ]] || { >&2 echo "ERROR: TOC file not found: $toc_file"; exit 1; }

version=$(sed -n 's/^## Version:[[:space:]]*//p' "$toc_file")
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { >&2 echo "ERROR: Invalid or missing TOC version: $version"; exit 1; }

# Work in the addon's repository without changing the script's working directory.
(
    cd -- "$addon_path"

    git rev-parse --is-inside-work-tree >/dev/null || { >&2 echo "ERROR: Not a Git repository: $addon_path"; exit 1; }
    [[ "$(git branch --show-current)" == main ]] || { >&2 echo "ERROR: Current branch must be main"; exit 1; }

    git_tag=$(git describe --tags --abbrev=0) || { >&2 echo "ERROR: No reachable local Git tag for $addon_name"; exit 1; }
    [[ "$git_tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || { >&2 echo "ERROR: Invalid Git tag: $git_tag"; exit 1; }

    local_commit=$(git rev-parse --verify "${git_tag}^{commit}") || { >&2 echo "ERROR: Cannot resolve local tag $git_tag"; exit 1; }
    remote_refs=$(git ls-remote --tags origin "refs/tags/$git_tag" "refs/tags/$git_tag^{}") || { >&2 echo "ERROR: Cannot query origin tags"; exit 1; }
    remote_commit=$(printf '%s\n' "$remote_refs" | awk -F '\t' '
        $2 ~ /\^\{\}$/ { peeled=$1 }
        $2 !~ /\^\{\}$/ { direct=$1 }
        END { print (peeled != "" ? peeled : direct) }
    ')
    [[ -n "$remote_commit" && "$local_commit" == "$remote_commit" ]] || {
        >&2 echo "ERROR: Local and remote tag $git_tag differ or remote tag is missing"
        exit 1
    }

    git_version="${git_tag#v}"
    if [[ "$version" == "$git_version" ]]; then
        if [[ -n "$(git status --porcelain)" ]]; then
            >&2 echo "ERROR: Uncommitted changes with already tagged version $version"
            exit 1
        fi
        if [[ "$(git rev-parse HEAD)" != "$local_commit" ]]; then
            >&2 echo "ERROR: HEAD does not match Git tag $git_tag"
            exit 1
        fi
        echo "Version $version already tagged. No changes to publish."
        exit 0
    fi
    if ! printf '%s\n' "$git_version" "$version" | sort -VC; then
        >&2 echo "ERROR: TOC version $version is older than Git tag $git_tag"
        exit 1
    fi

    # Refuse to create a tag that already exists locally or remotely.
    if git rev-parse --verify --quiet "refs/tags/v$version" >/dev/null; then
        >&2 echo "ERROR: Local tag v$version already exists"
        exit 1
    fi
    remote_new_tag=$(git ls-remote --tags --refs origin "refs/tags/v$version") || {
        >&2 echo "ERROR: Cannot check remote tag v$version"
        exit 1
    }
    [[ -z "$remote_new_tag" ]] || { >&2 echo "ERROR: Remote tag v$version already exists"; exit 1; }

    # The new version must include the changelog entry.
    grep -Fqx -- "### $version" CHANGELOG.md || {
        >&2 echo "ERROR: CHANGELOG.md has no entry for $version"
        exit 1
    }

    echo "New version: $git_version -> $version. Committing to GitHub..."
    git add . || { >&2 echo "ERROR: git add failed"; exit 1; }
    git commit -m "Updated Interface version $version" || { >&2 echo "ERROR: git commit failed"; exit 1; }
    git tag "v$version" || { >&2 echo "ERROR: git tag failed"; exit 1; }
    git push origin main "refs/tags/v$version" || { >&2 echo "ERROR: git push failed"; exit 1; }
)
