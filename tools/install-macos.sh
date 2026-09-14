#!/usr/bin/env bash
# Installs the Tedim (Chin) Bible bundles into ProPresenter 7 on macOS.
#
# ProPresenter stores each Bible on macOS as a .rvbible file (a zip of a bundle)
# under RVBibles/v2, which is the same format its own Bible downloads use. This
# script builds those packages and copies them in, so ProPresenter registers
# them itself — there is no preference file to edit, unlike on Windows.
#
# Two things about that format are easy to get wrong, and ProPresenter says
# nothing useful when you do — it either reports "We don't handle the file type"
# or quietly ignores the Bible:
#
#   1. The books do not live at the root of the zip. A package ProPresenter
#      accepts looks like:
#          metadata.xml
#          rvmetadata.xml
#          release/USX_1/GEN.usx …
#          release/styles.xml
#          release/versification.vrs
#          release/*.ldml
#   2. metadata.xml must be DBL 2.x (<DBLMetadata id="…" revision="…"
#      version="2.1">, or the 2.2.1 shape ProPresenter ships today,
#      <DBLMetadata version="2.2.1" id="…" revision="11">). The metadata.xml
#      files in this repository are DBL 1.2, which ProPresenter does not parse.
#      Attribute order differs between those releases, so nothing here may
#      depend on it.
#
# Rather than inventing 2.x metadata, this script borrows it: it takes a
# .rvbible that ProPresenter itself installed, uses it as a template, swaps our
# books and rvmetadata.xml in, and rewrites the identifying fields of the
# template's metadata.xml. So you need at least one working Bible installed
# first — any free one from ProPresenter's Options > Bibles will do.
#
# It needs nothing beyond what macOS already has: no Python, no Xcode command
# line tools.
#
# Quit ProPresenter first. If a destination needs administrator rights, the
# script re-runs that copy with sudo and macOS will ask for your password.
#
# Usage:
#   tools/install-macos.sh [bibles-folder]
#   DRY_RUN=1 tools/install-macos.sh      # show what would happen, change nothing

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dry_run="${DRY_RUN:-}"

system_dest="/Library/Application Support/RenewedVision/RVBibles/v2"
user_dest="$HOME/Library/Application Support/RenewedVision/RVBibles/v2"

# zsh (the default shell on macOS) passes a pasted trailing comment through as
# arguments, so `tools/install-macos.sh   # install` arrives here as two stray
# words. Drop anything from the first '#' on rather than treating it as a path.
args=()
for arg in "$@"; do
    case "$arg" in
        '#'*) break ;;
        *) args+=("$arg") ;;
    esac
done
set -- ${args[@]+"${args[@]}"}

# Some installs read only the per-user folder, others only the system one, and
# nothing in ProPresenter says which. Install into both unless told otherwise.
if [ $# -ge 1 ]; then
    destinations=("$1")
else
    destinations=("$system_dest" "$user_dest")
fi

if pgrep -x ProPresenter >/dev/null 2>&1; then
    echo "ProPresenter is running. Quit it first, then run this script again." >&2
    exit 1
fi

# Write with sudo only where the destination actually needs it.
run_write() {
    local target_dir="$1"
    shift
    if [ -n "$dry_run" ]; then
        echo "  would run: $*"
    elif [ -w "$target_dir" ] || { [ ! -e "$target_dir" ] && [ -w "$(dirname "$target_dir")" ]; }; then
        "$@"
    else
        sudo "$@"
    fi
}

work="$(mktemp -d "${TMPDIR:-/tmp}/rvbible.XXXXXX")"
trap 'rm -rf "$work"' EXIT

# --- find a template ---------------------------------------------------------
#
# A usable template is a .rvbible ProPresenter installed itself: it has the
# release/USX_1/ layout and DBL 2.x metadata. The American Standard Version is
# the usual free download, so prefer it, but any valid package works.
#
# Set RVBIBLE_TEMPLATE to a .rvbible to use that one instead of searching — how
# tools/check-build-parity.sh points both build paths at the same template.

# `unzip | grep -q` is deliberately avoided: grep exits at the first match,
# unzip dies of SIGPIPE, and pipefail then fails the whole pipeline. Capture the
# listing first and grep that.
zip_contains() {
    local listing
    listing="$(unzip -l "$1" 2>/dev/null || true)"
    case "$listing" in
        *"$2"*) return 0 ;;
        *) return 1 ;;
    esac
}

