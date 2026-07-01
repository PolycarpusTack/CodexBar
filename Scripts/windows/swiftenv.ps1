<#
.SYNOPSIS
  Set up the Swift-on-Windows + MSVC build environment in the current PowerShell session.

.DESCRIPTION
  `swift build` on Windows must run inside a Visual Studio Developer environment (so the MSVC
  `link.exe`/`cl.exe` are found) AND with the Swift toolchain/runtime on PATH and `SDKROOT` set.
  Enter-VsDevShell drops `SDKROOT`, so we restore it. DOT-SOURCE this before building:

      . .\Scripts\windows\swiftenv.ps1
      swift build --product CodexBarCLI          # links via committed Vendored\windows\x64\sqlite3.lib
      swift test --filter EngineContractV1       # tests run on Windows too

  Requires: Visual Studio (Build Tools) with the VC++ x64 workload; the Swift 6.x toolchain
  (winget Swift.Toolchain) which sets the User `SDKROOT`.

  Note: run natively (not via a redirected/piped host) or `vswhere` may not resolve — harmless
  "'vswhere.exe' is not recognized" lines can appear but the env still sets up (link.exe prints).
#>
$ErrorActionPreference = "Stop"
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vsPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
Import-Module (Join-Path $vsPath "Common7\Tools\Microsoft.VisualStudio.DevShell.dll")
Enter-VsDevShell -VsInstallPath $vsPath -SkipAutomaticLocation -DevCmdArguments "-arch=x64 -host_arch=x64" | Out-Null
# Ensure Swift toolchain + runtime on PATH (machine+user).
$machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
$env:Path = "$machinePath;$userPath;$env:Path"
# Restore Swift-specific vars that Enter-VsDevShell may have dropped.
$sdkroot = [Environment]::GetEnvironmentVariable("SDKROOT", "User")
if ($sdkroot) { $env:SDKROOT = $sdkroot }
Write-Host "swift:   $((Get-Command swift.exe -ErrorAction SilentlyContinue).Source)"
Write-Host "link:    $((Get-Command link.exe -ErrorAction SilentlyContinue).Source)"
Write-Host "SDKROOT: $env:SDKROOT"
