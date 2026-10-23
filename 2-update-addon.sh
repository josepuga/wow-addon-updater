#!/usr/bin/env bash

# Update the versions of a toc file WoW addon and
# if exists, add change log to CHANGELOG.md
# By José Puga 2026. Under MIT license.


if [ "$#" -ne 1 ]; then
    echo Sets the last client versions to a .toc file of WoW addon.
    echo This script uses the .csv file generated with get-versions.sh
    echo Check configuration before executing
    echo "USAGE: ${0##*/} AddonName"
    exit 1
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
cd -- "$script_dir" || { >&2 echo "Unable to enter directory $script_dir"; exit 1; }

set -euo pipefail

source "$script_dir/configuration"

[[ -n "${csv_file:-}" ]] || { >&2 echo "CSV output file not set"; exit 1; }
[[ -f "$csv_file" ]] || { >&2 echo "CSV file not found"; exit 1; }
[[ -d "$addons_path" ]] || { >&2 echo "Addons directory not found"; exit 1; }

addon_name="$1"
addon_path="$addons_path/$addon_name"
toc_file="$addon_path/$addon_name.toc"
changelog_file="$addon_path/CHANGELOG.md"
[[ -f "$toc_file" ]] || { >&2 echo "TOC File $toc_file does not exist"; exit 1; }

if (( $(date +%s) - $(stat -c %Y "$csv_file") > 7 * 86400 )); then
    >&2 echo "WARNING: CSV older than a week"
fi

# Extracting tags...
tags=$(grep '^## TAG_ORDER:' "$toc_file" | cut -d: -f2) || true
[[ -n "$tags" ]] || { >&2 echo "No '## TAG_ORDER:' in $toc_file"; exit 1; }
read -ra tag_array <<< "$tags"

# Extracting versions (in an indexed array)
# VERSIONS COUNT MUST BE == TAGS COUNT
versions=$(grep '^## Interface:' "$toc_file" | cut -d: -f2) || true
declare -a iface_versions
IFS=',' read -ra iface_versions <<< "$versions"

if (( ${#tag_array[@]} != ${#iface_versions[@]} )); then
    >&2 echo "ERROR: TAG_ORDER and Interface count mismatch"
    exit 1
fi

# Create associative interface arrays and set with versions
# key = tag. value = interface version

# Old (current) values from TOC
declare -A old_interface
i=0
for tag in "${tag_array[@]}"; do
    old_interface["$tag"]="${iface_versions[$i]// /}"
    ((++i))
done

# New values from CSV
declare -A new_interface

# Avoid missing key if CSV fails
for tag in "${!old_interface[@]}"; do
    new_interface["$tag"]="${old_interface[$tag]}"
done

updated=false
while IFS=, read -r tag interface public_version; do
    # Process only Interface versions used in the TOC file. Key exists?
    if [[ -v old_interface["$tag"] ]]; then
        if [[ "$interface" == "ERROR" || -z "$interface" ]]; then
            >&2 echo "Tag $tag marked as ERROR or empty. Ignored"
            new_interface["$tag"]="${old_interface[$tag]}"
        else
            new_interface["$tag"]="$interface"
            # Only if has changed...
            if [[ "$interface" != "${old_interface[$tag]}" ]]; then
                updated=true
            fi
        fi
    fi
done < "$csv_file"

# Show info of current versions
echo "Current versions:"
for k in "${tag_array[@]}"; do
    echo -e "\t$k -> ${old_interface[$k]}"
done

# Show info of new versions
echo -e "\nNew versions:"
for k in "${tag_array[@]}"; do
    echo -e "\t$k -> ${new_interface[$k]}"
done

# No changes... exit! Return 3 so the master script skips publishing.
if [[ "$updated" == false ]]; then
    echo "No Interface changes. Exiting."
    exit 3
fi

# Check repository before changing any files.
git -C "$addon_path" rev-parse --is-inside-work-tree >/dev/null || {
    >&2 echo "ERROR: Not a Git repository: $addon_path"
    exit 1
}
if [[ -n "$(git -C "$addon_path" status --porcelain)" ]]; then
    >&2 echo "ERROR: Uncommitted changes in $addon_name. Resolve them before updating."
    exit 1
fi

# CHANGELOG.md must exist with some text.
[[ -s "$changelog_file" ]] || {
    >&2 echo "ERROR: CHANGELOG.md not found or empty"
    exit 1
}

# Create the TOC's new lines
# Now, we need to:
#   * Increase the Addon patch version
#   * Update the "## TAG_ORDER" and "## Interface" lines.

# Version patch increase
old_ver=$(sed -n 's/^## Version:[[:space:]]*//p' "$toc_file")
[[ "$old_ver" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
    >&2 echo "ERROR: Invalid TOC version: $old_ver"
    exit 1
}
IFS='.' read -r major minor patch <<< "$old_ver"
((++patch))
new_ver="$major.$minor.$patch"
line_version="## Version: $new_ver"

# Interface versions (keep the same order as TAG_ORDER).
line_tag="## TAG_ORDER:"
line_iface="## Interface:"
for k in "${tag_array[@]}"; do
    v="${new_interface[$k]}"
    line_tag+=" $k"
    line_iface+=" $v,"
done
line_iface="${line_iface%,}" # Remove last ","

# Prepare both files before replacing either one.
tmp_toc=$(mktemp "$addon_path/.${addon_name}.toc.XXXXXX")
tmp_changelog=$(mktemp "$addon_path/.CHANGELOG.md.XXXXXX")
cleanup() {
    rm -f -- "$tmp_toc" "$tmp_changelog"
}
trap cleanup EXIT

sed \
    -e "s/^## Version:.*/$line_version/" \
    -e "s/^## TAG_ORDER:.*/$line_tag/" \
    -e "s/^## Interface:.*/$line_iface/" \
    "$toc_file" > "$tmp_toc"

{
    printf '### %s\n    - Updated Interface version.\n\n' "$new_ver"
    cat "$changelog_file"
} > "$tmp_changelog"

# Validate the prepared files.
[[ "$(sed -n 's/^## Version:[[:space:]]*//p' "$tmp_toc")" == "$new_ver" ]] || {
    >&2 echo "ERROR: Failed to prepare the new TOC version"
    exit 1
}
grep -Fqx -- "$line_iface" "$tmp_toc" || {
    >&2 echo "ERROR: Failed to prepare the new Interface versions"
    exit 1
}
grep -Fqx -- "### $new_ver" "$tmp_changelog" || {
    >&2 echo "ERROR: Failed to prepare CHANGELOG.md"
    exit 1
}

# Keep original files so a failed move can be rolled back.
backup_toc=$(mktemp "$addon_path/.${addon_name}.toc.backup.XXXXXX")
backup_changelog=$(mktemp "$addon_path/.CHANGELOG.md.backup.XXXXXX")
cp -p -- "$toc_file" "$backup_toc"
cp -p -- "$changelog_file" "$backup_changelog"

if ! { cat "$tmp_toc" > "$toc_file" && cat "$tmp_changelog" > "$changelog_file"; }; then
    cp -- "$backup_toc" "$toc_file"
    cp -- "$backup_changelog" "$changelog_file"
    rm -f -- "$backup_toc" "$backup_changelog"
    >&2 echo "ERROR: Unable to write TOC and CHANGELOG.md"
    exit 1
fi
rm -f -- "$backup_toc" "$backup_changelog"
echo -e "\nAddon Updated: $old_ver -> $new_ver"
