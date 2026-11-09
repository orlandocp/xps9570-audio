# Install-GenericAudioController

Deja el audio funcionando cuando Windows Update lo rompe: pone el driver generico de Microsoft en el
controlador de audio Intel y deshabilita el componente que falla. Es el script **base**: sin el, el codec
Realtek ni siquiera existe y no se puede instalar el driver de Dell.

## Uso

1. Doble clic en `Install-GenericAudioController.bat` (acepta el aviso de administrador).
2. Espera `RESULTADO: restaurado`.
3. Si dice `AUN SIN BOCINAS`, reinicia la laptop y ejecutalo otra vez.

Siempre aplica la reparacion y es repetible sin riesgo. Las pruebas del final son secundarias y solo informan;
con `-SkipTests` (desde PowerShell) se omiten. Despues, para recuperar la afinacion de Dell:
[install-dell-realtek-driver.md](install-dell-realtek-driver.md).

## Que problema resuelve

Windows pone el driver **Intel SST** en el controlador. Su componente `Intel SST OED` falla al iniciar
(Codigo 10, `0xC000009E`) y arrastra al driver Realtek de Dell (variante SST), asi que desaparece "Speakers".
Evidencia completa: [investigation.md](investigation.md).

## Que hace

1. Pide administrador.
2. Si el controlador PCI no usa ya el driver generico de Microsoft (`C:\Windows\INF\hdaudbus.inf`, viene con
   Windows), se lo instala forzado. Si ya lo usa, no lo reinstala (reinstalarlo hizo desaparecer el audio de
   monitores).
3. Deshabilita el `Intel SST OED` si esta presente.
4. Espera "Speakers"; si no aparece, reinicia codec y servicio de audio.
5. Si hay monitores externos sin "Intel Display Audio", reinicia el controlador de audio.
6. Pruebas secundarias: sonido de prueba, endpoint y captura de microfono.
7. Registra todo en `Install-GenericAudioController.log`.

Salida: `0` restaurado | `1` error | `2` sigue sin bocinas (reiniciar y repetir).

## Que se pierde

- La afinacion de Dell (sonido mas plano): se recupera con `Install-DellRealtekDriver`.
- Efectos Waves/MaxxAudio y el DSP de microfono de Intel: no se recuperan.
- No afecta el audio Bluetooth.

## Audio de monitores

Con el driver generico, el codec "Intel Display Audio" (audio por HDMI/DisplayPort) **no siempre aparece al
conectar el dock**. El script intenta recuperarlo reiniciando el controlador, pero **no es fiable**: si no
aparece, reinicia con el dock conectado. Un parlante conectado al jack de un monitor aparece con el nombre del
monitor.

## Deshacer

Administrador de dispositivos > `High Definition Audio Controller` > Actualizar controlador > Buscar en mi
equipo > Elegirlo de una lista > `Intel(R) Smart Sound Technology (Intel(R) SST) Audio Controller`.
