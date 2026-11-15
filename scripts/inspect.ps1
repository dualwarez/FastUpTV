# FastUpTV - inspect
# TV par kya-kya installed hai, ye dikhata hai (apni brand list banane ke liye).
#   .\scripts\inspect.ps1
#   .\scripts\inspect.ps1 -TvHost 192.168.1.50
param([string]$TvHost = '')
$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'lib.ps1')
$script:AdbPath = Get-Adb $root

if (-not $script:AdbPath) { Write-Host "adb nahi mila" -ForegroundColor Red; exit 1 }
$serial = Find-Tv $script:AdbPath $TvHost
if (-not $serial) { Write-Host "TV nahi mila" -ForegroundColor Red; exit 1 }

$brand = Get-Prop $serial 'ro.product.brand'
$model = Get-Prop $serial 'ro.product.model'
$sdk = Get-Prop $serial 'ro.build.version.sdk'

Clear-Host
Write-Host ""
Write-Host ("  {0} {1}  -  Android API {2}" -f $brand, $model, $sdk) -ForegroundColor Cyan
Write-Host ""

$all = (Sh $serial 'pm list packages') -split "`r?`n" | ForEach-Object { ($_ -replace '^package:', '').Trim() } | Where-Object { $_ }
$disabled = (Sh $serial 'pm list packages -d') -split "`r?`n" | ForEach-Object { ($_ -replace '^package:', '').Trim() } | Where-Object { $_ }
$system = (Sh $serial 'pm list packages -s') -split "`r?`n" | ForEach-Object { ($_ -replace '^package:', '').Trim() } | Where-Object { $_ }
$third = $all | Where-Object { $system -notcontains $_ }

Write-Host ("  total: {0}   system: {1}   aapke apps: {2}   disabled: {3}" -f $all.Count, $system.Count, $third.Count, $disabled.Count) -ForegroundColor DarkGray
Write-Host ""
Write-Host "  --- aapke (third-party) apps ---" -ForegroundColor Yellow
$third | Sort-Object | ForEach-Object { Write-Host "    $_" }
Write-Host ""
Write-Host "  --- brand ke system apps (vendor) ---" -ForegroundColor Yellow
$system | Where-Object { $_ -match '^(com\.(tcl|sony|hisense|philips|oneplus|nokia|skyworth|changhong|xiaomi|mitv)|android\.autoinstalls)' } |
    Sort-Object | ForEach-Object { Write-Host "    $_" }
Write-Host ""
Write-Host "  --- already disabled ---" -ForegroundColor Yellow
$disabled | Sort-Object | ForEach-Object { Write-Host "    $_" }
Write-Host ""
Write-Host "  Save karne ke liye:  .\scripts\inspect.ps1 | Out-File tv-apps.txt" -ForegroundColor DarkGray
Write-Host ""
