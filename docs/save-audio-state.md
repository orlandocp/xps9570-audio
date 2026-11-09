# Save-AudioState

Script opcional de **solo lectura** (no cambia nada, no pide administrador). Guarda una "foto" del estado del
audio en `snapshots\audio-state-<fecha-hora>.json`:

- el driver de cada dispositivo de audio (INF, version, fecha, fabricante),
- las salidas y entradas de audio y si estan OK,
- los monitores conectados.

## Para que sirve

- Correrlo **antes** de probar drivers, para tener documentado el estado exacto al que volver.
- Correrlo **despues** de que Windows rompa el audio, para comparar con una foto buena y ver que driver cambio.

## Notas

- No se ejecuta solo y ningun otro script lo usa.
- Para volver a un estado que funciona se usan `Install-GenericAudioController` y `Install-DellRealtekDriver`.
- Cada foto lleva datos de la maquina (IDs de dispositivo), por eso `snapshots\` no se sube al repo.

Uso: `.\Save-AudioState.ps1` desde PowerShell.
