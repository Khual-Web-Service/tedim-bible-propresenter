#!/bin/sh
# Rewrite a DBL 2.1 metadata.xml so its book names are the local ones this
# repository carries, rather than the names of whichever Bible was used as a
# packaging template.
#
# ProPresenter only parses DBL 2.1 metadata, and the packages built here get
# theirs by transplanting it from a Bible ProPresenter installed itself (see
# tools/install-macos.sh). That metadata brings the template's <names> section
# with it, so without this the Bible view lists "Genesis" over Tedim or Burmese
# text.
#
# Both build paths use this file, so the rules live in one place:
#
#   * tools/install-macos.sh sources it and calls build_names_table and
#     apply_book_names directly.
#   * tools/build_rvbible.py runs it as a command.
#
# Shell and awk only — installing Bibles should not need developer tools.
#
# Usage as a command:
#   tools/localize-book-names.sh <bundle-dir> <books-dir> <metadata.xml>
#
#     bundle-dir    a folder under bibles/, read for metadata.xml
#     books-dir     the USX folder whose *.usx files say which books we ship
#     metadata.xml  the transplanted metadata, rewritten in place

# --- localized book names ----------------------------------------------------
#
# The template's metadata.xml carries the template Bible's <names> section, so
# a transplanted package shows English book names ("Genesis") over our text.
# These build a table of local names for the books we ship and write them into
# the template's entries.
#
# Preferred source is the bundle's own DBL 1.2 metadata.xml, which has a
# <bookNames> block; where a book is missing there, the USX file itself carries
# \toc1 (long), \toc2 or \h (short) and \toc3 (abbreviation).

