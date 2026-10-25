#!/usr/bin/env python3
"""Convert Lai Siangtho JSON bibles into ProPresenter bundles under bibles/.

Source: https://github.com/laisiangtho/bible (json/<identify>.json, MIT).

For each entry in IMPORTS this writes bibles/<CODE>/ with metadata.xml
(DBL 1.2, the same shape as the existing bundles), rvmetadata.xml, USX/ and
USX_1/, and adds or updates the entry in bibles.json. Verse text only:
section titles in the source are dropped so they never land on a slide.

Usage:
  python3 tools/import_laisiangtho.py <path-to-laisiangtho/bible> [CODE ...]
"""
import json
import sys
import uuid
from pathlib import Path
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parent.parent

BOOKS = """GEN EXO LEV NUM DEU JOS JDG RUT 1SA 2SA 1KI 2KI 1CH 2CH EZR NEH EST JOB
PSA PRO ECC SNG ISA JER LAM EZK DAN HOS JOL AMO OBA JON MIC NAM HAB ZEP HAG ZEC
MAL MAT MRK LUK JHN ACT ROM 1CO 2CO GAL EPH PHP COL 1TH 2TH 1TI 2TI TIT PHM HEB
JAS 1PE 2PE 1JN 2JN 3JN JUD REV""".split()

# code, source file, ProPresenter name, language name, script
IMPORTS = [
    ("ZBI", "1065", "Lai Siengthou (Zou 1992)", "Zou", "Latin"),
    ("ZBM", "2486", "Zo Bible (Zou 2018)", "Zou", "Latin"),
    ("PAITE", "paite1971", "Paite Bible (1971)", "Paite", "Latin"),
    ("SIZANG", "sizang1932", "Lai Siangtho (Sizang 1932)", "Chin: Siyin", "Latin"),
    ("FALAM", "falam1973", "Baibal Thianghlim (Falam 1973)", "Chin: Falam", "Latin"),
    ("HAKHA", "hakha1920", "Baibal Thiang (Hakha 1920)", "Chin: Hakha", "Latin"),
    ("MIZO", "mizo1917", "Pathian Lehkhabu Thianghlim (Mizo 1917)", "Mizo", "Latin"),
    ("MIZOCL", "1048", "Common Language Bible (Mizo 1995)", "Mizo", "Latin"),
    ("MARA", "mara2011", "Khazopa Chabu Pathaipa (Mara 2011)", "Chin: Mara", "Latin"),
    ("THADOU", "1879", "Pathen Thutheng Bu (Thadou 2015)", "Thadou", "Latin"),
    ("MSV", "mcl2005", "Myanmar Standard Version (2005)", "Burmese", "Myanmar"),
    ("MCL", "1391", "Myanmar Common Language (2005)", "Burmese", "Myanmar"),
    ("MNWT", "jwmynwt", "New World Translation (Burmese 2010)", "Burmese", "Myanmar"),
    ("JCLB", "348", "Jinghpaw Common Language Bible (2009)", "Jinghpaw", "Latin"),
    ("JHVB", "2647", "Jinghpaw Hanson Version Bible (2009)", "Jinghpaw", "Latin"),
]


def clean(s: str) -> str:
    return " ".join(str(s or "").replace("​", "").split())


def usx(code: str, name: str, short: str, chapters: dict) -> str:
    out = [
        '<?xml version="1.0" encoding="utf-8"?>',
        '<usx version="2.0">',
        f'  <book code="{code}" style="id">{escape(name)}</book>',
        f'  <para style="h">{escape(short)}</para>',
        f'  <para style="toc1">{escape(name)}</para>',
        f'  <para style="toc2">{escape(short)}</para>',
        f'  <para style="mt">{escape(name)}</para>',
    ]
    for cnum in sorted(chapters, key=int):
        out.append(f'  <chapter number="{int(cnum)}" style="c" />')
        for vnum, verse in sorted(chapters[cnum]["verse"].items(), key=lambda kv: int(kv[0])):
            text = clean(verse.get("text"))
            if not text:
                continue
            out.append('  <para style="p">')
            out.append(f'    <verse number="{int(vnum)}" style="v" />{escape(text)}')
            out.append("  </para>")
    out.append("</usx>")
    return "\n".join(out) + "\n"


