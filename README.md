# WoW Addon Updater

Bash scripts to automate compatibility maintenance for my **World of Warcraft addons** when Blizzard updates its game clients, preventing outdated addon warnings.

## How It Works

**It is recommended to run `0-publish-with-client-update.sh`, which executes the other scripts in sequence.** It checks whether any WoW client versions have changed before proceeding. However, each script can also be run independently:

1. `1-get-versions.sh` retrieves the latest WoW client versions and saves them to a CSV file.
2. `2-update-addon.sh` updates each addon as needed.
3. `3-github.sh` updates the GitHub tag and pushes the addon to its repository.
4. `4-bigwigs.sh` publishes the addons to the different distribution platforms.

## Requirements

- Bash.
- `curl` and `jq` (for `1-get-versions.sh`).
- Configure the variables in `configuration.sh`:
  - The root directory containing your addon development projects.
  - The file containing the API keys used for publishing.
- Add the required `## TAG_ORDER` field to each addon's `.toc` file (only necessary once). See the `2-update-addon.sh` section below.
- API keys for the different publishing platforms.

## 1. `1-get-versions.sh`

Queries the [BlizzTrack](https://blizztrack.com/) API to retrieve the latest versions of the different World of Warcraft clients.

Generates a CSV file at the location specified in `configuration.sh`.

Each CSV line contains three fields:

`CLIENT,INTERFACE,PUBLIC_VERSION`

Example:

```csv
wow,120100,12.1.0.69933
wow_classic,50504,5.5.4.70032
wow_classic_era,11509,1.15.9.70003
wow_anniversary,20506,2.5.6.69795
wow_classic_beta,16001,1.60.1.70245
```

- **CLIENT:** WoW client identifier used by BlizzTrack.
- **INTERFACE:** Interface version number used in WoW addon `.toc` files.
- **PUBLIC_VERSION:** Full client version, including the build number, as commonly found in changelogs, forums, and release notes. For informational purposes only.

If a version cannot be retrieved, `ERROR` is used as its value.

This script only needs to be run when you want to update the WoW client version information.

## 2. `2-update-addon.sh`

Updates an addon's `.toc` file using the versions previously retrieved by `1-get-versions.sh`.

**Usage:**

```bash
./2-update-addon.sh AddonName
```

The script compares the versions stored in the CSV file with those declared in the addon's `.toc` file. It also adds a generic entry to `CHANGELOG.md` if the file exists.

**If changes are detected:**

- Updates `## Interface:` with the latest compatibility versions.
- Increments the **PATCH** component of the addon version (`MAJOR.MINOR.PATCH`) in `## Version:`.
- Preserves existing `Interface` versions when updated information is unavailable.
- Updates `## TAG_ORDER:` to maintain the correct mapping between WoW clients and their `Interface` versions.
- Creates a backup of the original `.toc` file with the `.toc.bak` extension.
- If `CHANGELOG.md` exists, adds a generic "Updated Interface version" entry.

**If no changes are detected**, the `.toc` file remains unchanged.

The script also displays a warning if the CSV file is more than seven days old.

## Required TOC Configuration: `TAG_ORDER`

The `update-toc.sh` script requires an additional metadata field in the addon's `.toc` file:

```toc
## TAG_ORDER: wow wow_classic wow_classic_era wow_anniversary wow_classic_beta
## Interface: 120100, 50504, 11509, 20506, 16001
```

**`TAG_ORDER` is a custom metadata field based on the BlizzTrack API**, not a standard Blizzard directive. It tells the script which WoW client corresponds to each `Interface` version.

The mapping is positional:

| TAG_ORDER | Interface | WoW Client |
|---|---|---|
| `wow` | `120100` | Retail |
| `wow_classic` | `50504` | Progressive Classic |
| `wow_classic_era` | `11509` | Classic Era |
| `wow_anniversary` | `20506` | Anniversary |
| `wow_classic_beta` | `16001` | Classic Beta |

**Important:**

- The number of entries in `TAG_ORDER` must match the number of versions in `## Interface`.
- Both fields must use the same order.
- The order itself is arbitrary, as long as the correspondence between the two fields is preserved.
- Only WoW clients supported by the addon need to be included.

The script automatically updates both fields when necessary, preserving their positional mapping even if the order changes.

Without `## TAG_ORDER`, the script cannot determine which WoW client corresponds to each `Interface` version and will not update the `.toc` file.

## 3. `3-github.sh`

**Usage:**

```bash
./3-github.sh AddonName
```

- Checks that the addon and its `.toc` file exist.
- Validates the `MAJOR.MINOR.PATCH` version format.
- Verifies that the repository is on the `main` branch.
- Requires an existing local Git tag that matches its remote counterpart, supporting both lightweight and annotated tags.
- If the `.toc` version is lower than the Git tag version, exits with an error.
- If both versions match, exits successfully without making any changes.
- If the `.toc` version is higher, runs `git add`, `commit`, `tag`, and `push`.
- If any Git operation fails, exits with an error.

## 4. `4-bigwigs.sh`

**Usage:**

```bash
./4-bigwigs.sh AddonName
```

Uses the `release.sh` script from **BigWigs Packager** to generate the corresponding ZIP files and upload them to the following platforms:

- CurseForge
- WoWInterface
- Wago

The `api_keys_file` variable in `configuration.sh` must contain the path to the file holding the API keys (remember to set its permissions with `chmod 600`).

Example format:

```ini
WAGO_API_TOKEN="YOUR WAGO API KEY"
CF_API_KEY="YOUR CURSEFORGE API KEY"
```

## Important Note

Updating `## Interface` prevents outdated addon warnings, but **does not guarantee compatibility with changes introduced in Blizzard's API**.

Actual compatibility must still be tested.

## License

MIT License.

Copyright (c) 2026 José Puga.