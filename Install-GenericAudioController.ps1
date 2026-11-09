<#
.SYNOPSIS
    Restores audio on a Dell XPS 15 9570 when a Windows/Dell update breaks the audio driver.

.DESCRIPTION
    Puts Microsoft's generic HD Audio controller driver (hdaudbus.inf) on the Intel PCI audio
    controller and disables the failing Intel SST OED, so the Realtek codec and "Speakers" come
    back. Always applies the repair (safe to repeat); the checks at the end only report.
    Run Install-DellRealtekDriver.bat AFTER this script to get Dell's codec driver.
    Why it breaks, steps, what is lost and how to undo: docs\install-generic-audio-controller.md

    EXIT CODES: 0 = restored ("Speakers" listed) | 1 = error | 2 = still no speakers (reboot, run again)

    USAGE: double-click Install-GenericAudioController.bat  (or .\Install-GenericAudioController.ps1 [-SkipTests] [-NoPause]).
    Run it with Windows PowerShell 5.1 (the .bat does); under pwsh 7 the microphone capture test fails.

.PARAMETER SkipTests
    Skip the test sound and the microphone capture test (faster).

.PARAMETER NoPause
    Do not wait for Enter at the end (automated use).

.NOTES
    Created 2026-11-08 with Claude Code. ASCII only to avoid PowerShell 5.1 encoding issues.
    Console messages are in Spanish on purpose (they are read by the laptop's owner).
#>
param(
    [switch]$SkipTests,
    [switch]$NoPause
)

$ErrorActionPreference = 'Continue'
$LogFile = Join-Path $PSScriptRoot 'Install-GenericAudioController.log'

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
    if ($SkipTests) { $relaunchArgs += '-SkipTests' }
    if ($NoPause)   { $relaunchArgs += '-NoPause' }
    Start-Process -FilePath 'powershell.exe' -ArgumentList $relaunchArgs -Verb RunAs
    exit
}

# --- Functions --------------------------------------------------------------------
function Get-ActiveSpeakers {
    Get-PnpDevice -Class AudioEndpoint -Status OK -ErrorAction SilentlyContinue |
        Where-Object { $_.FriendlyName -match 'Speakers|Altavoces|Bocinas' }
}

function Get-ActiveMic {
    Get-PnpDevice -Class AudioEndpoint -Status OK -ErrorAction SilentlyContinue |
        Where-Object { $_.FriendlyName -match 'Microphone|Microfono|Mic ' }
}

function Get-IntelAudioController {
    # Intel HD audio controller (PCI class 0403). A single CIM query (fast);
    # Win32_PnPEntity only lists devices that are present.
    Get-CimInstance Win32_PnPEntity -Filter "PNPDeviceID LIKE 'PCI\\VEN_8086%'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CompatibleID -contains 'PCI\CC_0403' -or $_.CompatibleID -contains 'PCI\CC_040380' } |
        Select-Object @{n='InstanceId';e={$_.PNPDeviceID}}, @{n='FriendlyName';e={$_.Name}}
}

function Wait-Speakers([int]$Seconds) {
    $timer = [Diagnostics.Stopwatch]::StartNew()
    while ($timer.Elapsed.TotalSeconds -lt $Seconds) {
        if (Get-ActiveSpeakers) { return $true }
        Start-Sleep -Seconds 1
    }
    return [bool](Get-ActiveSpeakers)
}

function Restart-AudioController {
    foreach ($controller in @(Get-IntelAudioController)) {
        try {
            Disable-PnpDevice -InstanceId $controller.InstanceId -Confirm:$false -ErrorAction Stop
            Start-Sleep -Seconds 3
            Enable-PnpDevice  -InstanceId $controller.InstanceId -Confirm:$false -ErrorAction Stop
        } catch { Write-Log ('No se pudo reiniciar el controlador: {0}' -f $_.Exception.Message) }
    }
    pnputil /scan-devices | Out-Null
    Restart-Service -Name Audiosrv -Force -ErrorAction SilentlyContinue
}

