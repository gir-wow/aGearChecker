# deploy.ps1 — Copy aGearCheck addon files into the WoW MoP Classic AddOns folder.
# Run from anywhere. Requires Administrator if WoW is in Program Files.
#
# Usage:  .\scripts\deploy.ps1
#         .\scripts\deploy.ps1 -Destination "D:\Games\WoW\_classic_\Interface\AddOns\aGearCheck"

param(
    [string]$Source      = "C:\git\aGearCheck",
    [string]$Destination = "C:\Program Files (x86)\World of Warcraft\_classic_\Interface\AddOns\aGearCheck"
)

# Only these directories / files belong in the addon
$addonDirs  = @("Compat", "Core", "Data", "UI")
$addonFiles = @("aGearCheck.toc", "aGearCheck.lua")

# Clean previous deploy
if (Test-Path $Destination) {
    Remove-Item $Destination -Recurse -Force
}
New-Item -ItemType Directory -Path $Destination -Force | Out-Null

# Copy top-level addon files
foreach ($file in $addonFiles) {
    $src = Join-Path $Source $file
    if (Test-Path $src) {
        Copy-Item $src (Join-Path $Destination $file) -Force
    } else {
        Write-Warning "Missing file: $src"
    }
}

# Copy addon sub-directories
foreach ($dir in $addonDirs) {
    $srcDir = Join-Path $Source $dir
    if (Test-Path $srcDir) {
        Copy-Item $srcDir (Join-Path $Destination $dir) -Recurse -Force
    }
}

Write-Host "Deployed aGearCheck to $Destination" -ForegroundColor Green
