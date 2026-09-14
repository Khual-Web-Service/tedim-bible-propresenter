#!/bin/sh
# Build a synthetic .rvbible template for testing, in either DBL header shape.
#
# The real templates come from ProPresenter and cannot be committed here, so
# the checks in tools/test-metadata.sh and the default run of
# tools/check-build-parity.sh use one of these instead. It carries the parts of
# a template the build actually touches:
#
#   * a <DBLMetadata …> start tag in the requested shape,
#   * id attributes elsewhere in the document (a <systemId><id>, a publication,
#     the <names> entries) which the build must leave alone,
#   * a publication <content> map, which the build must not disturb,
#   * a <names> section written in every entry shape the real templates use:
#     one line, several lines, self-closing <abbr/> and <abbr />, and two
#     entries sharing a line,
#   * the release/USX_1/ layout.
#
# Usage:
#   tools/make-test-template.sh <out.rvbible> [2.2.1|2.1|1.2]
#
# 2.2.1 (the default) is what ProPresenter ships today: version= first,
# revision="11". 2.1 is the older shape, id= first. 1.2 is our own pre-DBL-2
# metadata, which the build must keep rejecting.

set -eu

if [ $# -lt 1 ]; then
    echo "usage: make-test-template.sh <out.rvbible> [2.2.1|2.1|1.2]" >&2
    exit 2
fi

out="$1"
shape="${2:-2.2.1}"

case "$shape" in
    2.2.1) header='<DBLMetadata version="2.2.1" id="bb5a17ca143f4866" revision="11">' ;;
    2.1)   header='<DBLMetadata id="bb5a17ca143f4866" revision="3" version="2.1">' ;;
    1.2)   header='<DBLMetadata id="bb5a17ca143f4866" revision="3" type="text" typeVersion="1.2">' ;;
    *)     echo "unknown header shape: $shape (want 2.2.1, 2.1 or 1.2)" >&2; exit 2 ;;
esac

command -v zip >/dev/null 2>&1 || { echo "zip is not installed" >&2; exit 1; }

work="$(mktemp -d "${TMPDIR:-/tmp}/tmpl.XXXXXX")"
trap 'rm -rf "$work"' EXIT

mkdir -p "$work/release/USX_1"

{
    printf '%s\n' "$header"
    cat <<'EOF'
    <identification>
      <name>The Holy Bible, American Standard Version</name>
      <nameLocal>The Holy Bible, American Standard Version</nameLocal>
      <description>Bible</description>
      <abbreviation>ASV</abbreviation>
      <abbreviationLocal>ASV</abbreviationLocal>
      <systemId type="paratext">
        <id>06125adad2d5898a0bfd9b8e13fb698fa5a2d0d8</id>
        <name>engASV</name>
      </systemId>
    </identification>
    <publications>
      <publication id="p1" default="true">
        <name>The Holy Bible, American Standard Version</name>
        <abbreviation>ASV</abbreviation>
        <canonicalContent>
          <book code="GEN"/>
          <book code="EXO"/>
          <book code="LEV"/>
        </canonicalContent>
        <structure>
          <content name="book-gen" src="release/USX_1/GEN.usx" role="GEN"/>
          <content name="book-exo" src="release/USX_1/EXO.usx" role="EXO"/>
          <content name="book-lev" src="release/USX_1/LEV.usx" role="LEV"/>
        </structure>
      </publication>
    </publications>
    <names>
      <name id="book-gen">
        <abbr>Gen</abbr>
        <short>Genesis</short>
        <long>Genesis</long>
      </name>
      <name id="book-exo"><abbr>Exod</abbr><short>Exodus</short><long>Exodus</long></name>
      <name id="book-lev">
        <abbr/>
        <short />
        <long>Leviticus</long>
      </name>
      <name id="book-num"><abbr>Num</abbr><short>Numbers</short><long>Numbers</long></name><name id="book-deu"><abbr>Deut</abbr><short>Deuteronomy</short><long>Deuteronomy</long></name>
    </names>
</DBLMetadata>
EOF
} >"$work/metadata.xml"

cat >"$work/rvmetadata.xml" <<'EOF'
<RVBibleMetadata>
  <name>The Holy Bible, American Standard Version</name>
  <abbreviation>ASV</abbreviation>
</RVBibleMetadata>
EOF

cat >"$work/release/styles.xml" <<'EOF'
<stylesheet/>
EOF
printf '#test versification\n' >"$work/release/versification.vrs"
printf '<ldml/>\n' >"$work/release/en.ldml"

for code in GEN EXO LEV; do
    cat >"$work/release/USX_1/$code.usx" <<EOF
<usx version="3.0">
  <book code="$code" style="id">American Standard Version</book>
  <para style="h">$code</para>
</usx>
EOF
done

out_dir="$(cd "$(dirname "$out")" && pwd)"
out="$out_dir/$(basename "$out")"
rm -f "$out"
(cd "$work" && zip -q -r -X "$out" . -x '*.DS_Store')

echo "$out"
