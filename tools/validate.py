#!/usr/bin/env python3
"""Validate the bundles in bibles/ against what ProPresenter 7 expects.

Checks, per bundle:
  * folder name is a UUID and matches bibles.json
  * metadata.xml / rvmetadata.xml are present and well-formed XML
  * the abbreviation in rvmetadata.xml matches the manifest
  * a USX/ folder exists and every file in it is well-formed USX with a
    <book code="..."> matching its filename
  * all 66 canonical books are present

Usage: python3 tools/validate.py
"""
import json
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
UUID_RE = re.compile(r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")

BOOKS = """GEN EXO LEV NUM DEU JOS JDG RUT 1SA 2SA 1KI 2KI 1CH 2CH EZR NEH EST JOB
PSA PRO ECC SNG ISA JER LAM EZK DAN HOS JOL AMO OBA JON MIC NAM HAB ZEP HAG ZEC
MAL MAT MRK LUK JHN ACT ROM 1CO 2CO GAL EPH PHP COL 1TH 2TH 1TI 2TI TIT PHM HEB
JAS 1PE 2PE 1JN 2JN 3JN JUD REV""".split()


def check(bundle_dir: Path, entry: dict, errors: list, warnings: list) -> None:
    tag = f"{entry['abbreviation']} ({bundle_dir.name})"

    if not UUID_RE.match(bundle_dir.name):
        errors.append(f"{tag}: folder name is not a lowercase UUID")

    for name in ("metadata.xml", "rvmetadata.xml"):
        path = bundle_dir / name
        if not path.is_file():
            errors.append(f"{tag}: missing {name}")
            continue
        try:
            ET.parse(path)
        except ET.ParseError as exc:
            errors.append(f"{tag}: {name} is not well-formed XML ({exc})")

    rv = bundle_dir / "rvmetadata.xml"
    if rv.is_file():
        try:
            root = ET.parse(rv).getroot()
        except ET.ParseError:
            root = None
        if root is not None:
            abbr = (root.findtext("abbreviation") or "").strip()
            if abbr != entry["abbreviation"]:
                errors.append(
                    f"{tag}: rvmetadata abbreviation is {abbr!r}, manifest says "
                    f"{entry['abbreviation']!r}"
                )
            name = (root.findtext("name") or "").strip()
            if name != entry["name"]:
                errors.append(f"{tag}: rvmetadata name is {name!r}, manifest says {entry['name']!r}")

    usx = bundle_dir / "USX"
    if not usx.is_dir():
        errors.append(f"{tag}: missing USX/ folder")
        return

    found = set()
    for path in sorted(usx.iterdir()):
        if path.suffix != ".usx":
            warnings.append(f"{tag}: stray file in USX/: {path.name}")
            continue
        try:
            root = ET.parse(path).getroot()
        except ET.ParseError as exc:
            errors.append(f"{tag}: {path.name} is not well-formed XML ({exc})")
            continue
        book = root.find("book")
        code = book.get("code") if book is not None else None
        if code != path.stem:
            errors.append(f"{tag}: {path.name} declares book code {code!r}")
            continue
        found.add(code)

    for missing in [b for b in BOOKS if b not in found]:
        errors.append(f"{tag}: missing book {missing}")
    for extra in sorted(found - set(BOOKS)):
        warnings.append(f"{tag}: non-canonical book {extra}")

    if not (bundle_dir / "SearchIndex").is_dir():
        warnings.append(f"{tag}: no SearchIndex/ — ProPresenter rebuilds it on first search")


def main() -> int:
    manifest = json.loads((ROOT / "bibles.json").read_text())["bibles"]
    errors: list[str] = []
    warnings: list[str] = []

    for entry in manifest:
        bundle_dir = ROOT / "bibles" / entry["uuid"]
        if not bundle_dir.is_dir():
            errors.append(f"{entry['abbreviation']}: bibles/{entry['uuid']} does not exist")
            continue
        check(bundle_dir, entry, errors, warnings)

    known = {e["uuid"] for e in manifest}
    for path in sorted((ROOT / "bibles").iterdir()):
        if path.is_dir() and path.name not in known:
            warnings.append(f"bibles/{path.name} is not listed in bibles.json")

    for warning in warnings:
        print(f"warning: {warning}")
    for error in errors:
        print(f"ERROR: {error}")

    print(f"\n{len(manifest)} bundles checked, {len(errors)} errors, {len(warnings)} warnings")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