function Get-DisplayAudioCodec {
    # Intel monitor audio codec ("Intel Display Audio"), only if present
    Get-CimInstance Win32_PnPEntity -Filter "PNPDeviceID LIKE 'HDAUDIO\\FUNC_01&VEN_8086%'" -ErrorAction SilentlyContinue
}

function Wait-DisplayAudioCodec([int]$Seconds) {
    $timer = [Diagnostics.Stopwatch]::StartNew()
    while ($timer.Elapsed.TotalSeconds -lt $Seconds) {
        if (Get-DisplayAudioCodec) { return $true }
        Start-Sleep -Seconds 1
    }
    return [bool](Get-DisplayAudioCodec)
}

function Test-MicCapture([int]$Milliseconds) {
    # Records $Milliseconds from the default microphone (waveIn) and returns the peak
    # sample (0..32768), or a negative number if capture failed. Audio is not saved.
    if (-not ('MicProbe' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class MicProbe {
  [StructLayout(LayoutKind.Sequential)] struct WAVEFORMATEX { public ushort wFormatTag, nChannels; public uint nSamplesPerSec, nAvgBytesPerSec; public ushort nBlockAlign, wBitsPerSample, cbSize; }
  [StructLayout(LayoutKind.Sequential)] struct WAVEHDR { public IntPtr lpData; public uint dwBufferLength, dwBytesRecorded; public IntPtr dwUser; public uint dwFlags, dwLoops; public IntPtr lpNext; public IntPtr reserved; }
  [DllImport("winmm.dll")] static extern int waveInOpen(out IntPtr h, uint dev, ref WAVEFORMATEX f, IntPtr cb, IntPtr inst, uint flags);
  [DllImport("winmm.dll")] static extern int waveInPrepareHeader(IntPtr h, IntPtr hdr, int size);
  [DllImport("winmm.dll")] static extern int waveInUnprepareHeader(IntPtr h, IntPtr hdr, int size);
  [DllImport("winmm.dll")] static extern int waveInAddBuffer(IntPtr h, IntPtr hdr, int size);
  [DllImport("winmm.dll")] static extern int waveInStart(IntPtr h);
  [DllImport("winmm.dll")] static extern int waveInStop(IntPtr h);
  [DllImport("winmm.dll")] static extern int waveInReset(IntPtr h);
  [DllImport("winmm.dll")] static extern int waveInClose(IntPtr h);
  public static int Peak(int ms) {
    var f = new WAVEFORMATEX { wFormatTag=1, nChannels=1, nSamplesPerSec=16000, wBitsPerSample=16, nBlockAlign=2, nAvgBytesPerSec=32000, cbSize=0 };
    IntPtr h; int r = waveInOpen(out h, 0xFFFFFFFF, ref f, IntPtr.Zero, IntPtr.Zero, 0);
    if (r != 0) return -1000 - r;
    int bytes = 32 * ms; IntPtr buf = Marshal.AllocHGlobal(bytes);
    var hdr = new WAVEHDR { lpData = buf, dwBufferLength = (uint)bytes };
    int hs = Marshal.SizeOf(typeof(WAVEHDR)); IntPtr ph = Marshal.AllocHGlobal(hs); Marshal.StructureToPtr(hdr, ph, false);
    int peak = -2000;
    try {
      if (waveInPrepareHeader(h, ph, hs) != 0) return -2001;
      waveInAddBuffer(h, ph, hs); waveInStart(h);
      System.Threading.Thread.Sleep(ms + 300);
      waveInStop(h); waveInReset(h);
      var done = (WAVEHDR)Marshal.PtrToStructure(ph, typeof(WAVEHDR));
      int n = (int)done.dwBytesRecorded / 2; peak = 0;
      for (int i = 0; i < n; i++) { int v = Math.Abs((int)Marshal.ReadInt16(buf, i*2)); if (v > peak) peak = v; }
      if (n == 0) peak = -2002;
      waveInUnprepareHeader(h, ph, hs);
    } finally { waveInClose(h); Marshal.FreeHGlobal(buf); Marshal.FreeHGlobal(ph); }
    return peak;
  }
}
'@
    }
    return [MicProbe]::Peak($Milliseconds)
}

Write-Log '=== Install-GenericAudioController: inicio ==='

# --- 2. Controller -> Microsoft generic driver ------------------------------------
$controllers = @(Get-IntelAudioController)
if ($controllers.Count -eq 0) {
    Write-Log 'ERROR: no se encontro el controlador de audio PCI de Intel. Nada que reparar.'
    Exit-Script 1
}
foreach ($controller in $controllers) {
    $infPath = (Get-PnpDeviceProperty -InstanceId $controller.InstanceId -KeyName DEVPKEY_Device_DriverInfPath -ErrorAction SilentlyContinue).Data
    Write-Log ('Controlador: "{0}"  driver actual: {1}' -f $controller.FriendlyName, $infPath)
}
$genericInf = Join-Path $env:WINDIR 'INF\hdaudbus.inf'
if (-not (Test-Path $genericInf)) { Write-Log "ERROR: no existe $genericInf"; Exit-Script 1 }

Add-Type -Namespace AudioRepair -Name Native -MemberDefinition @'
[DllImport("newdev.dll", SetLastError=true, CharSet=CharSet.Unicode)]
public static extern bool UpdateDriverForPlugAndPlayDevices(IntPtr hwnd, string hwid, string inf, uint flags, out bool reboot);
'@ -ErrorAction SilentlyContinue

# Only install when a controller does NOT already use the generic driver. Reinstalling it
# when it is already there fixes nothing and breaks the monitor audio codec
# ("Intel Display Audio"), which then does not come back (verified 2026-11-08).
$alreadyGeneric = $true
foreach ($controller in $controllers) {
    $infPath = (Get-PnpDeviceProperty -InstanceId $controller.InstanceId -KeyName DEVPKEY_Device_DriverInfPath -ErrorAction SilentlyContinue).Data
    if ($infPath -ne 'hdaudbus.inf') { $alreadyGeneric = $false }
}
if ($alreadyGeneric) {
    Write-Log 'Driver generico: ya instalado, no se reinstala.'
} else {
    $rebootNeeded = $false
    # flags=1 -> INSTALLFLAG_FORCE: install even if another driver has a better rank
    $installed = [AudioRepair.Native]::UpdateDriverForPlugAndPlayDevices([IntPtr]::Zero, 'PCI\CC_0403', $genericInf, 1, [ref]$rebootNeeded)
    $lastError = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
    Write-Log ('Driver generico instalado: ok={0} reinicio_requerido={1} error={2}' -f $installed, $rebootNeeded, $lastError)
}

# --- 3. Disable the OED (cause of the code 10 error) ------------------------------
$oedDevices = @(Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue | Where-Object { $_.InstanceId -like 'INTELAUDIO\DSP_CTLR*' })
if ($oedDevices.Count -eq 0) { Write-Log 'OED: no esta presente (normal).' }
foreach ($device in $oedDevices) {
    try { Disable-PnpDevice -InstanceId $device.InstanceId -Confirm:$false -ErrorAction Stop; Write-Log 'OED: deshabilitado.' }
    catch { Write-Log ('OED: no se pudo deshabilitar: {0}' -f $_.Exception.Message) }
}

# --- 4. Wait for the speakers; otherwise restart codec and audio service ----------
$speakersListed = Wait-Speakers 25
if (-not $speakersListed) {
    Write-Log 'Aun sin "Speakers": reiniciando codec y servicio de audio...'
    foreach ($codec in @(Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue | Where-Object { $_.InstanceId -like 'HDAUDIO\FUNC_01&VEN_10EC*' })) {
        try {
            Disable-PnpDevice -InstanceId $codec.InstanceId -Confirm:$false -ErrorAction Stop
            Start-Sleep -Seconds 3
            Enable-PnpDevice  -InstanceId $codec.InstanceId -Confirm:$false -ErrorAction Stop
        } catch { Write-Log ('No se pudo reiniciar el codec: {0}' -f $_.Exception.Message) }
    }
    Restart-Service -Name Audiosrv -Force -ErrorAction SilentlyContinue
    $speakersListed = Wait-Speakers 20
}

# --- 5. Monitor audio -------------------------------------------------------------
$externalMonitors = @(Get-PnpDevice -Class Monitor -PresentOnly -ErrorAction SilentlyContinue | Where-Object { $_.FriendlyName -notmatch 'Integrated' })
if ($externalMonitors.Count -eq 0) {
    Write-Log 'Monitores externos: ninguno conectado (si conectas el dock despues, vuelve a ejecutar este script).'
} elseif (Get-DisplayAudioCodec) {
    Write-Log ('Audio de monitores: codec listado ({0} monitor(es) externo(s)).' -f $externalMonitors.Count)
} else {
    Write-Log ('Hay {0} monitor(es) externo(s) sin "Intel Display Audio": reiniciando el controlador de audio...' -f $externalMonitors.Count)
    Restart-AudioController
    if (Wait-DisplayAudioCodec 12) { Write-Log 'Audio de monitores: codec restaurado.' }
    else { Write-Log 'Audio de monitores: NO se pudo restaurar con el script. Reinicia la laptop con el dock conectado y revisa Configuracion > Sistema > Sonido > Salida.' }
    $speakersListed = Wait-Speakers 20
}

# --- Main result ------------------------------------------------------------------
if (-not $speakersListed) {
    Write-Log 'RESULTADO: AUN SIN BOCINAS. Reinicia la laptop y vuelve a ejecutar este script.'
    Exit-Script 2
}
Write-Log ('RESULTADO: restaurado. "{0}" esta listado.' -f (Get-ActiveSpeakers | Select-Object -First 1).FriendlyName)

# --- 6. Secondary checks (report only) --------------------------------------------
if ($SkipTests) {
    Write-Log 'Verificaciones omitidas (-SkipTests). Prueba a mano: sonido, microfono y salida de monitores.'
} else {
    try {
        (New-Object Media.SoundPlayer (Join-Path $env:WINDIR 'Media\Windows Notify System Generic.wav')).PlaySync()
        Write-Log 'Sonido de prueba reproducido: confirma tu si lo oiste (volumen/mute y salida predeterminada).'
    } catch { Write-Log 'No se pudo reproducir el sonido de prueba: prueba a mano.' }

    $mics = @(Get-ActiveMic)
    if ($mics.Count -eq 0) {
        Write-Log 'ADVERTENCIA: no hay endpoint de microfono. Prueba a mano en Configuracion > Sistema > Sonido > Entrada.'
    } else {
        Write-Log ('Microfono listado: "{0}". Habla o haz ruido 3 segundos...' -f $mics[0].FriendlyName)
        $peak = Test-MicCapture 3000
        if     ($peak -lt 0)  { Write-Log ('No se pudo probar la captura (codigo {0}): prueba el microfono a mano.' -f $peak) }
        elseif ($peak -eq 0)  { Write-Log 'ADVERTENCIA: la captura salio en silencio total: revisa que el microfono no este silenciado y pruebalo a mano.' }
        elseif ($peak -lt 30) { Write-Log ('Microfono: senal muy baja (pico {0} de 32768). Puede ser silencio ambiente; habla fuerte o prueba a mano.' -f $peak) }
        else                  { Write-Log ('Microfono capta senal (pico {0} de 32768).' -f $peak) }
    }
}
Write-Log 'Pendiente de tu lado: elegir la salida correcta (bocinas internas, monitor con jack, o DJV por Bluetooth).'
Exit-Script 0
