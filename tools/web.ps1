<#
.SYNOPSIS
  Export the web build and serve it locally for testing in a browser.

.EXAMPLE
  .\tools\web.ps1            # export (debug) + serve on http://localhost:8060
  .\tools\web.ps1 -Release   # release export + serve
  .\tools\web.ps1 -NoExport  # just serve the last build
#>
param(
    [switch]$Release,
    [switch]$NoExport,
    [int]$Port = 8060
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$out = Join-Path $root "build\web"

# Make sure winget's godot aliases are visible even in old terminals
$env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")

if (-not $NoExport) {
    New-Item -ItemType Directory -Force $out | Out-Null
    $mode = if ($Release) { "--export-release" } else { "--export-debug" }
    Write-Host "Exporting web build ($mode) ..."
    & godot_console --headless --path (Join-Path $root "game") $mode "web" (Join-Path $out "index.html")
    if ($LASTEXITCODE -ne 0) { throw "Godot export failed (exit $LASTEXITCODE)" }
    $size = (Get-ChildItem $out -File | Measure-Object Length -Sum).Sum / 1MB
    Write-Host ("Build size: {0:N1} MB (uncompressed)" -f $size)
}

Write-Host "Serving $out at http://localhost:$Port  (Ctrl+C to stop)"
& py -3 -m http.server $Port --bind 127.0.0.1 --directory $out
