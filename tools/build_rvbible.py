#!/usr/bin/env python3
"""Package each bundle in bibles/ as a .rvbible file in dist/.

A .rvbible is a zip, but not a zip of the bundle as it sits in this repository.
ProPresenter 7 rejects a package whose books are at the root ("We don't handle
the file type"); what it accepts looks like:

    metadata.xml
    rvmetadata.xml
    release/USX_1/GEN.usx …
    release/styles.xml
    release/versification.vrs
    release/*.ldml

metadata.xml also has to be DBL 2.1 (<DBLMetadata id="…" revision="…"
version="2.1">). The files in bibles/ are DBL 1.2, which ProPresenter does not
parse, so pass --template pointing at any .rvbible ProPresenter installed
itself: its metadata is reused with the identifying fields swapped for ours.
That is what tools/install-macos.sh does automatically.

Without --template the layout is still correct, but the metadata is only an
attribute-level rewrite of our own 1.2 file — useful for inspection and CI, not
verified against ProPresenter.

Usage:
  python3 tools/build_rvbible.py [--out dist] [--template path/to/x.rvbible]
"""
import argparse
import hashlib
import json
import re
import secrets
import shutil
import tempfile
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
# Books go here inside the package, whichever folder they came from.
BOOKS_IN_PACKAGE = "release/USX_1"
RELEASE_EXTRAS = ("styles.xml", "versification.vrs")


def bundle_books(bundle_dir: Path) -> Path:
    for name in ("USX", "USX_1"):
        candidate = bundle_dir / name
        if candidate.is_dir():
            return candidate
    raise SystemExit(f"{bundle_dir.name}: no USX/ or USX_1/ folder")


def read_rvmetadata(bundle_dir: Path) -> dict:
    text = (bundle_dir / "rvmetadata.xml").read_text(encoding="utf-8")

    def field(tag: str) -> str:
        match = re.search(rf"<{tag}>(.*?)</{tag}>", text, re.S)
        return match.group(1).strip() if match else ""

    return {
        "name": field("name") or bundle_dir.name,
        "abbreviation": field("abbreviation") or bundle_dir.name,
    }


def xml_escape(value: str) -> str:
    return value.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def rewrite_metadata(metadata: str, info: dict) -> str:
    """Point a DBL metadata document at this translation.

    Only the first id="…" is the bundle id — later ones belong to book and name
    entries — and only the first of each identification field is replaced, for
    the same reason.
    """
    name = xml_escape(info["name"])
    abbr = xml_escape(info["abbreviation"])

    metadata = re.sub(r'id="[0-9a-fA-F]+"', f'id="{secrets.token_hex(8)}"', metadata, count=1)
    for tag, value in (
        ("name", name),
        ("nameLocal", name),
        ("description", name),
        ("abbreviation", abbr),
        ("abbreviationLocal", abbr),
    ):
        metadata = re.sub(rf"<{tag}>[^<]*</{tag}>", f"<{tag}>{value}</{tag}>", metadata, count=1)
    return metadata


def upgrade_metadata_header(metadata: str) -> str:
    """Best-effort DBL 1.2 -> 2.1 header, for builds without a template."""

    def fix(match: re.Match) -> str:
        tag = match.group(0)
        if 'version="2.1"' in tag:
            return tag
        # 2.1 dropped the type/typeVersion pair in favour of a version attribute.
        tag = re.sub(r'\s+type(Version)?="[^"]*"', "", tag)
        return tag.rstrip(">").rstrip() + ' version="2.1">'

    return re.sub(r"<DBLMetadata\b[^>]*>", fix, metadata, count=1)


def stage(bundle_dir: Path, work: Path, template_dir: Path | None) -> Path:
    staged = work / bundle_dir.name
    if template_dir is not None:
        shutil.copytree(template_dir, staged)
        shutil.rmtree(staged / BOOKS_IN_PACKAGE, ignore_errors=True)
    else:
        staged.mkdir(parents=True)
    (staged / BOOKS_IN_PACKAGE).mkdir(parents=True, exist_ok=True)

    for book in sorted(bundle_books(bundle_dir).glob("*.usx")):
        shutil.copy2(book, staged / BOOKS_IN_PACKAGE / book.name)

    # The bundle's own release files win over the template's, where it has them.
    for extra in RELEASE_EXTRAS:
        if (bundle_dir / extra).is_file():
            shutil.copy2(bundle_dir / extra, staged / "release" / extra)
    for ldml in sorted(bundle_dir.glob("*.ldml")):
        for stale in (staged / "release").glob("*.ldml"):
            stale.unlink()
        shutil.copy2(ldml, staged / "release" / ldml.name)

    shutil.copy2(bundle_dir / "rvmetadata.xml", staged / "rvmetadata.xml")
    if (bundle_dir / "license.xml").is_file():
        shutil.copy2(bundle_dir / "license.xml", staged / "license.xml")

    info = read_rvmetadata(bundle_dir)
    if template_dir is not None:
        metadata = (staged / "metadata.xml").read_text(encoding="utf-8")
    else:
        metadata = upgrade_metadata_header(
            (bundle_dir / "metadata.xml").read_text(encoding="utf-8")
        )
    (staged / "metadata.xml").write_text(rewrite_metadata(metadata, info), encoding="utf-8")
    return staged


def zip_dir(source: Path, target: Path) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(source.rglob("*")):
            if path.is_file() and path.name != ".DS_Store":
                archive.write(path, path.relative_to(source).as_posix())


def unpack_template(template: Path, work: Path) -> Path:
    with zipfile.ZipFile(template) as archive:
        names = archive.namelist()
        if not any(n.startswith(f"{BOOKS_IN_PACKAGE}/") for n in names):
            raise SystemExit(f"{template}: not a usable template, it has no {BOOKS_IN_PACKAGE}/")
        if 'version="2.1"' not in archive.read("metadata.xml").decode("utf-8", "replace"):
            raise SystemExit(f"{template}: metadata.xml is not DBL 2.1")
        target = work / "template"
        archive.extractall(target)
    return target


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", default="dist", help="output directory (default: dist)")
    parser.add_argument(
        "--template",
        help="a .rvbible ProPresenter installed, whose DBL 2.1 metadata is reused",
    )
    args = parser.parse_args()

    out_dir = ROOT / args.out
    manifest = json.loads((ROOT / "bibles.json").read_text())["bibles"]

    with tempfile.TemporaryDirectory() as tmp:
        work = Path(tmp)
        template_dir = unpack_template(Path(args.template), work) if args.template else None
        if template_dir is None:
            print(
                "No --template given: packages will have the right layout but "
                "metadata ProPresenter has not been verified to accept.\n"
                "On macOS run tools/install-macos.sh, which finds a template itself."
            )

        for entry in manifest:
            bundle_dir = ROOT / "bibles" / entry["abbreviation"]
            target = out_dir / f"{entry['abbreviation']}.rvbible"
            zip_dir(stage(bundle_dir, work, template_dir), target)

            with zipfile.ZipFile(target) as archive:
                assert any(
                    n.startswith(f"{BOOKS_IN_PACKAGE}/") for n in archive.namelist()
                ), f"{target}: built without {BOOKS_IN_PACKAGE}/"

            digest = hashlib.sha256(target.read_bytes()).hexdigest()
            size_mb = target.stat().st_size / (1024 * 1024)
            print(f"{target.relative_to(ROOT)}  {size_mb:6.1f} MB  sha256:{digest[:16]}…")


if __name__ == "__main__":
    main()