# The <DBLMetadata …> start tag, on one line, or empty if there is none. The
# tag may be written across several lines, and its attributes come in no fixed
# order — 2.1 opens with id=, the 2.2.1 packages ProPresenter ships today open
# with version= — so it is read as a whole rather than matched line by line.
dbl_header() {
    awk '
        { buf = buf $0 "\n" }
        END {
            if (match(buf, /<DBLMetadata[^>]*>/)) {
                tag = substr(buf, RSTART, RLENGTH)
                gsub(/[\n\t]+/, " ", tag)
                print tag
            }
        }
    '
}

# True for any DBL 2.x metadata, whatever the attribute order; false for 1.x,
# which ProPresenter does not parse.
is_dbl2_header() {
    case "$1" in
        *'version="2.'*) return 0 ;;
        *) return 1 ;;
    esac
}

is_valid_template() {
    local candidate="$1" header
    zip_contains "$candidate" 'release/USX_1/' || return 1
    header="$(unzip -p "$candidate" metadata.xml 2>/dev/null | dbl_header || true)"
    is_dbl2_header "$header"
}

find_template() {
    local dir candidate

    if [ -n "${RVBIBLE_TEMPLATE:-}" ]; then
        if [ -f "$RVBIBLE_TEMPLATE" ] && is_valid_template "$RVBIBLE_TEMPLATE"; then
            printf '%s\n' "$RVBIBLE_TEMPLATE"
            return 0
        fi
        echo "RVBIBLE_TEMPLATE=$RVBIBLE_TEMPLATE is not a usable template." >&2
        return 1
    fi

    # Preferred name first, then anything else that validates.
    for dir in "$user_dest" "$system_dest"; do
        [ -d "$dir" ] || continue
        for candidate in "$dir"/publicdomain_American_Standard_Version*.rvbible; do
            [ -f "$candidate" ] || continue
            if is_valid_template "$candidate"; then
                printf '%s\n' "$candidate"
                return 0
            fi
        done
    done
    for dir in "$user_dest" "$system_dest"; do
        [ -d "$dir" ] || continue
        for candidate in "$dir"/*.rvbible; do
            [ -f "$candidate" ] || continue
            if is_valid_template "$candidate"; then
                printf '%s\n' "$candidate"
                return 0
            fi
        done
    done
    return 1
}

shopt -s nullglob

template=""
if ! template="$(find_template)"; then
    cat >&2 <<'EOF'
No usable .rvbible template was found.

This script copies the package structure from a Bible ProPresenter installed
itself, because ProPresenter only accepts its own metadata format. To get one:

  1. Open ProPresenter.
  2. Go to Options (or Preferences) > Bibles.
  3. Download any free Bible — "American Standard Version" under Public Domain
     is the one this script looks for first, but any of them will do.
  4. Quit ProPresenter and run this script again.

Looked in:
EOF
    printf '  %s\n' "$system_dest" "$user_dest" >&2
    exit 1
fi

echo "Using template: $template"

template_dir="$work/template"
mkdir -p "$template_dir"
unzip -q "$template" -d "$template_dir"

# --- helpers for rewriting the template's metadata ---------------------------

# Read a top-level element out of our rvmetadata.xml.
rv_field() {
    local file="$1" field="$2"
    tr '\n' ' ' <"$file" \
        | sed -n "s|.*<$field>\(.*\)</$field>.*|\1|p" \
        | sed -n '1{s/^ *//;s/ *$//;p;}'
}

