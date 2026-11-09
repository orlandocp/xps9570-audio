# Audio Dell XPS 15 9570

> **English summary.** On the Dell XPS 15 9570 under Windows 11, the Intel SST audio driver stack
> (Intel SST OED, `IntcOED.sys` 10.23.3349.219) fails to start with Code 10 / `0xC000009E`, so the Realtek codec
> and the "Speakers" device disappear after Windows/Dell updates. This repo has two double-click PowerShell
> scripts: `Install-GenericAudioController.bat` forces Microsoft's generic HD Audio controller driver and
> disables the broken OED (sound is back), and `Install-DellRealtekDriver.bat` puts Dell's official Realtek
> 6.0.8991.1 HDA driver on the codec. Waves/MaxxAudio cannot be restored: Dell only binds it in SST mode.
> Full evidence, failed attempts and final state: [docs/investigation.md](docs/investigation.md). The
> documentation is in Spanish. Tested only on one XPS 9570 (BIOS 1.27.0, Windows 11 26H2 build 26300) on
> 2026-11-08; use at your own risk. The Dell driver files are not included
> ([docs/driver-source.md](docs/driver-source.md)).

Dos scripts de doble clic para recuperar el audio de la laptop despues de que Windows Update lo rompe.

| Script | Para que sirve | Guia |
|---|---|---|
| **`Install-DellRealtekDriver.bat`** (principal) | Pone el driver oficial de Dell/Realtek en el codec (afinacion de Dell) | [guia](docs/install-dell-realtek-driver.md) |
| `Install-GenericAudioController.bat` (base) | Arregla el controlador y el Intel SST OED para que vuelvan las bocinas | [guia](docs/install-generic-audio-controller.md) |

## Que correr

| Situacion | Que hacer |
|---|---|
| No hay sonido | `Install-GenericAudioController.bat`, y luego `Install-DellRealtekDriver.bat` |
| Hay sonido pero plano, o volvio el driver generico | `Install-DellRealtekDriver.bat` |

Si algo falla: reinicia y repite. Ambos son repetibles sin riesgo.

## Contenido

| Archivo | Responsabilidad |
|---|---|
| `Install-DellRealtekDriver.bat` / `.ps1` | instalar el driver Realtek de Dell en el codec |
| `Install-GenericAudioController.bat` / `.ps1` | dejar el controlador funcionando (driver generico, sin OED) |
| `Save-AudioState.ps1` | foto de solo lectura de los drivers de audio ([guia](docs/save-audio-state.md)) |
| `drivers\` (no esta en el repo) | archivos del driver Realtek ([origen](docs/driver-source.md)) |
| `docs\investigation.md` | pruebas, fallas, hipotesis descartadas y estado final |
| `docs\versions.md` | versiones y fechas de cada driver (2026-11-08) |

Los `.log` y `snapshots\` se generan al usar los scripts y no se suben al repo.
Licencia: [MIT](LICENSE) (aplica a los scripts y la documentacion, no a los drivers de Dell/Realtek).
Convencion: nombres `Verbo-Sustantivo` en ingles; codigo y comentarios en ingles; mensajes de consola y
documentacion en espanol. Creado el 2026-11-08 con Claude Code.
