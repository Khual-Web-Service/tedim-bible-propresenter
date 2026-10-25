# Myanmar Bibles for ProPresenter

Adds 20 Bibles in Zomi/Zo, Chin, Mizo, Kuki, Kachin, Burmese and English to
ProPresenter 7 — free, with a double-click installer for Mac and Windows.

## Install (Mac)

1. Open the
   [Releases page](https://github.com/Khual-Web-Service/myanmar-bibles-propresenter/releases/latest).
2. Scroll to the **Assets** list near the bottom of that page.
3. Click **MyanmarBibles.pkg** to download it.
4. Open your Downloads folder and find **MyanmarBibles.pkg**.
5. Hold Control, click the file, and choose **Open**.
6. If your Mac says it cannot check the file for harmful software, click
   **Done**. Do **not** click **Move to Trash**.
7. Open **System Settings**, click **Privacy & Security**, and scroll all the
   way to the bottom.
8. Next to the message about **MyanmarBibles.pkg**, click **Open Anyway**.
9. Click **Open Anyway** once more in the box that appears, then type your Mac
   password. This warning is normal for free software that does not come from
   Apple, and you only see it the first time.
10. Click **Continue**, then **Install**, and type your Mac password when asked.
11. Quit ProPresenter completely with **Cmd+Q**.
12. Open ProPresenter again and look in the Bible view.
13. Repeat steps 11 and 12 once more if a bible is still missing.

## Install (Windows)

1. Open the
   [Releases page](https://github.com/Khual-Web-Service/myanmar-bibles-propresenter/releases/latest).
2. Scroll to the **Assets** list near the bottom of that page.
3. Click **MyanmarBibles-windows.zip** to download it.
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
- **Still missing, or the words look old.** An older copy of a bible may already be
  installed. On a Mac, delete any `.rvbible` files with old Tedim names from
  both `/Library/Application Support/RenewedVision/RVBibles/v2` and
  `~/Library/Application Support/RenewedVision/RVBibles/v2`. On Windows, delete
  the old translation folders from
  `C:\ProgramData\RenewedVision\ProPresenter\Bibles`. Then install again.
- **Book names show in English.** Install the newest version from the Releases
  page again.

## What's included

| Code | Translation | Language |
| --- | --- | --- |
| `TDB` | Tedim (Chin) Bible | Tedim |
| `TB77` | Chin 1977 (Tedim Bible) | Tedim |
| `SIZANG` | Lai Siangtho (Sizang 1932) | Sizang (Siyin) |
| `ZBI` | Lai Siengthou (Zou 1992) | Zo / Zou |
| `ZBM` | Zo Bible (Zou 2018) | Zo / Zou |
| `PAITE` | Paite Bible (1971) | Paite |
| `THADOU` | Pathen Thutheng Bu (Thadou 2015) | Thadou (Kuki) |
| `FALAM` | Baibal Thianghlim (Falam 1973) | Falam |
| `HAKHA` | Baibal Thiang (Hakha 1920) | Hakha (Lai) |
| `MARA` | Khazopa Chabu Pathaipa (Mara 2011) | Mara |
| `MATU` | Baibal Olcim (Matu Chin) | Matu |
| `MIZO` | Pathian Lehkhabu Thianghlim (Mizo 1917) | Mizo |
| `MIZOCL` | Common Language Bible (Mizo 1995) | Mizo |
| `JCLB` | Jinghpaw Common Language Bible (2009) | Jinghpaw (Kachin) |
| `JHVB` | Jinghpaw Hanson Version Bible (2009) | Jinghpaw (Kachin) |
| `BJB` | Judson Bible | Burmese |
| `MSV` | Myanmar Standard Version (2005) | Burmese |
| `MCL` | Myanmar Common Language (2005) | Burmese |
| `MNWT` | New World Translation (Burmese 2010) | Burmese |
| `KJV` | King James Version | English |

These translations are copyrighted by the **Bible Society of Myanmar**, the
**Bible Society of India** and other respective copyright holders; each
bundle's license line names its publisher. Contact the publisher (for example
the [Bible Society of Myanmar](https://www.myanmarbs.org/)) for permission to
reproduce or distribute them.

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
`MyanmarBibles.pkg`, zips the Windows layout as `MyanmarBibles-windows.zip`, and
attaches both plus the raw `.rvbible` files to the release. The pkg is unsigned;
`make-pkg.sh` carries a TODO with the signing and notarization commands.

## Credits

Original Tedim package by
[peterlianpi/Tedim-Chin-Bible](https://github.com/peterlianpi/Tedim-Chin-Bible).
The other translations come from
[laisiangtho/bible](https://github.com/laisiangtho/bible) and are converted with
[`tools/import_laisiangtho.py`](tools/import_laisiangtho.py):

```
git clone --depth 1 https://github.com/laisiangtho/bible ../laisiangtho-bible
python3 tools/import_laisiangtho.py ../laisiangtho-bible   # rewrites bibles/<CODE>/ and bibles.json
```

Matu comes from the eBible.org Matupi Chin Standard Bible instead, because the
laisiangtho copy has its New Testament books misnumbered. Pass
`--ebible <clone of github.com/BibleNLP/ebible>` to rebuild it.