xml_escape() {
    printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
}

new_id() {
    # 16 lowercase hex characters, the shape of a DBL 2.x bundle id.
    LC_ALL=C od -An -N8 -tx1 /dev/urandom | tr -d ' \n'; echo
}

# Replace the id="…" attribute of the <DBLMetadata …> start tag, wherever it
# sits among that tag's attributes, and nowhere else: the document is full of
# other id attributes (publications, book and name entries) and of <id> elements
# under <systemId>, none of which may change. Prints the rewritten document;
# fails if there is no DBLMetadata tag or it carries no id.
rewrite_bundle_id() {
    awk -v id="$1" '
        { buf = buf $0 "\n" }
        END {
            if (!match(buf, /<DBLMetadata[^>]*>/)) exit 1
            tag = substr(buf, RSTART, RLENGTH)
            if (!sub(/id="[^"]*"/, "id=\"" id "\"", tag)) exit 1
            printf "%s%s%s", substr(buf, 1, RSTART - 1), tag, substr(buf, RSTART + RLENGTH)
        }
    ' "$2"
}

# --- localized book names ----------------------------------------------------
#
# The rewrite rules live in one place, shared with tools/build_rvbible.py.

names_lib="$repo_root/tools/localize-book-names.sh"
if [ ! -f "$names_lib" ]; then
    echo "Missing $names_lib — is this a complete copy of the repository?" >&2
    exit 1
fi
# shellcheck source=tools/localize-book-names.sh
. "$names_lib"

# --- build ------------------------------------------------------------------

echo "Building .rvbible packages..."
# The packages are built into dist/ and installed from there. Tests point
# RVBIBLE_DIST at a scratch folder so a test run cannot overwrite the packages
# committed in dist/.
dist_dir="${RVBIBLE_DIST:-$repo_root/dist}"
mkdir -p "$dist_dir"

packages=()
# Counted separately: macOS ships bash 3.2, where ${#array[@]} on an empty array
# counts as unbound under `set -u` and aborts with a confusing error.
built=0

