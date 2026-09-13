#!/usr/bin/env bash
# Installs the Tedim (Chin) Bible bundles into ProPresenter 7 on macOS.
#
# ProPresenter stores each Bible on macOS as a .rvbible file (a zip of a bundle)
# under RVBibles/v2, which is the same format its own Bible downloads use. This
# script builds those packages and copies them in, so ProPresenter registers
# them itself — there is no preference file to edit, unlike on Windows.
#
# It needs nothing beyond what macOS already has: no Python, no Xcode command
# line tools.
#
# Quit ProPresenter first. If the destination needs administrator rights, the
# script re-runs the copy with sudo and macOS will ask for your password.
#
# Usage:
#   tools/install-macos.sh [bibles-folder]
#   DRY_RUN=1 tools/install-macos.sh      # show what would happen, change nothing

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dry_run="${DRY_RUN:-}"

system_dest="/Library/Application Support/RenewedVision/RVBibles/v2"
user_dest="$HOME/Library/Application Support/RenewedVision/RVBibles/v2"

# An explicit argument wins. Otherwise prefer whichever folder already exists,
# since some installs keep Bibles per-user rather than system-wide.
if [ $# -ge 1 ]; then
    dest="$1"
elif [ -d "$system_dest" ]; then
    dest="$system_dest"
elif [ -d "$user_dest" ]; then
    dest="$user_dest"
else
    dest="$system_dest"
    echo "Note: no existing Bibles folder found; using $dest"
fi

if pgrep -x ProPresenter >/dev/null 2>&1; then
    echo "ProPresenter is running. Quit it first, then run this script again." >&2
    exit 1
fi

# Copy with sudo only where the destination actually needs it.
run_write() {
    if [ -n "$dry_run" ]; then
        echo "  would run: $*"
    elif [ -w "$(dirname "$dest")" ] || [ -w "$dest" ]; then
        "$@"
    else
        sudo "$@"
    fi
}

# Built with /usr/bin/zip, which every Mac has, rather than the Python script
# in tools/ — installing Bibles should not require the Xcode command line tools.
echo "Building .rvbible packages..."
mkdir -p "$repo_root/dist"

shopt -s nullglob
packages=()
for bundle in "$repo_root"/bibles/*/; do
    uuid="$(basename "$bundle")"
    # Read the abbreviation out of rvmetadata.xml to name the package.
    abbr="$(sed -n 's:.*<abbreviation>\(.*\)</abbreviation>.*:\1:p' \
        "$bundle/rvmetadata.xml" | head -1)"
    if [ -z "$abbr" ]; then
        echo "Skipping $uuid: no abbreviation in rvmetadata.xml" >&2
        continue
    fi
    package="$repo_root/dist/$abbr.rvbible"
    rm -f "$package"
    # A .rvbible is a zip of the bundle's *contents*, so zip from inside it.
    # USX_1 is the legacy folder and is left out; .DS_Store would confuse nothing
    # but bloats the package.
    (cd "$bundle" && zip -q -r -X "$package" . -x 'USX_1/*' '*.DS_Store')
    echo "  built $abbr.rvbible"
    packages+=("$package")
done

if [ ${#packages[@]} -eq 0 ]; then
    echo "No .rvbible packages were built." >&2
    exit 1
fi

echo
echo "Installing into: $dest"
run_write mkdir -p "$dest"

for package in "${packages[@]}"; do
    name="$(basename "$package")"
    if [ -e "$dest/$name" ]; then
        echo "Replacing existing $name"
    fi
    run_write cp "$package" "$dest/$name"
    [ -n "$dry_run" ] || echo "Installed $name"
done

if [ -n "$dry_run" ]; then
    echo
    echo "Dry run - nothing was written."
    exit 0
fi

echo
echo "Done. Start ProPresenter and open the Bible view."
echo "If a translation does not show up, restart ProPresenter once more."
