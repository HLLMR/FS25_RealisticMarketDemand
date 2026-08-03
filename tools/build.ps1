<#
.SYNOPSIS
    Package Realistic Market Demand into a ModHub-ready ZIP.

.DESCRIPTION
    Produces dist/FS25_RealisticMarketDemand.zip with modDesc.xml at the archive
    ROOT (required by FS25) and only the runtime files — excluding tests, docs,
    dev configs, git metadata, and this build script.

    Also prints a release-readiness checklist. Blockers (debug logging left on, a
    missing icon, malformed modDesc) are reported but do NOT rename the archive:
    the zip name must stay exactly FS25_RealisticMarketDemand.zip for the game to
    recognize the mod. Fix blockers before submitting to ModHub.

.PARAMETER AllowDevBuild
    Build even when release-readiness checks fail (for local iteration). Without
    it, a failed check exits non-zero so the build fails closed.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\build.ps1
    powershell -ExecutionPolicy Bypass -File tools\build.ps1 -AllowDevBuild
#>

param([switch]$AllowDevBuild)

$ErrorActionPreference = 'Stop'

$modName = 'FS25_RealisticMarketDemand'
$root    = Split-Path -Parent $PSScriptRoot   # tools\ -> repo root
$distDir = Join-Path $root 'dist'
$outZip  = Join-Path $distDir "$modName.zip"

Write-Host "Packaging $modName ..." -ForegroundColor Cyan

# --- Read version from modDesc.xml -----------------------------------------
$modDescPath = Join-Path $root 'modDesc.xml'
if (-not (Test-Path $modDescPath)) { throw "modDesc.xml not found at $modDescPath" }

[xml]$modDesc = Get-Content $modDescPath -Raw   # also validates well-formedness
$version = $modDesc.modDesc.version
Write-Host "  version: $version"

# --- Assemble the include list (allowlist): @{ src; entry } -----------------
# entry paths use forward slashes so the archive is correct on Linux dedicated
# servers and mod tooling, not just Windows.
# NOTE: LICENSE is intentionally NOT bundled — the game doesn't load it, so the
# TestRunner's ObsoleteFiles module flags it. It stays in the repo (GitHub).
$files = @()
$files += @{ src = $modDescPath; entry = 'modDesc.xml' }

Get-ChildItem (Join-Path $root 'scripts') -Filter '*.lua' -File | ForEach-Object {
    $files += @{ src = $_.FullName; entry = "scripts/$($_.Name)" }
}

$iconPath = Join-Path $root 'icon_RealisticMarketDemand.dds'
$hasIcon = Test-Path $iconPath
if ($hasIcon) { $files += @{ src = $iconPath; entry = 'icon_RealisticMarketDemand.dds' } }

$l10nPath = Join-Path $root 'l10n'
if (Test-Path $l10nPath) {
    Get-ChildItem $l10nPath -Recurse -File | ForEach-Object {
        $rel = $_.FullName.Substring($l10nPath.Length + 1) -replace '\\', '/'
        $files += @{ src = $_.FullName; entry = "l10n/$rel" }
    }
}

# --- Build the archive (.NET, forward-slash entries) ------------------------
if (-not (Test-Path $distDir)) { New-Item -ItemType Directory -Path $distDir | Out-Null }
if (Test-Path $outZip) { Remove-Item $outZip -Force }

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::Open($outZip, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($f in $files) {
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $archive, $f.src, $f.entry,
            [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
    }
} finally {
    $archive.Dispose()
}
Write-Host "  wrote: $outZip" -ForegroundColor Green

# --- Show archive contents --------------------------------------------------
$zip = [System.IO.Compression.ZipFile]::OpenRead($outZip)
Write-Host "`nArchive contents:"
$zip.Entries | ForEach-Object { Write-Host ("  {0}" -f $_.FullName) }
$hasRootModDesc = @($zip.Entries | Where-Object { $_.FullName -eq 'modDesc.xml' }).Count -eq 1
$zip.Dispose()

# --- Release-readiness checklist -------------------------------------------
function Check($ok, $label) {
    if ($ok) { Write-Host "  [PASS] $label" -ForegroundColor Green }
    else     { Write-Host "  [FAIL] $label" -ForegroundColor Yellow }
    return $ok
}

Write-Host "`nRelease readiness:"
$allOk = $true
$allOk = (Check $hasRootModDesc 'modDesc.xml at archive root') -and $allOk
$allOk = (Check $hasIcon 'icon_RealisticMarketDemand.dds present') -and $allOk

$debugOn = Select-String -Path (Join-Path $root 'scripts\RMDLogging.lua') `
    -Pattern 'RMDLogging\.debugEnabled\s*=\s*true' -Quiet
$allOk = (Check (-not $debugOn) 'debug logging OFF (RMDLogging.debugEnabled = false)') -and $allOk

if ($allOk) {
    Write-Host "`nModHub-ready." -ForegroundColor Green
} elseif ($AllowDevBuild) {
    Write-Host "`nDev build (-AllowDevBuild) - resolve [FAIL] items before submitting to ModHub." -ForegroundColor Yellow
} else {
    Write-Host "`nRelease readiness FAILED - fix the [FAIL] items, or pass -AllowDevBuild for local iteration." -ForegroundColor Red
    exit 1
}
