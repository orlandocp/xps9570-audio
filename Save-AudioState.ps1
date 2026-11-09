<#
.SYNOPSIS
    Saves a snapshot of the audio driver configuration (read-only, no admin needed).

.DESCRIPTION
    Writes a JSON file to .\snapshots\ with, for every audio-related device, the driver
    INF, version, date and provider that is bound right now, plus the audio endpoints and
    their status. Use it BEFORE experimenting with drivers so the exact previous state is
    documented. To go back to a working state, run Install-GenericAudioController.bat.

.NOTES
    ASCII only. Created 2026-11-08 with Claude Code.
#>
$snapshotDir = Join-Path $PSScriptRoot 'snapshots'
New-Item -ItemType Directory -Force -Path $snapshotDir | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$outFile = Join-Path $snapshotDir "audio-state-$stamp.json"

# Drivers bound to audio-related devices (one fast CIM query)
$drivers = Get-CimInstance Win32_PnPSignedDriver -ErrorAction SilentlyContinue |
    Where-Object {
        $_.DeviceID -like 'INTELAUDIO*' -or $_.DeviceID -like 'HDAUDIO*' -or
        $_.DeviceID -like 'PCI\VEN_8086&DEV_A348*' -or
        $_.DeviceName -match 'Realtek.*(Audio|Asio)|Waves|Smart Sound|High Definition Audio|Display Audio'
    } |
    Select-Object DeviceID, DeviceName, DriverVersion, @{n='DriverDate';e={"$($_.DriverDate)"}}, InfName, Manufacturer

$endpoints = Get-PnpDevice -Class AudioEndpoint -ErrorAction SilentlyContinue |
    Select-Object Status, FriendlyName

$monitors = Get-PnpDevice -Class Monitor -PresentOnly -ErrorAction SilentlyContinue |
    Select-Object Status, FriendlyName

[pscustomobject]@{
    Created   = (Get-Date).ToString('s')
    Drivers   = $drivers
    Endpoints = $endpoints
    Monitors  = $monitors
} | ConvertTo-Json -Depth 5 | Set-Content -Path $outFile -Encoding UTF8

Write-Host "Snapshot saved: $outFile"
