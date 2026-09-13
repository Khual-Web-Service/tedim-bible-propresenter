#!/usr/bin/env python3
"""Package each bundle in bibles/ as a .rvbible file in dist/.

A .rvbible is a plain zip of the *contents* of a bible folder — metadata.xml
sits at the root of the archive, not inside a subfolder. Current ProPresenter
versions import these directly (Mac: drop into the Bibles folder; Windows:
unzip into a UUID folder — see tools/install-windows.ps1).

Usage: python3 tools/build_rvbible.py [--out dist]
"""
import argparse
import hashlib
import json
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
# USX_1 is the legacy folder name; it is kept in the repo for older
# ProPresenter builds but left out of the package to halve its size.
SKIP_DIRS = {"USX_1"}


def build(bundle_dir: Path, target: Path) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(bundle_dir.rglob("*")):
            if not path.is_file():
                continue
            rel = path.relative_to(bundle_dir)
            if rel.parts[0] in SKIP_DIRS:
                continue
            archive.write(path, rel.as_posix())


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", default="dist", help="output directory (default: dist)")
    args = parser.parse_args()

    out_dir = ROOT / args.out
    manifest = json.loads((ROOT / "bibles.json").read_text())["bibles"]

    for entry in manifest:
        bundle_dir = ROOT / "bibles" / entry["uuid"]
        target = out_dir / f"{entry['abbreviation']}.rvbible"
        build(bundle_dir, target)
        digest = hashlib.sha256(target.read_bytes()).hexdigest()
        size_mb = target.stat().st_size / (1024 * 1024)
        print(f"{target.relative_to(ROOT)}  {size_mb:6.1f} MB  sha256:{digest[:16]}…")


if __name__ == "__main__":
    main()
