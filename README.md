# Tedim (Chin) Bible for ProPresenter 7

Tedim (Chin) Bible translations packaged for current ProPresenter 7 releases on
Windows and macOS.

| Code | Translation | Language |
| --- | --- | --- |
| `TDB` | Tedim (Chin) Bible | Chin: Tedim (`ctd`) |
| `TB77` | Chin 1977 (Tedim Bible) | Chin: Tedim (`ctd`) |
| `BJB` | Judson Bible | Burmese (`mya`) |
| `KJV` | King James Version | English (`eng`) |

## Copyright

These translations are copyrighted by the **Myanmar Bible Society** and other
respective copyright holders. Contact the
[Myanmar Bible Society](https://www.myanmarbs.org/) for permission to reproduce
or distribute them.

## What changed from the older package

The earlier version of this package was built for ProPresenter 7 as it shipped
around 2023, and it worked by overwriting files ProPresenter owns. That is what
broke on newer releases:

- **The Tedim versions no longer hijack `RVA` and `YLT`.** They used to be
  installed under the Reina-Valera Antigua and Young's Literal Translation
  codes, which removed those translations and let ProPresenter's own Bible
  library overwrite the Tedim text. `TDB` and `TB77` are now their own
  translations, with their own UUIDs, and they sit alongside anything else you
  have installed.
- **`BibleData.proPref` is merged, not replaced.** The old instructions said to
  delete the file and paste a new one in, which silently uninstalled every other
  Bible. `tools/install-windows.ps1` reads the existing entries, backs the file
  up, and adds these translations to the list.
- **Each bundle has a canonical `USX/` folder.** Current ProPresenter reads
  `USX/`; the legacy `USX_1/` folder is still in the repo for older builds but is
  left out of what gets installed.
- **macOS is supported.** ProPresenter on macOS picks up `.rvbible` packages, so
  `tools/build_rvbible.py` produces them and `tools/install-macos.sh` installs
  them.
- **Metadata is valid XML.** Two bundles were missing their XML declaration, and
  the abbreviations now match the translations they describe.

## Install

Quit ProPresenter first, on either platform.

### Windows

Run from an elevated PowerShell prompt, in a clone of this repository:

```powershell
powershell -ExecutionPolicy Bypass -File tools\install-windows.ps1
```

Add `-WhatIf` to see what it would change without writing anything, or
`-BiblesPath <path>` if your Bibles folder is not the default
`C:\ProgramData\RenewedVision\ProPresenter\Bibles`.

### macOS

```bash
DRY_RUN=1 tools/install-macos.sh   # see what it would do, change nothing
tools/install-macos.sh             # install
```

ProPresenter stores each Bible on macOS as a `.rvbible` package — the same
format its own Bible downloads use — so it registers them itself and there is no
preference file to edit, unlike on Windows.

The script builds the packages and copies them into
`/Library/Application Support/RenewedVision/RVBibles/v2`, falling back to
`~/Library/Application Support/RenewedVision/RVBibles/v2` if that is where your
install keeps them. It only reaches for `sudo` if the destination needs it. Pass
a different folder as the first argument to override both.

Then start ProPresenter and open the Bible view. If a translation does not
appear, restart ProPresenter once more — it indexes new Bibles on launch.

### Manual install

Prefer to do it by hand? Build the packages with
`python3 tools/build_rvbible.py`, then:

- **macOS** — copy `dist/*.rvbible` into
  `/Library/Application Support/RenewedVision/RVBibles/v2`.
- **Windows** — copy each folder from `bibles/` into
  `C:\ProgramData\RenewedVision\ProPresenter\Bibles`, then add one entry per
  translation to the `InstalledBiblesNew` array in `BibleData.proPref`, in the
  form `"<uuid>|<code>|<name>|1"`. Keep the entries that are already there.

## Repository layout

```
bibles/<uuid>/          one folder per translation, named by UUID
  metadata.xml          DBL metadata (book names, language, scope)
  rvmetadata.xml        ProPresenter metadata (name, abbreviation, license)
  USX/                  one USX file per book, read by current ProPresenter
  USX_1/                same books under the legacy folder name
  SearchIndex/          prebuilt search index, where one exists
bibles.json             manifest: UUID, code, name, language, license
tools/                  build, install and validation scripts
```

## Development

```bash
python3 tools/validate.py        # check structure, XML and book coverage
python3 tools/build_rvbible.py   # write dist/*.rvbible
```

`validate.py` checks that every bundle has well-formed metadata, that each USX
file declares the book code its filename claims, and that all 66 books are
present.

Both run in CI on every push and pull request
(`.github/workflows/validate.yml`), which also uploads the built `.rvbible`
packages as a workflow artifact — so you can download them from a run instead
of building them locally.

## Credits

Original package and translation data by
[peterlianpi/Tedim-Chin-Bible](https://github.com/peterlianpi/Tedim-Chin-Bible).