# Escape for XML content, leaving existing entities (&#4096; in the Burmese
# names) alone — the values are lifted straight out of XML and are escaped
# already; only a bare '&' needs help.
names_awk_prelude='
function xmlsafe(v,   out, i, rest) {
    out = ""
    while ((i = index(v, "&")) > 0) {
        out = out substr(v, 1, i - 1)
        rest = substr(v, i)
        if (match(rest, /^&[#A-Za-z][A-Za-z0-9]*;/)) {
            out = out substr(rest, 1, RLENGTH)
            v = substr(rest, RLENGTH + 1)
        } else {
            out = out "\&amp;"
            v = substr(rest, 2)
        }
    }
    v = out v
    gsub(/</, "\&lt;", v)
    gsub(/>/, "\&gt;", v)
    return v
}
function attrtext(line, tag,   open, endtag, i, j, k) {
    open = "<" tag " "
    endtag = "</" tag ">"
    i = index(line, open)
    if (i == 0) return ""
    j = index(substr(line, i), ">")
    if (j == 0) return ""
    k = i + j
    j = index(substr(line, k), endtag)
    if (j == 0) return ""
    return substr(line, k, j - 1)
}
function tagtext(line, tag,   open, endtag, i, j) {
    open = "<" tag ">"
    endtag = "</" tag ">"
    i = index(line, open)
    if (i == 0) return ""
    j = index(substr(line, i + length(open)), endtag)
    if (j == 0) return ""
    return substr(line, i + length(open), j - 1)
}
'

# CODE<tab>abbr<tab>short<tab>long for every book in the bundle's metadata.
names_from_metadata() {
    [ -f "$1" ] || return 0
    awk "$names_awk_prelude"'
        /<bookNames>/  { inside = 1 }
        /<\/bookNames>/ { inside = 0 }
        inside && /<book code="[A-Z0-9]+"/ {
            line = $0
            i = index(line, "code=\"")
            code = substr(line, i + 6)
            code = substr(code, 1, index(code, "\"") - 1)
            a = ""; s = ""; l = ""
        }
        inside && code != "" {
            if (l == "") l = tagtext($0, "long")
            if (s == "") s = tagtext($0, "short")
            if (a == "") a = tagtext($0, "abbr")
        }
        inside && /<\/book>/ && code != "" {
            print code "\t" xmlsafe(a) "\t" xmlsafe(s) "\t" xmlsafe(l)
            code = ""
        }
    ' "$1"
}

# CODE<tab>abbr<tab>short<tab>long from one USX file, read only as far as the
# first chapter — the name lines all sit in the header.
names_from_usx() {
    awk -v code="$2" "$names_awk_prelude"'
        /<chapter/ { exit }
        /<para style="toc1">/ { l = attrtext($0, "para") }
        /<para style="toc2">/ { s = attrtext($0, "para") }
        /<para style="toc3">/ { a = attrtext($0, "para") }
        /<para style="h">/    { h = attrtext($0, "para") }
        END {
            if (s == "") s = h
            if (l == "" && s == "" && a == "") exit
            print code "\t" xmlsafe(a) "\t" xmlsafe(s) "\t" xmlsafe(l)
        }
    ' "$1"
}

# Merge both sources for the books we actually ship, filling gaps in one
# direction only: metadata wins, the USX header fills what it leaves empty, and
# long/short/abbr stand in for each other rather than being written blank.
build_names_table() {
    local bundle="$1" books="$2" table="$3"
    local raw="$table.raw" usx code

    : >"$raw"
    names_from_metadata "$bundle/metadata.xml" >>"$raw"
    for usx in "$books"/*.usx; do
        code="$(basename "$usx" .usx)"
        names_from_usx "$usx" "$code" >>"$raw"
    done

    # Books we ship, in the order their files appear.
    for usx in "$books"/*.usx; do
        basename "$usx" .usx
    done >"$table.codes"

    awk -F'\t' '
        FNR == NR {
            # First entry for a code wins per field; later ones only fill gaps.
            if (!($1 in seen)) { seen[$1] = 1; a[$1] = $2; s[$1] = $3; l[$1] = $4 }
            else {
                if (a[$1] == "") a[$1] = $2
                if (s[$1] == "") s[$1] = $3
                if (l[$1] == "") l[$1] = $4
            }
            next
        }
        {
            code = $1
            if (!(code in seen)) next
            av = a[code]; sv = s[code]; lv = l[code]
            if (sv == "") sv = (lv != "" ? lv : av)
            if (lv == "") lv = sv
            if (av == "") av = sv
            if (av == "" && sv == "" && lv == "") next
            print code "\t" av "\t" sv "\t" lv
        }
    ' "$raw" "$table.codes" >"$table"

    rm -f "$raw" "$table.codes"
}

# Write those names into the template metadata's <names> entries, which look
# like <name id="book-gen"><abbr/><short/><long/></name>. Every shape the DBL
# 2.1 and 2.2.1 templates use is handled: the whole entry on one line, spread
# over several lines (what the 2.2.1 packages ProPresenter ships today do), a
# value tag written empty and self-closing as <abbr/> or <abbr />, and several
# entries sharing a line — each line is walked entry by entry rather than
# assuming one entry per line. Entries for books we do not ship are left as the
# template had them, matching how the template itself lists every book it
# carries.
apply_book_names() {
    local table="$1" metadata="$2"

    [ -s "$table" ] || return 0

    awk -F'\t' '
        function replace_tag(line, tag, val,   open, endtag, self, i, j, k) {
            if (val == "") return line
            open = "<" tag ">"
            endtag = "</" tag ">"
            i = index(line, open)
            if (i > 0) {
                j = index(substr(line, i + length(open)), endtag)
                if (j == 0) return line
                return substr(line, 1, i - 1) open val endtag \
                       substr(line, i + length(open) + j - 1 + length(endtag))
            }
            for (k = 0; k <= 1; k++) {
                self = (k == 0) ? "<" tag "/>" : "<" tag " />"
                i = index(line, self)
                if (i > 0)
                    return substr(line, 1, i - 1) open val endtag \
                           substr(line, i + length(self))
            }
            return line
        }
        function localize(part, c) {
            if (c == "" || !(c in a)) return part
            part = replace_tag(part, "abbr", a[c])
            part = replace_tag(part, "short", s[c])
            part = replace_tag(part, "long", l[c])
            return part
        }
        FNR == NR { a[$1] = $2; s[$1] = $3; l[$1] = $4; next }
        {
            line = $0
            out = ""
            # Walk the line entry by entry. Text before the first <name
            # id="book-…"> belongs to the entry the previous line opened, if
            # any; each following segment belongs to the entry it opens.
            while (match(line, /<name id="book-[A-Za-z0-9]+"/)) {
                start = RSTART
                len = RLENGTH
                out = out localize(substr(line, 1, start - 1), code)
                tag = substr(line, start, len)
                code = substr(tag, index(tag, "book-") + 5)
                sub(/".*$/, "", code)
                code = toupper(code)
                out = out tag
                line = substr(line, start + len)
            }
            out = out localize(line, code)
            # The values of an entry never span past its own </name>, and no
            # <name> outside the <names> section is a book entry.
            if (index(line, "</name>") > 0 || index(line, "</names>") > 0) code = ""
            print out
        }
    ' "$table" "$metadata" >"$metadata.names"
    mv "$metadata.names" "$metadata"
}

# Rewrite one metadata.xml in place. Only runs when this file is executed;
# sourcing it (as tools/install-macos.sh does) just defines the functions.
localize_book_names_main() {
    if [ $# -ne 3 ]; then
        echo "usage: localize-book-names.sh <bundle-dir> <books-dir> <metadata.xml>" >&2
        exit 2
    fi

    table="${TMPDIR:-/tmp}/book-names.$$"
    build_names_table "$1" "$2" "$table"
    apply_book_names "$table" "$3"
    rm -f "$table"
}

case "${0##*/}" in
    localize-book-names.sh) localize_book_names_main "$@" ;;
esac
