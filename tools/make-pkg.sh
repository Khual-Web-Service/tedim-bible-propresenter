#!/bin/bash
# Builds TedimBibles.pkg — the double-click installer for macOS.
#
# The pkg carries the four .rvbible packages from dist/ and nothing else: it
# does not build them, and the machine it installs on never does either. Build
# dist/ on a Mac with ProPresenter first (tools/install-macos.sh, or
# tools/build_rvbible.py --template), where a real template exists.
#
# Requires macOS: pkgbuild and productbuild ship with it and have no equivalent
# elsewhere.
#
# Usage:
#   tools/make-pkg.sh [version]     # default: the latest git tag, else 1.0
#
# TODO: sign and notarize before wider distribution —
#   productbuild --sign "Developer ID Installer: <team>" …
#   xcrun notarytool submit TedimBibles.pkg --keychain-profile <profile> --wait
#   xcrun stapler staple TedimBibles.pkg
# Until then the pkg is unsigned and Gatekeeper blocks a double-click; the
# install instructions say to right-click and choose Open the first time.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
identifier="org.myanmarbs.tedimbibles"
install_location="/Library/Application Support/RenewedVision/RVBibles/v2"

version="${1:-}"
if [ -z "$version" ]; then
    version="$(git -C "$repo_root" describe --tags --abbrev=0 2>/dev/null || true)"
    version="${version#v}"
    [ -n "$version" ] || version="1.0"
fi

shopt -s nullglob
packages=("$repo_root"/dist/*.rvbible)
if [ "${#packages[@]}" -eq 0 ]; then
    echo "No .rvbible packages in $repo_root/dist." >&2
    echo "Build them on a Mac with ProPresenter first:" >&2
    echo "  tools/install-macos.sh   # builds dist/ and installs" >&2
    exit 1
fi

for tool in pkgbuild productbuild; do
    command -v "$tool" >/dev/null 2>&1 || {
        echo "$tool not found — building the pkg needs macOS." >&2
        exit 1
    }
done

work="$(mktemp -d "${TMPDIR:-/tmp}/tedim-pkg.XXXXXX")"
trap 'rm -rf "$work"' EXIT

# The payload: the system-wide Bibles folder, exactly as installed.
payload="$work/root$install_location"
mkdir -p "$payload"
cp "${packages[@]}" "$payload/"

mkdir -p "$work/scripts"
cat >"$work/scripts/postinstall" <<'POSTINSTALL'
#!/bin/bash
# Runs as root after the payload lands in /Library.
#
# Two things the payload alone cannot do:
#   1. Some ProPresenter installs read only the per-user Bibles folder, so the
#      packages are copied there too — for the person actually at the Mac, not
#      root. $USER is root here, so the console owner is who we want.
#   2. A translation installed earlier under a different filename makes
#      ProPresenter hide the duplicate, and the old text keeps showing. Those
#      known filenames are removed from both folders.

set -u

system_dest="/Library/Application Support/RenewedVision/RVBibles/v2"

console_user="$(stat -f '%Su' /dev/console 2>/dev/null || true)"
if [ -n "$console_user" ] && [ "$console_user" != "root" ]; then
    home="$(dscl . -read "/Users/$console_user" NFSHomeDirectory 2>/dev/null | awk '{print $2}')"
    [ -n "${home:-}" ] || home="/Users/$console_user"
    user_dest="$home/Library/Application Support/RenewedVision/RVBibles/v2"
else
    user_dest=""
fi

# Older packages of these same translations, under the names they shipped with.
stale="Tedim_Bible_Revision_2017.rvbible
Tedim_(Chin)_Bible.rvbible
Chin_1977_(Tedim Bible).rvbible
bjb-my.rvbible
kjv-en.rvbible"

remove_stale() {
    [ -d "$1" ] || return 0
    printf '%s\n' "$stale" | while IFS= read -r name; do
        [ -n "$name" ] || continue
        if [ -e "$1/$name" ]; then
            echo "Removing superseded $name from $1"
            rm -f "$1/$name"
        fi
    done
}

remove_stale "$system_dest"

if [ -n "$user_dest" ]; then
    remove_stale "$user_dest"
    mkdir -p "$user_dest"
    cp "$system_dest"/*.rvbible "$user_dest/" 2>/dev/null || true
    # The files were written by root; hand the folder back to its owner.
    chown -R "$console_user" "$user_dest"
fi

exit 0
POSTINSTALL
chmod +x "$work/scripts/postinstall"

component="$work/component.pkg"
pkgbuild \
    --root "$work/root" \
    --scripts "$work/scripts" \
    --identifier "$identifier" \
    --version "$version" \
    --install-location / \
    "$component" >/dev/null

mkdir -p "$repo_root/dist"
out="$repo_root/dist/TedimBibles.pkg"
productbuild --package "$component" "$out" >/dev/null

echo "Built $out (version $version) with:"
for package in "${packages[@]}"; do
    echo "  $(basename "$package")"
done
echo
echo "It is unsigned, so the first open needs right-click > Open."