for bundle in "$repo_root"/bibles/*/; do
    # Each bundle folder is named for its code, which is also the package name.
    abbr="$(basename "$bundle")"
    package="$dist_dir/$abbr.rvbible"

    if [ ! -f "$bundle/rvmetadata.xml" ]; then
        echo "  skipping $abbr: no rvmetadata.xml" >&2
        continue
    fi

    books="$bundle/USX"
    [ -d "$books" ] || books="$bundle/USX_1"
    if [ ! -d "$books" ]; then
        echo "  skipping $abbr: no USX/ or USX_1/ folder" >&2
        continue
    fi

    stage="$work/stage-$abbr"
    rm -rf "$stage"
    cp -R "$template_dir" "$stage"

    # Our books replace the template's, under the name ProPresenter reads.
    rm -rf "$stage/release/USX_1"
    mkdir -p "$stage/release/USX_1"
    cp "$books"/*.usx "$stage/release/USX_1/"

    # Keep the template's styles.xml, versification.vrs and .ldml unless this
    # bundle ships its own.
    for extra in styles.xml versification.vrs; do
        if [ -f "$bundle/$extra" ]; then
            cp "$bundle/$extra" "$stage/release/$extra"
        fi
    done
    for ldml in "$bundle"/*.ldml; do
        rm -f "$stage"/release/*.ldml
        cp "$ldml" "$stage/release/"
    done

    # ProPresenter's own metadata, which names the translation in its UI.
    cp "$bundle/rvmetadata.xml" "$stage/rvmetadata.xml"
    if [ -f "$bundle/license.xml" ]; then
        cp "$bundle/license.xml" "$stage/license.xml"
    fi

    # Rewrite the identifying fields of the template's 2.x metadata so the
    # package describes our translation rather than the template's.
    name="$(rv_field "$bundle/rvmetadata.xml" name)"
    abbreviation="$(rv_field "$bundle/rvmetadata.xml" abbreviation)"
    [ -n "$abbreviation" ] || abbreviation="$abbr"
    [ -n "$name" ] || name="$abbr"

    esc_name="$(xml_escape "$name")"
    esc_abbr="$(xml_escape "$abbreviation")"
    fresh_id="$(new_id)"

    if ! rewrite_bundle_id "$fresh_id" "$stage/metadata.xml" >"$stage/metadata.xml.new"; then
        echo "  $abbr: the template's metadata.xml has no <DBLMetadata id=\"…\"> to rewrite" >&2
        exit 1
    fi
    mv "$stage/metadata.xml.new" "$stage/metadata.xml"

    awk -v name="$esc_name" -v abbr="$esc_abbr" '
        !done_name && /<name>/         { sub(/<name>[^<]*<\/name>/, "<name>" name "</name>"); done_name = 1; print; next }
        !done_local && /<nameLocal>/    { sub(/<nameLocal>[^<]*<\/nameLocal>/, "<nameLocal>" name "</nameLocal>"); done_local = 1; print; next }
        !done_desc && /<description>/   { sub(/<description>[^<]*<\/description>/, "<description>" name "</description>"); done_desc = 1; print; next }
        !done_ab && /<abbreviation>/    { sub(/<abbreviation>[^<]*<\/abbreviation>/, "<abbreviation>" abbr "</abbreviation>"); done_ab = 1; print; next }
        !done_ablocal && /<abbreviationLocal>/ { sub(/<abbreviationLocal>[^<]*<\/abbreviationLocal>/, "<abbreviationLocal>" abbr "</abbreviationLocal>"); done_ablocal = 1; print; next }
        { print }
    ' "$stage/metadata.xml" >"$stage/metadata.xml.new"
    mv "$stage/metadata.xml.new" "$stage/metadata.xml"

    # …and give it our book names, so the Bible view does not list Genesis in
    # English over Tedim or Burmese text.
    build_names_table "$bundle" "$books" "$work/names-$abbr.tsv"
    apply_book_names "$work/names-$abbr.tsv" "$stage/metadata.xml"

    rm -f "$package"
    # A .rvbible is a zip of the bundle's *contents*, so zip from inside it.
    (cd "$stage" && zip -q -r -X "$package" . -x '*.DS_Store')

    # Cheap guard against silently shipping the old, flat layout again.
    if ! zip_contains "$package" 'release/USX_1/'; then
        echo "  built $abbr.rvbible without release/USX_1/ — refusing to install it" >&2
        exit 1
    fi

    echo "  built $abbr.rvbible ($name / $abbreviation, id $fresh_id)"
    packages+=("$package")
    built=$((built + 1))
done

if [ "$built" -eq 0 ]; then
    echo "No .rvbible packages were built." >&2
    echo "Is $repo_root/bibles missing or empty?" >&2
    exit 1
fi

# --- install ----------------------------------------------------------------

for dest in "${destinations[@]}"; do
    echo
    echo "Installing into: $dest"
    run_write "$dest" mkdir -p "$dest"

    for package in "${packages[@]}"; do
        name="$(basename "$package")"
        if [ -e "$dest/$name" ]; then
            echo "Replacing existing $name"
        fi
        run_write "$dest" cp "$package" "$dest/$name"
        [ -n "$dry_run" ] || echo "Installed $name"
    done
done

if [ -n "$dry_run" ]; then
    echo
    echo "Dry run - nothing was written."
    exit 0
fi

echo
echo "Done. Start ProPresenter and open the Bible view."
echo "If a translation does not show up, quit ProPresenter completely with"
echo "Cmd+Q and start it again — sometimes twice. If an older copy of one of"
echo "these Bibles is installed under a different filename, delete it from both"
echo "RVBibles/v2 folders first: ProPresenter hides duplicates."
