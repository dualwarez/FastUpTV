# FastUpTV - setup
#   .\scripts\setup.ps1                 (TV dhoondh ke sab kuch karta hai)
#   .\scripts\setup.ps1 -TvHost 192.168.1.50
#   .\scripts\setup.ps1 -DryRun         (kuch change nahi, sirf dikhata hai)
param(
    [string]$TvHost = '',
    [switch]$DryRun,
    [switch]$NoLauncher,
    [switch]$Compile,
    [switch]$Yes
)
$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'lib.ps1')

$script:AdbPath = Get-Adb $root
Clear-Host
Write-Host ""
Write-Host "  ############################################################" -ForegroundColor DarkCyan
Write-Host "  #                                                          #" -ForegroundColor DarkCyan
Write-Host "  #   F a s t U p T V                                        #" -ForegroundColor Cyan
Write-Host "  #   Android TV ko fast, clean aur ad-free banao            #" -ForegroundColor DarkCyan
Write-Host "  #                                                          #" -ForegroundColor DarkCyan
Write-Host "  ############################################################" -ForegroundColor DarkCyan

if (-not $script:AdbPath) {
    Fail "adb nahi mila. 'tools\platform-tools\adb.exe' rakho ya PATH mein adb add karo."
    exit 1
}
Info "adb: $script:AdbPath"

Step 1 "TV dhoondh rahe hain ..."
$serial = Find-Tv $script:AdbPath $TvHost
if (-not $serial) {
    Fail "Koi Android TV nahi mila."
    Write-Host ""
    Write-Host "  TV par ye karo (ek baar):" -ForegroundColor Yellow
    Write-Host "   1. Settings > About (ya Device Preferences > About)" -ForegroundColor Gray
    Write-Host "   2. 'Build' par 7 baar OK dabao  -> 'You are now a developer'" -ForegroundColor Gray
    Write-Host "   3. Settings > Developer options > USB debugging ON" -ForegroundColor Gray
    Write-Host "      (Xiaomi/Redmi par 'ADB debugging' bhi ON karo)" -ForegroundColor Gray
    Write-Host "   4. TV ko WiFi par chhod do, computer bhi usi WiFi par ho" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Phir dobara chalao:  setup.bat" -ForegroundColor Yellow
    Write-Host "  IP pata ho to:       setup.bat 192.168.1.50" -ForegroundColor DarkGray
    exit 1
}
Ok "mila: $serial"

Step 2 "TV ki jaankari ..."
$brand = Get-Prop $serial 'ro.product.brand'
$manufacturer = Get-Prop $serial 'ro.product.manufacturer'
$model = Get-Prop $serial 'ro.product.model'
$sdk = Get-Prop $serial 'ro.build.version.sdk'
$release = Get-Prop $serial 'ro.build.version.release'
$homeLine = (Sh $serial 'cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME') -split "`r?`n" |
    Where-Object { $_ -match '/' } | Select-Object -Last 1
$homePkg = "$homeLine".Trim() -split '/' | Select-Object -First 1
Info "brand     : $brand / $manufacturer"
Info "model     : $model"
Info "android   : $release (API $sdk)"
Info "home app  : $homePkg"

if ($sdk -match '^\d+$' -and [int]$sdk -lt 26) {
    Warn "Android 8 se purana TV hai - kuch cheezein kaam nahi kar sakti."
}

Step 3 "Kya hone wala hai"
$listCore = Join-Path $root 'lists\core.txt'
$brandKey = ($brand + $manufacturer).ToLower()
$listBrand = $null
foreach ($candidate in @('xiaomi', 'tcl', 'sony', 'hisense', 'philips', 'google', 'oneplus', 'nokia')) {
    if ($brandKey -match $candidate) { $listBrand = Join-Path $root "lists\$candidate.txt"; break }
}
if ($listBrand -and -not (Test-Path $listBrand)) { $listBrand = $null }
$corePkgs = Read-List $listCore
$brandPkgs = if ($listBrand) { Read-List $listBrand } else { @() }
Info ("safe debloat : {0} packages" -f $corePkgs.Count)
if ($listBrand) { Info ("{0} extra  : {1} packages" -f $brand, $brandPkgs.Count) }
else { Info "is brand ki apni list nahi - sirf safe list chalegi" }
if (-not $NoLauncher) { Info "launcher     : install hoga aur Home bana diya jayega" }
Info "performance  : animations 0.5x, cache trim$(if($Compile){', apps AOT compile'})"

