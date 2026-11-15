# FastUpTV - restore (jo kuch band kiya tha, wapas chalu)
#   .\scripts\restore.ps1                 (sabse naya backup)
#   .\scripts\restore.ps1 -Backup backups\20260101-120000
param(
    [string]$Backup = '',
    [string]$TvHost = ''
)
$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'lib.ps1')
$script:AdbPath = Get-Adb $root

Clear-Host
Write-Host ""
Write-Host "  FastUpTV - RESTORE" -ForegroundColor Cyan
Write-Host ""

if (-not $script:AdbPath) { Fail "adb nahi mila"; exit 1 }

$serial = Find-Tv $script:AdbPath $TvHost
if (-not $serial) { Fail "TV nahi mila - USB debugging ON hai? same WiFi?"; exit 1 }
Ok "TV: $serial"

if (-not $Backup) {
    $latest = Get-ChildItem (Join-Path $root 'backups') -Directory -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending | Select-Object -First 1
    if (-not $latest) { Fail "koi backup nahi mila"; exit 1 }
    $Backup = $latest.FullName
}
Info "backup: $Backup"

$record = Join-Path $Backup 'disabled.txt'
if (-not (Test-Path $record)) { Fail "is backup mein disabled.txt nahi hai"; exit 1 }

$pkgs = Get-Content $record | Where-Object { $_ -match '\S' } | ForEach-Object { $_.Trim() } | Select-Object -Unique
Info ("{0} packages wapas chalu kar rahe hain ..." -f $pkgs.Count)

$ok = 0; $fail = 0
foreach ($p in $pkgs) {
    $out = Sh $serial "pm enable --user 0 $p"
    if ($out -match 'new state: enabled') { Ok $p; $ok++ } else { Fail "$p ($out)"; $fail++ }
}

foreach ($k in 'window_animation_scale', 'transition_animation_scale', 'animator_duration_scale') {
    Sh $serial "settings put global $k 1.0" | Out-Null
}
Ok "animations 1x"

$homeFile = Join-Path $Backup 'home-owner.txt'
if (Test-Path $homeFile) {
    $stockHome = (Get-Content $homeFile | Where-Object { $_ -match '/' } | Select-Object -Last 1) -split '/' | Select-Object -First 1
    if ($stockHome) {
        Sh $serial "pm enable --user 0 $stockHome" | Out-Null
        Sh $serial "cmd package set-home-activity --user 0 $stockHome/.MainActivity" | Out-Null
        Info "purana home: $stockHome"
    }
}
Sh $serial "pm disable-user --user 0 com.gathin.tvhome" | Out-Null

Write-Host ""
Write-Host ("  RESTORE HO GAYA - {0} chalu, {1} fail" -f $ok, $fail) -ForegroundColor Green
Write-Host "  TV restart karo: remote se power off/on" -ForegroundColor Gray
Write-Host ""
