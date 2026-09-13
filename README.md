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

## For churches — easy install

Download one file, double-click it, done. No Terminal, no PowerShell, nothing
to type.

**Before you start:** quit ProPresenter. On a Mac press **Cmd+Q**; on Windows
close it and check it is not still in the taskbar.

Get the files from the
[latest release](https://github.com/khualbawi/tedim-bible-propresenter/releases/latest)
— the **Assets** list at the bottom of that page.

### Mac

1. Download **TedimBibles.pkg**.
2. Find it in your Downloads folder. **Right-click it and choose Open** — then
   click **Open** again in the box that appears. (A normal double-click shows
   "cannot be opened because it is from an unidentified developer". The
   right-click is what gets past that.)
3. Click through **Continue** and **Install**, and type your Mac password when
   it asks.
4. Open ProPresenter and look in the Bible view.

### Windows

1. Download **TedimBibles-windows.zip**.
2. Right-click the download and choose **Extract All**, then open the folder it
   makes.
3. Double-click **Install.bat**. Windows asks for permission to make changes —
   click **Yes**. (If a blue "Windows protected your PC" box appears, click
   **More info**, then **Run anyway**.)
4. A black window does the work and tells you when it is finished. Press a key
   to close it.
5. Open ProPresenter and look in the Bible view.

### If a translation is missing

**Quit ProPresenter completely and open it again** — Cmd+Q on a Mac, or close
it from the taskbar on Windows. It only looks for new Bibles when it starts.
Sometimes it takes two full restarts before they all appear.

If a translation still shows the old text, an older copy of it is probably
installed under a different name. The Mac installer removes the ones we know
about; for anything else, see the troubleshooting notes further down.

---

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
- **Each bundle has a canonical `USX/` folder.** Both `USX/` and the legacy
  `USX_1/` are kept in the repo; the macOS packages copy the books to
  `release/USX_1/`, which is where ProPresenter reads them inside a `.rvbible`,
  and the Windows install uses the folders as they are.
- **macOS is supported.** ProPresenter on macOS picks up `.rvbible` packages, so
  `tools/build_rvbible.py` produces them and `tools/install-macos.sh` installs
  them. The packages put the books under `release/USX_1/` and carry DBL 2.1
  metadata — ProPresenter rejects anything else, mostly silently.
- **Metadata is valid XML.** Two bundles were missing their XML declaration, and
  the abbreviations now match the translations they describe.

## For developers

Everything below is the manual route: a checkout, a terminal, and the scripts
that build and install from it.

### Get the files first

Every command below runs **from inside a copy of this repository**, not from your
home folder. Two ways to get one:

**No developer tools needed** — on the
[repository page](https://github.com/khualbawi/tedim-bible-propresenter), click
the green **Code** button, then **Download ZIP**. Double-click the download to
unpack it. In Terminal, type `cd ` (with a space) and drag the unpacked folder
onto the Terminal window, then press Return.

**Or, if you already have git:**

```
git clone https://github.com/khualbawi/tedim-bible-propresenter.git
cd tedim-bible-propresenter
```

On a Mac without the Xcode command line tools, `git` will pop up an installer
prompt instead of cloning. You do not need it — use the ZIP download above. The
macOS installer runs on a stock Mac, with no Python and no Xcode tools.

Type the commands themselves — the ``` fences around the code blocks in this
README are formatting, not part of any command. If your prompt changes to
`bquote>` or `dquote>`, a fence got pasted by mistake: press Ctrl+C and try
again.

Then quit ProPresenter, on either platform.

### Windows, from a checkout

Run from an elevated PowerShell prompt:

```powershell
powershell -ExecutionPolicy Bypass -File tools\install-windows.ps1
```

Add `-WhatIf` to see what it would change without writing anything, or
`-BiblesPath <path>` if your Bibles folder is not the default
`C:\ProgramData\RenewedVision\ProPresenter\Bibles`.

### macOS, from a checkout

```bash
DRY_RUN=1 tools/install-macos.sh   # see what it would do, change nothing
tools/install-macos.sh             # install
```

**Install any free Bible from ProPresenter's Options > Bibles first** (the
public-domain *American Standard Version* is the one the script looks for).
ProPresenter only accepts its own metadata format, so the installer copies the
package structure out of a Bible ProPresenter installed itself, swaps in our
books, and rewrites the name and abbreviation. Without one on the machine it
stops and says so.

It builds the packages with `/usr/bin/zip`, which every Mac already has, and
copies them into **both**
`/Library/Application Support/RenewedVision/RVBibles/v2` and
`~/Library/Application Support/RenewedVision/RVBibles/v2`, because some installs
read only one of them and nothing in ProPresenter says which. It only reaches
for `sudo` where the destination needs it. Pass a folder as the first argument
to install into that one instead.

Then start ProPresenter and open the Bible view.

#### If a translation does not appear

- **Quit ProPresenter completely with Cmd+Q and start it again** — a window
  close is not enough; it indexes Bibles on launch. Occasionally it takes two
  full relaunches.
- **Delete any older copy of the same translation first.** If a previous
  package is installed under a different filename — for example
  `Tedim_Bible_Revision_2017.rvbible` — ProPresenter hides the duplicate and you
  keep seeing the old text. Remove it from *both* `RVBibles/v2` folders (the one
  under `/Library` and the one under `~/Library`), then run the installer again.
- **"We don't handle the file type"** means the package layout is wrong. A good
  package lists `release/USX_1/…` under `unzip -l dist/TDB.rvbible`; if yours
  does not, you are running an older copy of this repository.

### Manual install

Prefer to do it by hand?

- **macOS** — copy `dist/*.rvbible` into
  `/Library/Application Support/RenewedVision/RVBibles/v2` *and*
  `~/Library/Application Support/RenewedVision/RVBibles/v2`. Build them with
  `python3 tools/build_rvbible.py --template <a .rvbible ProPresenter
  installed>` — without `--template` the metadata is not in the DBL 2.1 form
  ProPresenter parses, and it will ignore the Bible. Packages built this way
  are equivalent to the installer's, book names included.
- **Windows** — copy each folder from `bibles/` into
  `C:\ProgramData\RenewedVision\ProPresenter\Bibles`, then add one entry per
  translation to the `InstalledBiblesNew` array in `BibleData.proPref`, in the
  form `"<uuid>|<code>|<name>|1"`. Keep the entries that are already there.

### Building the installers

```bash
tools/make-pkg.sh          # dist/TedimBibles.pkg, from the packages in dist/
```

`make-pkg.sh` needs macOS (`pkgbuild` and `productbuild`) and wraps whatever is
already in `dist/` — it never builds the `.rvbible` files itself, because that
needs a real ProPresenter template. Build those first on a Mac that has
ProPresenter, with `tools/install-macos.sh`, and commit `dist/` so a release can
use them.

The pkg installs into `/Library/.../RVBibles/v2` and its postinstall script
copies the same files into the console user's `~/Library/.../RVBibles/v2`,
resolving that user from `/dev/console` rather than `$USER`, which is `root`
during an install. It also deletes the older filenames these translations used
to ship under, since ProPresenter hides duplicates.

The pkg is unsigned for now — `make-pkg.sh` carries a TODO with the Developer ID
signing and notarization commands.

`.github/workflows/release.yml` runs on a `v*` tag: it builds the pkg on a macOS
runner from the committed `dist/`, zips the Windows layout (`Install.bat`,
`tools/install-windows.ps1`, `bibles/`, `bibles.json`), and attaches the pkg, the
zip and the raw `.rvbible` files to the release.

## Repository layout

```
bibles/TDB/             one folder per translation, named by its code
  metadata.xml          DBL metadata (book names, language, scope)
  rvmetadata.xml        ProPresenter metadata (name, abbreviation, license)
  USX/                  one USX file per book, read by current ProPresenter
  USX_1/                same books under the legacy folder name
  SearchIndex/          prebuilt search index, where one exists
bibles/TB77/            likewise, and BJB/ and KJV/
bibles.json             manifest: code, UUID, name, language, license
tools/                  build, install and validation scripts
  make-pkg.sh             wraps dist/ as TedimBibles.pkg (macOS only)
  Install.bat             double-click entry point for Windows
  localize-book-names.sh  shared book-name rewrite, used by both build paths
  check-build-parity.sh   diffs what the two build paths produce
```

ProPresenter requires each installed Bible to sit in a folder named for its
UUID, which makes for an unreadable repository. The folders here are named for
the translation instead, and the installers rename to the UUID on the way in —
`bibles.json` holds the mapping.

## Development

```bash
python3 tools/validate.py        # check structure, XML and book coverage
python3 tools/build_rvbible.py   # write dist/*.rvbible
python3 tools/build_rvbible.py --template ~/Library/Application\ Support/RenewedVision/RVBibles/v2/publicdomain_American_Standard_Version.rvbible
```

A `.rvbible` is a zip of `metadata.xml`, `rvmetadata.xml` and a `release/`
folder holding `USX_1/`, `styles.xml`, `versification.vrs` and an `.ldml` file.
`metadata.xml` must be DBL 2.1; the `bibles/*/metadata.xml` files here are DBL
1.2, so `--template` reuses the metadata of a Bible ProPresenter installed and
swaps in our name, abbreviation and a fresh id. `tools/install-macos.sh` finds
such a template by itself.

The template's metadata also names the template's books, so both build paths
rewrite the `<names>` section with the local names out of `<bookNames>` in the
bundle's own `metadata.xml`, falling back to the `\toc1`/`\toc2`/`\toc3`/`\h`
lines in the USX headers. Those rules live in `tools/localize-book-names.sh`
alone: the shell installer sources it, `build_rvbible.py` runs it. To prove the
two paths have not drifted, build both ways and diff what they produce:

```bash
tools/check-build-parity.sh <a .rvbible ProPresenter installed>
```

It reports each translation as identical or prints the difference. It needs a
template, so it is not part of CI.

## Credits

Original package and translation data by
[peterlianpi/Tedim-Chin-Bible](https://github.com/peterlianpi/Tedim-Chin-Bible).