def metadata(code, name, iso, lang, script, license_, names) -> str:
    rows = []
    for c in BOOKS:
        long_, short, abbr = (escape(x) for x in names[c])
        rows.append(
            f'      <book code="{c}">\n         <long>{long_}</long>\n'
            f'         <short>{short}</short>\n         <abbr>{abbr}</abbr>\n      </book>'
        )
    books = "\n".join(f'            <book code="{c}" />' for c in BOOKS)
    n, lic = escape(name), escape(license_)
    return f"""<?xml version="1.0" encoding="utf-8"?>
<DBLMetadata id="{uuid.uuid5(uuid.NAMESPACE_URL, 'laisiangtho:' + code).hex[:16]}" revision="2" type="text" typeVersion="1.2">
   <identification>
      <name>{n}</name>
      <nameLocal>{n}</nameLocal>
      <abbreviation>{code}</abbreviation>
      <abbreviationLocal>{code}</abbreviationLocal>
      <scope>Old and New Testament</scope>
      <description>{lic}. Old and New Testament</description>
      <dateCompleted></dateCompleted>
      <bundleProducer></bundleProducer>
   </identification>
   <agencies>
      <etenPartner>NON-DBL</etenPartner>
      <creator>HolySpirit</creator>
   </agencies>
   <language>
      <iso>{iso}</iso>
      <name>{escape(lang)}</name>
      <script>{script}</script>
      <scriptDirection>LTR</scriptDirection>
   </language>
   <bookNames>
{chr(10).join(rows)}
   </bookNames>
   <contents>
      <bookList id="1" default="yes">
         <name>{n}</name>
         <nameLocal>{n}</nameLocal>
         <abbreviation>{code}</abbreviation>
         <abbreviationLocal>{code}</abbreviationLocal>
         <description>null</description>
         <range>Old and New Testament</range>
         <tradition />
         <books>
{books}
         </books>
      </bookList>
   </contents>
</DBLMetadata>
"""


def rvmetadata(code, name, license_) -> str:
    return f"""<?xml version="1.0" encoding="utf-8"?>
<RVBibleMetdata>
    <name>{escape(name)}</name>
    <abbreviation>{code}</abbreviation>
    <displayAbbreviation>{code}</displayAbbreviation>
    <version>2.1</version>
    <revision>4</revision>
    <licenseType>0</licenseType>
    <license>{escape(license_)}</license>
</RVBibleMetdata>
"""


def convert(src: Path, code, ident, name, lang, script) -> dict:
    data = json.loads((src / "json" / f"{ident}.json").read_text(encoding="utf-8"))
    info = data["info"]
    iso = info["language"]["name"]
    publisher = clean(info.get("publisher")) or "the copyright holder"
    year = clean(info.get("year"))
    license_ = f"{name} © {publisher}" + (f", {year}" if year and year not in name else "")

    out = ROOT / "bibles" / code
    for sub in ("USX", "USX_1"):
        (out / sub).mkdir(parents=True, exist_ok=True)
    names = {}
    for i, c in enumerate(BOOKS, 1):
        book = data["book"][str(i)]
        b = book["info"]
        long_ = clean(b.get("name")) or c
        abbr = clean((b.get("abbr") or [""])[0]) or clean(b.get("shortname")) or long_
        names[c] = (long_, long_, abbr)
        text = usx(c, long_, long_, book["chapter"])
        for sub in ("USX", "USX_1"):
            (out / sub / f"{c}.usx").write_text(text, encoding="utf-8")
    (out / "metadata.xml").write_text(
        metadata(code, name, iso, lang, script, license_, names), encoding="utf-8")
    (out / "rvmetadata.xml").write_text(rvmetadata(code, name, license_), encoding="utf-8")
    return {
        "uuid": str(uuid.uuid5(uuid.NAMESPACE_URL, "laisiangtho:" + code)),
        "abbreviation": code,
        "name": name,
        "language": iso,
        "license": license_,
        "source": f"laisiangtho/bible json/{ident}.json",
    }


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    src = Path(sys.argv[1])
    only = set(sys.argv[2:])
    manifest_path = ROOT / "bibles.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    by_code = {e["abbreviation"]: e for e in manifest["bibles"]}
    for code, ident, name, lang, script in IMPORTS:
        if only and code not in only:
            continue
        entry = convert(src, code, ident, name, lang, script)
        if code in by_code:
            entry["uuid"] = by_code[code]["uuid"]  # keep the installed folder stable
            by_code[code].update(entry)
        else:
            manifest["bibles"].append(entry)
        print(f"{code}: {name}")
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
