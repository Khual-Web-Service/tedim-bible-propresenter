<#
.SYNOPSIS
    Installs the Tedim (Chin) Bible bundles into ProPresenter 7 on Windows.

.DESCRIPTION
    Copies each bundle from bibles/ into the ProPresenter Bibles folder and
    MERGES its entry into BibleData.proPref, keeping every translation that is
    already installed. The old instructions told you to delete BibleData.proPref
    and drop a replacement in, which silently removed your other Bibles.

    Close ProPresenter before running, and run this from an elevated PowerShell
    prompt (ProgramData\RenewedVision usually needs administrator rights).

.PARAMETER BiblesPath
    Override the ProPresenter Bibles folder.

.PARAMETER WhatIf
    Show what would change without writing anything.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\install-windows.ps1
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$BiblesPath = (Join-Path $env:ProgramData 'RenewedVision\ProPresenter\Bibles')
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$manifest = Get-Content (Join-Path $repoRoot 'bibles.json') -Raw | ConvertFrom-Json

if (Get-Process -Name 'ProPresenter' -ErrorAction SilentlyContinue) {
    throw 'ProPresenter is running. Quit it first, then run this script again.'
}

if (-not (Test-Path $BiblesPath)) {
    if ($PSCmdlet.ShouldProcess($BiblesPath, 'Create Bibles folder')) {
        New-Item -ItemType Directory -Path $BiblesPath -Force | Out-Null
    }
}

$prefFile = Join-Path $BiblesPath 'BibleData.proPref'

# Read the entries that are already installed so nothing gets lost.
$entries = [System.Collections.Generic.List[string]]::new()
if (Test-Path $prefFile) {
    $backup = "$prefFile.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    if ($PSCmdlet.ShouldProcess($prefFile, "Back up to $(Split-Path -Leaf $backup)")) {
        Copy-Item $prefFile $backup
        Write-Host "Backed up existing BibleData.proPref to $backup"
    }
    $existing = Get-Content $prefFile -Raw
    if ($existing -match 'InstalledBiblesNew=\[(.*)\];') {
        foreach ($match in [regex]::Matches($Matches[1], '"([^"]*)"')) {
            $entries.Add($match.Groups[1].Value)
        }
    }
}

foreach ($bible in $manifest.bibles) {
    $source = Join-Path $repoRoot "bibles\$($bible.uuid)"
    $target = Join-Path $BiblesPath $bible.uuid

    if (-not (Test-Path $source)) {
        Write-Warning "Skipping $($bible.abbreviation): $source not found"
        continue
    }

    if ($PSCmdlet.ShouldProcess($target, "Install $($bible.abbreviation) - $($bible.name)")) {
        if (Test-Path $target) { Remove-Item $target -Recurse -Force }
        New-Item -ItemType Directory -Path $target -Force | Out-Null
        # USX_1 is only there for older ProPresenter builds; USX is what current
        # versions read, so the install stays lean. Copy-Item -Exclude does not
        # filter directories reliably, so the top level is walked by hand.
        Get-ChildItem -LiteralPath $source | Where-Object { $_.Name -ne 'USX_1' } |
            ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $target -Recurse -Force }
        Write-Host "Installed $($bible.abbreviation) - $($bible.name)"
    }

    # Drop any entry with the same UUID or the same abbreviation, then re-add.
    $stale = $entries | Where-Object {
        $parts = $_ -split '\|'
        $parts[0] -eq $bible.uuid -or $parts[1] -eq $bible.abbreviation
    }
    foreach ($item in @($stale)) { $entries.Remove($item) | Out-Null }
    $entries.Add("$($bible.uuid)|$($bible.abbreviation)|$($bible.name)|1")
}

$quoted = ($entries | ForEach-Object { '"' + $_ + '"' }) -join ','
$contents = "InstalledBiblesNew=[$quoted];"

if ($PSCmdlet.ShouldProcess($prefFile, 'Write merged BibleData.proPref')) {
    # ProPresenter reads this as plain ASCII - no BOM.
    [System.IO.File]::WriteAllText($prefFile, $contents, [System.Text.UTF8Encoding]::new($false))
    Write-Host "`nBibleData.proPref now lists $($entries.Count) translation(s)."
}

Write-Host 'Done. Start ProPresenter and open the Bible view.'
