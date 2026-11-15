# FastUpTV - shared helpers (PowerShell 5.1 compatible, ASCII only)
$ErrorActionPreference = 'Stop'

function Step($n, $text) {
    Write-Host ""
    Write-Host ("  [{0}] {1}" -f $n, $text) -ForegroundColor Cyan
}

function Ok($text)   { Write-Host ("      OK   {0}" -f $text) -ForegroundColor Green }
function Info($text) { Write-Host ("           {0}" -f $text) -ForegroundColor DarkGray }
function Warn($text) { Write-Host ("      !    {0}" -f $text) -ForegroundColor Yellow }
function Fail($text) { Write-Host ("      X    {0}" -f $text) -ForegroundColor Red }

function Get-Adb([string]$root) {
    $candidates = @(
        (Join-Path $root 'tools\platform-tools\adb.exe'),
        (Join-Path $root 'tools\adb.exe'),
        (Join-Path $root 'platform-tools\adb.exe')
    )
    foreach ($c in $candidates) { if (Test-Path $c) { return $c } }
    $cmd = Get-Command adb -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

function Adb([string]$serial, [string[]]$argv) {
    $out = & $script:AdbPath -s $serial @argv 2>&1
    return ($out | Out-String).Trim()
}

function Sh([string]$serial, [string]$cmd) {
    return Adb $serial @('shell', $cmd)
}

function Get-LocalSubnet {
    $ip = (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } |
        Select-Object -First 1).IPAddress
    if (-not $ip) { return $null }
    return ($ip -replace '\.\d+$', '')
}

function Test-Port([string]$ip, [int]$port, [int]$timeoutMs = 350) {
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $ar = $client.BeginConnect($ip, $port, $null, $null)
        return ($ar.AsyncWaitHandle.WaitOne($timeoutMs, $false) -and $client.Connected)
    } catch { return $false } finally { $client.Close() }
}

function Find-Tv([string]$adb, [string]$hint) {
    # 1. USB / already connected
    $devices = (& $adb devices) -join "`n"
    $connected = @()
    foreach ($line in ($devices -split "`r?`n")) {
        if ($line -match '^(\S+)\s+device$') { $connected += $Matches[1] }
    }
    if ($connected.Count -gt 0) { return $connected[0] }

    # 2. explicit IP:port
    if ($hint) {
        & $adb connect $hint | Out-Null
        Start-Sleep -Seconds 1
        if (((& $adb devices) -join "`n") -match [regex]::Escape($hint) + '\s+device') { return $hint }
    }

    # 3. scan the local /24 for port 5555
    $subnet = Get-LocalSubnet
    if (-not $subnet) { return $null }
    Info "scanning $subnet.1-254 for Android TV (port 5555) ..."
    $found = @()
    foreach ($i in 1..254) {
        $ip = "$subnet.$i"
        if (Test-Port $ip 5555 200) { $found += "$ip:5555"; Write-Host "           found $ip" -ForegroundColor DarkGray }
    }
    foreach ($f in $found) { & $adb connect $f | Out-Null }
    Start-Sleep -Seconds 1
    foreach ($f in $found) {
        if (((& $adb devices) -join "`n") -match [regex]::Escape($f) + '\s+device') { return $f }
    }
    return $null
}

function Get-Prop([string]$serial, [string]$name) {
    $value = (Sh $serial "getprop $name").Trim()
    if ($value -match 'Android Debug Bridge|^error') { return '' }
    return $value
}

function Read-List([string]$path) {
    if (-not (Test-Path $path)) { return @() }
    $items = @()
    foreach ($line in (Get-Content $path)) {
        $clean = ($line -replace '#.*$', '').Trim()
        if ($clean) { $items += ($clean -split '\s+')[0] }
    }
    return ($items | Select-Object -Unique)
}

function Backup([string]$serial, [string]$dir) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    Sh $serial 'pm list packages -f'      | Out-File (Join-Path $dir 'packages-all.txt') -Encoding utf8
    Sh $serial 'pm list packages -d'      | Out-File (Join-Path $dir 'packages-disabled.txt') -Encoding utf8
    Sh $serial 'getprop'                  | Out-File (Join-Path $dir 'props.txt') -Encoding utf8
    Sh $serial 'settings list global'     | Out-File (Join-Path $dir 'settings-global.txt') -Encoding utf8
    Sh $serial 'settings list secure'     | Out-File (Join-Path $dir 'settings-secure.txt') -Encoding utf8
    Sh $serial 'settings list system'     | Out-File (Join-Path $dir 'settings-system.txt') -Encoding utf8
    Sh $serial 'cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME' |
        Out-File (Join-Path $dir 'home-owner.txt') -Encoding utf8
}

# Packages that must never be disabled, on any TV.
$script:CorePattern = '^(android|com\.android\.systemui|com\.android\.shell|com\.android\.phone|com\.android\.settings|com\.android\.tv\.settings|com\.(google\.)?android\.(permissioncontroller|packageinstaller|ext\.services|ext\.shared|modulemetadata)|com\.google\.android\.overlay\.modules.*|com\.android\.providers\..*)$'
$script:CoreAllowed = '^com\.android\.providers\.(calendar|contacts|userdictionary|blockednumber)$'

function Apply-List([string]$serial, [string[]]$packages, [string]$homePkg, [string]$recordFile, [switch]$DryRun) {
    $installed = (Sh $serial 'pm list packages') -split "`r?`n" | ForEach-Object { ($_ -replace '^package:', '').Trim() }
    $done = 0; $skipped = 0; $failed = 0

    foreach ($p in $packages) {
        if ($p -cmatch $script:CorePattern -and $p -cnotmatch $script:CoreAllowed) { Warn "core package, skip: $p"; continue }
        if ($p -eq $homePkg) { Warn "Home owner, skip: $p"; continue }
        if ($p -match 'inputmethod|\.input$|gboard') { Warn "keyboard, skip: $p"; continue }
        if ($p -match 'setupwraith|setupwizard') { Warn "setup wizard, skip: $p"; continue }
        if ($installed -notcontains $p) { $skipped++; continue }
        if ($DryRun) { Info "would disable: $p"; $done++; continue }

        $out = Sh $serial "pm disable-user --user 0 $p"
        $still = ((Sh $serial 'pm list packages -d') -split "`r?`n") -match "^package:$([regex]::Escape($p))$"
        if ($still) {
            Ok $p
            $done++
            if ($recordFile) { $p | Out-File $recordFile -Append -Encoding utf8 }
        } else {
            Fail "$p  ($out)"
            $failed++
        }
        Start-Sleep -Milliseconds 250
    }
    return [pscustomobject]@{ Done = $done; Skipped = $skipped; Failed = $failed }
}

function Set-Home([string]$serial, [string]$pkg, [string]$activity) {
    Sh $serial "cmd package set-home-activity --user 0 $pkg/$activity" | Out-Null
    $now = (Sh $serial 'cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME') -split "`r?`n" |
        Where-Object { $_ -match '/' } | Select-Object -Last 1
    return $now
}
