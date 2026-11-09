<#
.SYNOPSIS
    Installs Dell's official Realtek audio driver (HDA variant) on the Realtek codec.

.DESCRIPTION
    Run it AFTER Install-GenericAudioController.bat has left audio working. Installs the driver in
    drivers\realtek-6.0.8991.1\ (Realtek HD Audio 6.0.8991.1 A10, HDXDELLCSMB2018.inf) with
    pnputil and forces it onto the codec. Does nothing if the codec already uses it (-Force
    reinstalls). It does not give Waves/MaxxAudio. Steps, undo: docs\install-dell-realtek-driver.md
    Where the driver files come from: docs\driver-source.md

    EXIT CODES: 0 = installed or already installed | 1 = error (no codec, driver files missing, install failed)

    USAGE: double-click Install-DellRealtekDriver.bat (or .\Install-DellRealtekDriver.ps1 [-Force] [-NoPause]).

.PARAMETER Force
    Reinstall even if the codec already uses this driver version.

.PARAMETER NoPause
    Do not wait for Enter at the end (automated use).

.NOTES
    Created 2026-11-08 with Claude Code. ASCII only (PowerShell 5.1 encoding).
    Console messages are in Spanish on purpose (read by the laptop's owner).
#>
param(
    [switch]$Force,
    [switch]$NoPause
)

$ErrorActionPreference = 'Continue'
$LogFile       = Join-Path $PSScriptRoot 'Install-DellRealtekDriver.log'
$DriverVersion = '6.0.8991.1'
$InfPath       = Join-Path $PSScriptRoot 'drivers\realtek-6.0.8991.1\HDXDELLCSMB2018.inf'
$CodecHwId     = 'HDAUDIO\FUNC_01&VEN_10EC&DEV_0298&SUBSYS_1028087C'

function Write-Log($Message) {
    $line = '{0:yyyy-MM-dd HH:mm:ss}  {1}' -f (Get-Date), $Message
    Write-Host $line
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}

function Exit-Script($Code) {
    if (-not $NoPause) { Read-Host 'Pulsa Enter para cerrar' | Out-Null }
    exit $Code
}

# --- 1. Administrator rights ------------------------------------------------------
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host 'Pidiendo permisos de administrador...'
    $relaunchArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"")
    if ($Force)   { $relaunchArgs += '-Force' }
    if ($NoPause) { $relaunchArgs += '-NoPause' }
    Start-Process -FilePath 'powershell.exe' -ArgumentList $relaunchArgs -Verb RunAs
    exit
}

function Get-RealtekCodec {
    Get-CimInstance Win32_PnPSignedDriver -ErrorAction SilentlyContinue |
        Where-Object { $_.DeviceID -like 'HDAUDIO\FUNC_01&VEN_10EC*' } | Select-Object -First 1
}

Write-Log '=== Install-DellRealtekDriver: inicio ==='

# --- 2. Preconditions -------------------------------------------------------------
if (-not (Test-Path $InfPath)) {
    Write-Log "ERROR: faltan los archivos del driver: $InfPath"
    Write-Log 'Rehaz la carpeta drivers\ siguiendo docs\driver-source.md (enlace de descarga de Dell).'
    Exit-Script 1
}
$codec = Get-RealtekCodec
if (-not $codec) {
    Write-Log 'ERROR: no hay codec Realtek. Ejecuta primero Install-GenericAudioController.bat y reinicia si hace falta.'
    Exit-Script 1
}
Write-Log ('Codec actual: {0} {1} ({2})' -f $codec.DeviceName, $codec.DriverVersion, $codec.InfName)

# --- 3. Already installed? --------------------------------------------------------
if (($codec.DriverVersion -eq $DriverVersion) -and ($codec.DriverProviderName -match 'Realtek') -and -not $Force) {
    Write-Log "Ya esta instalado el driver Dell/Realtek $DriverVersion. No se hace nada (usa -Force para reinstalar)."
    Exit-Script 0
}

# --- 4. Install -------------------------------------------------------------------
Write-Log 'Agregando el driver al almacen de Windows...'
$pnpOutput = pnputil /add-driver "$InfPath" /install 2>&1 | Out-String
Write-Log ('pnputil: ' + (($pnpOutput -split "`r?`n" | Where-Object { $_.Trim() }) -join ' | '))

Add-Type -ErrorAction SilentlyContinue -Namespace Native -Name Newdev -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("newdev.dll", CharSet = System.Runtime.InteropServices.CharSet.Unicode, SetLastError = true)]
public static extern bool UpdateDriverForPlugAndPlayDevices(System.IntPtr hwnd, string hardwareId, string fullInfPath, uint installFlags, out bool rebootRequired);
'@
$rebootNeeded = $false
Write-Log 'Forzando el driver sobre el codec Realtek...'
$ok = [Native.Newdev]::UpdateDriverForPlugAndPlayDevices([IntPtr]::Zero, $CodecHwId, $InfPath, 1, [ref]$rebootNeeded)
if (-not $ok) {
    $err = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
    Write-Log "AVISO: UpdateDriverForPlugAndPlayDevices devolvio error $err (puede ser normal si ya estaba aplicado)."
}
if ($rebootNeeded) { Write-Log 'Windows pide reiniciar para terminar.' }

# --- 5. Report --------------------------------------------------------------------
Restart-Service -Name Audiosrv -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 5
$codec = Get-RealtekCodec
if ($codec -and $codec.DriverVersion -eq $DriverVersion -and $codec.DriverProviderName -match 'Realtek') {
    Write-Log ('LISTO: codec con {0} {1} ({2})' -f $codec.DeviceName, $codec.DriverVersion, $codec.InfName)
    $result = 0
} else {
    Write-Log 'ERROR: el codec no quedo con el driver Dell/Realtek. Reinicia y ejecuta de nuevo con -Force.'
    $result = 1
}
Get-PnpDevice -Class AudioEndpoint -Status OK -ErrorAction SilentlyContinue |
    Where-Object { $_.FriendlyName -match 'Realtek' } |
    ForEach-Object { Write-Log ('Salida activa: ' + $_.FriendlyName) }
Write-Log 'Prueba a mano: sonido por "Speakers/Headphones (Realtek Audio)" y microfono. Waves no esta activo (ver docs\investigation.md).'
Exit-Script $result
