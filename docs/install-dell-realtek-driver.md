# Install-DellRealtekDriver

Pone el driver oficial de Dell/Realtek (6.0.8991.1, variante HDA) en el codec de audio Realtek. Es el script
**principal**: deja el audio con la afinacion que Dell hizo para este modelo (suena mejor que con el driver
generico de Microsoft; percepcion del dueno, no medida).

## Uso

1. Doble clic en `Install-DellRealtekDriver.bat` (acepta el aviso de administrador).
2. Espera `LISTO: codec con Realtek Audio 6.0.8991.1`.

Si dice `no hay codec Realtek`, el controlador esta roto: ejecuta antes `Install-GenericAudioController.bat`
([guia](install-generic-audio-controller.md)) y reinicia.

## Que hace

1. Pide administrador.
2. Busca el codec Realtek (`HDAUDIO\FUNC_01&VEN_10EC`). Si no existe, se detiene.
3. Si el codec ya usa este driver, no hace nada (`-Force` desde PowerShell reinstala).
4. Agrega el driver al almacen de Windows (`pnputil /add-driver`) y lo fuerza sobre el codec
   (`UpdateDriverForPlugAndPlayDevices`), porque Windows puede preferir otro.
5. Reinicia el servicio de audio y lista las salidas Realtek activas.
6. Registra todo en `Install-DellRealtekDriver.log`.

Es repetible y no necesita internet: usa los archivos de `drivers\realtek-6.0.8991.1\`
(de donde salen: [driver-source.md](driver-source.md)).

Salida: `0` instalado o ya instalado | `1` error (sin codec, faltan archivos, fallo la instalacion).

## Lo que NO da

Waves/MaxxAudio. Dell solo enlaza Waves en modo SST y ese modo falla en este equipo
([investigation.md](investigation.md)).

## Deshacer

Administrador de dispositivos > `Realtek Audio` > Actualizar controlador > Buscar en mi equipo > Elegir de una
lista > `High Definition Audio Device` (Microsoft). O ejecutar `Install-GenericAudioController.bat`.
