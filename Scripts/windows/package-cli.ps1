<#
.SYNOPSIS
  Package CodexBarCLI.exe with the Swift runtime DLLs into a self-contained folder
  so it runs on a clean Windows 10+ machine (no Swift toolchain required).

.DESCRIPTION
  Copies the built CodexBarCLI.exe and the Swift Windows runtime DLLs into -OutDir.
  The api-ms-win-crt-* dependencies are part of the OS Universal CRT (Windows 10+);
  the VC++ runtime DLLs (vcruntime140/msvcp140) ARE bundled from the Swift runtime dir.

.PARAMETER Config
  Build configuration folder under .build (debug|release). Default: debug.

.PARAMETER RuntimeDir
  Swift Windows runtime bin dir. Auto-discovered from the Swift install if omitted.

.PARAMETER OutDir
  Output folder. Default: dist\windows.

.EXAMPLE
  pwsh scripts\windows\package-cli.ps1
  pwsh scripts\windows\package-cli.ps1 -Config release -OutDir C:\ship\codexbar
#>
[CmdletBinding()]
param(
    [string]$Config = "debug",
    [string]$RuntimeDir,
    [string]$OutDir
)
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$exe = Join-Path $repoRoot ".build\$Config\CodexBarCLI.exe"
if (-not (Test-Path $exe)) {
    throw "CodexBarCLI.exe not found at $exe. Build first: swift build --product CodexBarCLI"
}

# Auto-discover the Swift runtime bin dir if not supplied.
if (-not $RuntimeDir) {
    $candidates = @(
        (Get-ChildItem "$env:LOCALAPPDATA\Programs\Swift\Runtimes\*\usr\bin" -Directory -ErrorAction SilentlyContinue),
        (Get-ChildItem "C:\Library\Developer\Toolchains\*\usr\bin" -Directory -ErrorAction SilentlyContinue)
    ) | ForEach-Object { $_ } | Where-Object { $_ -and (Test-Path (Join-Path $_.FullName "swiftCore.dll")) }
    if (-not $candidates) { throw "Could not auto-discover the Swift runtime dir; pass -RuntimeDir." }
    $RuntimeDir = ($candidates | Sort-Object FullName -Descending | Select-Object -First 1).FullName
}
if (-not (Test-Path (Join-Path $RuntimeDir "swiftCore.dll"))) {
    throw "RuntimeDir '$RuntimeDir' has no swiftCore.dll."
}

if (-not $OutDir) { $OutDir = Join-Path $repoRoot "dist\windows" }
New-Item -ItemType Directory -Force $OutDir | Out-Null

Copy-Item $exe (Join-Path $OutDir "CodexBarCLI.exe") -Force
$dlls = Get-ChildItem $RuntimeDir -Filter *.dll
foreach ($d in $dlls) { Copy-Item $d.FullName (Join-Path $OutDir $d.Name) -Force }

Write-Host "Packaged CodexBarCLI.exe + $($dlls.Count) runtime DLLs -> $OutDir"
Write-Host "Runtime source: $RuntimeDir"
