# Tedim (Chin) Bible for ProPresenter

Adds the Tedim (Chin) Bible, Chin 1977 Bible, Judson Burmese Bible, and King
James Version to ProPresenter.

## Install (Mac)

1. Open the
   [Releases page](https://github.com/khualbawi/tedim-bible-propresenter/releases/latest).
2. Scroll to the **Assets** list near the bottom of that page.
3. Click **TedimBibles.pkg** to download it.
4. Open your Downloads folder and find **TedimBibles.pkg**.
5. Hold Control, click the file, and choose **Open**.
6. Click **Open** again in the warning box. Your Mac only warns because we are
   not a paid Apple developer.
7. Click **Continue**, then **Install**, and type your Mac password when asked.
8. Quit ProPresenter completely with **Cmd+Q**.
9. Open ProPresenter again and look in the Bible view.
10. Repeat steps 8 and 9 once more if a bible is still missing.

## Install (Windows)

1. Open the
   [Releases page](https://github.com/khualbawi/tedim-bible-propresenter/releases/latest).
2. Scroll to the **Assets** list near the bottom of that page.
3. Click **TedimBibles-windows.zip** to download it.
4. Right-click the download and choose **Extract All**, then **Extract**.
5. Open the folder that appears.
6. Double-click **Install.bat**.
7. Click **Yes** when Windows asks for permission to make changes.
8. Click **More info**, then **Run anyway**, if a blue warning box appears.
9. Wait for the black window to say it is finished, then press any key.
10. Close ProPresenter completely, open it again, and look in the Bible view.

## Problems?

- **A bible is missing.** Quit ProPresenter and open it again, twice. It looks
  for new bibles only when it starts.
- **Still missing, or the words look old.** An older Tedim bible may already be
  installed. On a Mac, delete any `.rvbible` files with old Tedim names from
  both `/Library/Application Support/RenewedVision/RVBibles/v2` and
  `~/Library/Application Support/RenewedVision/RVBibles/v2`. On Windows, delete
  the old translation folders from
  `C:\ProgramData\RenewedVision\ProPresenter\Bibles`. Then install again.
- **Book names show in English.** Install the newest version from the Releases
  page again.

## What's included

| Code | Translation |
| --- | --- |
| `TDB` | Tedim (Chin) Bible |
| `TB77` | Chin 1977 (Tedim Bible) |
| `BJB` | Judson Bible (Burmese) |
| `KJV` | King James Version |

These translations are copyrighted by the **Myanmar Bible Society** and other
respective copyright holders. Contact the
[Myanmar Bible Society](https://www.myanmarbs.org/) for permission to reproduce
or distribute them.

## For developers

**Layout.** `bibles/<CODE>/` holds one bundle per translation — `metadata.xml`
(DBL 1.2), `rvmetadata.xml`, `USX/` and the legacy `USX_1/`, plus a
`SearchIndex/` where one exists. [`bibles.json`](bibles.json) maps each code to
the UUID folder name ProPresenter requires, with its name, language and
license. [`tools/`](tools) holds the build, install and validation scripts.

**macOS.** [`tools/install-macos.sh`](tools/install-macos.sh) builds the
`.rvbible` packages and copies them into both
`/Library/Application Support/RenewedVision/RVBibles/v2` and the same path under
`~`. It needs a Bible ProPresenter installed itself (the public-domain American
Standard Version) as a DBL 2.x metadata template — ProPresenter silently
rejects anything else. Both DBL 2 header shapes are accepted: the older
`<DBLMetadata id="…" revision="…" version="2.1">` and the
`<DBLMetadata version="2.2.1" id="…" revision="11">` that ProPresenter
downloads today; attribute order is never assumed. DBL 1.x is still rejected.
`DRY_RUN=1` shows what it would do, `RVBIBLE_TEMPLATE` names a template
instead of searching, and `RVBIBLE_DIST` builds somewhere other than `dist/`.
[`tools/build_rvbible.py`](tools/build_rvbible.py) does the same packaging in
Python; pass `--template <a .rvbible ProPresenter installed>`. A valid package
has its books under `release/USX_1/`.

**Windows.** [`tools/install-windows.ps1`](tools/install-windows.ps1) copies the
bundles into `C:\ProgramData\RenewedVision\ProPresenter\Bibles` and *merges*
entries into `InstalledBiblesNew` in `BibleData.proPref` (backing it up), rather
than replacing the file. `-WhatIf` and `-BiblesPath` are supported.
[`tools/Install.bat`](tools/Install.bat) is the double-click wrapper.

**Book names.** The template's metadata names the template's books, so both
build paths rewrite `<names>` from the bundle's own `<bookNames>`, falling back
to `\toc1`/`\toc2`/`\toc3`/`\h` in the USX headers. Those rules live only in
[`tools/localize-book-names.sh`](tools/localize-book-names.sh); the shell
installer sources it and `build_rvbible.py` runs it.

**Checks.** [`tools/check-build-parity.sh`](tools/check-build-parity.sh) builds
both ways and diffs the `<names>` sections; pass a real `.rvbible`, or let it
use the synthetic templates from
[`tools/make-test-template.sh`](tools/make-test-template.sh).
[`tools/test-metadata.sh`](tools/test-metadata.sh) runs those synthetic
templates — 2.1 and 2.2.1 headers, plus a 1.2 one that must be rejected —
through both build paths and asserts the bundle id is replaced, every other
`id` and the publication `<content>` map are left alone, and the book names are
localized in each `<names>` entry shape.
[`tools/validate.py`](tools/validate.py) checks structure, XML and book
coverage. All three run in CI.

**Releases.** Build the `.rvbible` files on a Mac with ProPresenter and commit
`dist/`. Push a `v*` tag:
[`.github/workflows/release.yml`](.github/workflows/release.yml) runs
[`tools/make-pkg.sh`](tools/make-pkg.sh) to wrap the committed `dist/` as
`TedimBibles.pkg`, zips the Windows layout as `TedimBibles-windows.zip`, and
attaches both plus the raw `.rvbible` files to the release. The pkg is unsigned;
`make-pkg.sh` carries a TODO with the signing and notarization commands.

## Credits

Original package and translation data by
[peterlianpi/Tedim-Chin-Bible](https://github.com/peterlianpi/Tedim-Chin-Bible).
