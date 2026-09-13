#!/usr/bin/env bash
# Installs the Tedim (Chin) Bible bundles into ProPresenter 7 on macOS.
#
# Current ProPresenter versions pick up .rvbible packages dropped into the
# Bibles folder, so this script builds them and copies them across. Quit
# ProPresenter first; it may ask for your password, since the destination is
# under /Library.
#
# Usage: tools/install-macos.sh [bibles-folder]

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dest="${1:-/Library/Application Support/RenewedVision/RVBibles/v2}"

if pgrep -x ProPresenter >/dev/null 2>&1; then
    echo "ProPresenter is running. Quit it first, then run this script again." >&2
    exit 1
fi

echo "Building .rvbible packages..."
python3 "$repo_root/tools/build_rvbible.py" >/dev/null

sudo mkdir -p "$dest"

shopt -s nullglob
packages=("$repo_root"/dist/*.rvbible)
if [ ${#packages[@]} -eq 0 ]; then
    echo "No .rvbible packages were built." >&2
    exit 1
fi

for package in "${packages[@]}"; do
    sudo cp "$package" "$dest/"
    echo "Installed $(basename "$package")"
done

echo
echo "Done. Start ProPresenter and open the Bible view."
echo "If a translation does not show up, restart ProPresenter once more."
