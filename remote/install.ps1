# FastUpTV - one-line installer for Windows
#
#   irm https://raw.githubusercontent.com/dualwarez/FastUpTV/main/remote/install.ps1 | iex
#
# Downloads the latest release, unpacks it to %LOCALAPPDATA%\FastUpTV and runs the setup.
# Add -DryRun to only show the plan.
param(
    [switch]$DryRun
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$repo = 'dualwarez/FastUpTV'
$base = $env:LOCALAPPDATA
if (-not $base) { $base = Join-Path $env:USERPROFILE 'AppData\Local' }
$dest = Join-Path $base 'FastUpTV'
$zip  = Join-Path $env:TEMP 'FastUpTV-latest.zip'

Write-Host ""
Write-Host "  FastUpTV installer" -ForegroundColor Cyan
Write-Host "  ------------------------------" -ForegroundColor DarkGray

Write-Host "  latest release dhoondh rahe hain ..."
$rel = Invoke-RestMethod "https://api.github.com/repos/$repo/releases/latest" -Headers @{ 'User-Agent' = 'FastUpTV' }
$asset = $rel.assets | Where-Object { $_.name -like 'FastUpTV-*.zip' } | Select-Object -First 1
if (-not $asset) { throw "release mein zip nahi mila - https://github.com/$repo/releases" }
Write-Host ("  " + $asset.name + " (" + [math]::Round($asset.size / 1MB, 1) + " MB)")

Write-Host "  download ..."
Invoke-WebRequest $asset.browser_download_url -OutFile $zip
if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
Expand-Archive -Path $zip -DestinationPath $dest -Force
Remove-Item $zip -Force
Write-Host "  extract: $dest" -ForegroundColor DarkGray

Set-Location $dest
if (-not (Test-Path (Join-Path $dest 'tools\platform-tools\adb.exe'))) {
    Write-Host "  ! adb zip mein nahi mila - tools\platform-tools check karo" -ForegroundColor Yellow
}

Write-Host ""
if ($DryRun) {
    & (Join-Path $dest 'scripts\setup.ps1') -DryRun -Yes
} else {
    & (Join-Path $dest 'scripts\setup.ps1')
}