if ($DryRun) { Warn "DRY RUN - TV par kuch change nahi hoga" }
if (-not $Yes -and -not $DryRun) {
    Write-Host ""
    Write-Host "  Enter dabao shuru karne ke liye (Ctrl+C = cancel) ..." -ForegroundColor Yellow
    Read-Host | Out-Null
}

Step 4 "Backup"
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupDir = Join-Path $root "backups\$stamp"
if ($DryRun) {
    Info "would save to $backupDir"
} else {
    Backup $serial $backupDir
    Ok "backup: $backupDir"
}
$record = Join-Path $backupDir 'disabled.txt'
if (-not $DryRun) { New-Item -ItemType Directory -Path $backupDir -Force | Out-Null }

Step 5 "Bloat hata rahe hain (chhote batches mein)"
$all = @($corePkgs) + @($brandPkgs)
$result = Apply-List $serial $all $homePkg $record -DryRun:$DryRun
Ok ("disabled {0} | pehle se nahi tha {1} | fail {2}" -f $result.Done, $result.Skipped, $result.Failed)

Step 6 "Performance tuning"
if ($DryRun) {
    Info "would set animations 0.5x, pm trim-caches"
} else {
    foreach ($k in 'window_animation_scale', 'transition_animation_scale', 'animator_duration_scale') {
        Sh $serial "settings put global $k 0.5" | Out-Null
    }
    Ok "animations 0.5x"
    Sh $serial 'pm trim-caches 32G' | Out-Null
    Ok "cache trim"
    if ($Compile) {
        $apps = @('com.google.android.youtube.tv', 'com.netflix.ninja', 'com.google.android.tvlauncher')
        foreach ($a in $apps) {
            if ((Sh $serial 'pm list packages') -match [regex]::Escape($a)) {
                Info "compiling $a ..."
                Sh $serial "cmd package compile -m speed -f $a" | Out-Null
            }
        }
        Ok "apps compiled"
    }
}

if (-not $NoLauncher) {
    Step 7 "Fast launcher"
    $apk = Join-Path $root 'apk\launcher.apk'
    if (-not (Test-Path $apk)) {
        Warn "apk\launcher.apk nahi mila - launcher skip"
    } elseif ($DryRun) {
        Info "would install $apk and set as Home"
    } else {
        $inst = (& $script:AdbPath -s $serial install -r $apk 2>&1 | Out-String).Trim()
        if ($inst -notmatch 'Success') {
            Warn "launcher install nahi hua: $inst"
        } else {
            Ok "launcher install"
            Sh $serial 'cmd package set-home-activity --user 0 com.gathin.tvhome/.MainActivity' | Out-Null
            Sh $serial 'am start -W -a android.intent.action.MAIN -c android.intent.category.HOME -n com.gathin.tvhome/.MainActivity' | Out-Null
            $now = (Sh $serial 'cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME') -split "`r?`n" |
                Where-Object { $_ -match 'gathin' } | Select-Object -Last 1
            if ($now) {
                Ok "Home ab naya launcher hai"
                if ($homePkg -and $homePkg -notmatch 'gathin') {
                    Sh $serial "pm disable-user --user 0 $homePkg" | Out-Null
                    if ($record) { $homePkg | Out-File $record -Append -Encoding utf8 }
                    Ok "purana launcher disable: $homePkg"
                }
            } else {
                Warn "Home set nahi hua - purana launcher wapas chalu hai, kuch nahi bigda"
                Sh $serial "pm enable --user 0 $homePkg" | Out-Null
            }
        }
    }
}

Write-Host ""
Write-Host "  ------------------------------------------------------------" -ForegroundColor DarkGray
if ($DryRun) {
    Write-Host "  DRY RUN poora hua - TV par kuch change nahi hua." -ForegroundColor Yellow
} else {
    Write-Host "  HO GAYA!" -ForegroundColor Green
    Write-Host ""
    Write-Host "  TV par Home dabao - naya launcher dikhega." -ForegroundColor Gray
    Write-Host "  Kuch wapas chahiye?  restore.bat  chalao" -ForegroundColor Gray
    Write-Host ("  Backup: {0}" -f $backupDir) -ForegroundColor DarkGray
}
Write-Host "  ------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host ""
