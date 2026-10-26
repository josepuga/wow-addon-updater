#!/usr/bin/env bash

# Get the last versions of differents wow clients
# By José Puga 2026. Under MIT license.

API_URL="https://blizztrack.com/api/manifest/%s/versions"
declare -a CLIENTS=(
    wow                 # Retail
    wow_classic         # Mist of Pandarian
    wow_classic_era     # Classic
    wow_anniversary     # TBC
    wowf                # Forever
)

# Dependencies
deps=(curl jq)

# Check dependencies
deps_error=false
for n in "${deps[@]}"; do
    if ! command -v "$n" &>/dev/null; then
        echo "$n not installed." >&2
        deps_error=true
    fi
done
[[ $deps_error == true ]] && exit 1

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
cd -- "$script_dir" || { >&2 echo "Unable to enter directory $script_dir"; exit 1; }
set -eou pipefail

source "$script_dir/configuration"

[[ -n "$csv_file" ]] || { >&2 echo "CSV output file not set in configuration"; exit 1; }

# Converts WoW Client version to "internal" version
# i.e: 12.1.0.69933 -> 120100
sanitize_version() {
    local major minor patch build

    IFS='.' read -r major minor patch build <<< "$1"

    printf '%d%02d%02d' "$major" "$minor" "$patch"
}


: > "$csv_file"
for k in "${CLIENTS[@]}"; do 
    url=""
    printf -v url "$API_URL" "$k"
    if new_version=$(curl -fsS "$url" --connect-timeout 10 --max-time 30 | \
        jq -er '.result.data[] | select(.region == "eu") | .version_name'); then
        echo "$k,$(sanitize_version "$new_version"),$new_version" | tee -a "$csv_file"
    else
        >&2 echo "Error getting $k @ $url"
        echo "$k,ERROR,ERROR" | tee -a "$csv_file"
    fi
done
