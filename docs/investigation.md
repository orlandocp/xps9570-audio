# Registro de investigacion - audio Dell XPS 15 9570

Todo lo probado, encontrado, lo que fallo y el estado final. Fecha de la investigacion: **2026-11-08**
(Windows 11 26H2 build 26300, BIOS 1.27.0). Hecha con Claude Code. Los scripts de este repo son la salida
practica; este archivo es la evidencia. Las versiones exactas estan en `versions.md`.

## 1. Sintoma

Sin sonido por las bocinas internas. Segun el dueno, a veces volvia solo tras una actualizacion de Windows/Dell
y luego se rompia con otra, durante meses. Al principio parecia una tarjeta de sonido danada.

## 2. Causa encontrada

- El controlador de audio Intel (`PCI\VEN_8086&DEV_A348`, SUBSYS `1028087C`) queda con el driver **Intel SST**
  (`intcaudiobus`). Su dispositivo hijo **Intel SST OED** (`IntcOED.sys` 10.23.3349.219, 2020) **falla al iniciar**:
  Codigo 10, `0xC000009E` (STATUS_DEVICE_POWER_FAILURE). El evento no trae texto legible; el `.sys` contiene el
  texto "Configuration mismatch (production/engineering)".
- El driver Realtek de Dell que Windows elige es la variante SST (`hdxdellsstcsmb2018.inf`, solo `INTELAUDIO`),
  que depende del OED. Sin OED no hay codec Realtek y desaparece "Speakers".
- Ese fallo ya ocurria casi a diario desde **2026-09-26** (logs de `Windows.old`), asi que la reinstalacion de
  Windows del 2026-11-01 **no** lo causo.

## 3. Lo que se hizo, en orden

| # | Accion | Resultado |
|---|---|---|
| 1 | Cambiar el controlador al driver generico de Microsoft (`hdaudbus.inf`) y deshabilitar el OED | **Funciona**: el codec Realtek aparece (driver `hdaudio.inf`) y vuelven bocinas y microfono |
| 2 | Convertirlo en script de doble clic (`Install-GenericAudioController`) | Funciona; probado sobre un estado realmente roto (revierte en ~9 s) |
| 3 | Investigar la configuracion "de fabrica" de Dell (Waves/MaxxAudio) | Ver secciones 4 y 5 |
| 4 | Instalar el driver base HDA oficial de Dell/Realtek 6.0.8991.1 (`Install-DellRealtekDriver`) | **Funciona**; el dueno percibe mejor sonido (subjetivo, no medido) |
| 5 | Reset de energia (apagar, quitar AC, boton 30 s) | Sin cambios |

## 4. Hipotesis descartadas

| Hipotesis | Resultado |
|---|---|
| Desalineacion entre `intcaudiobus` 2427 (2019, trae el SUBSYS exacto de la laptop) y el OED 3349 | **Descartada.** Con bus 3349 + OED 3349 (prueba del 2026-11-08 17:55) el OED vuelve a fallar |
| Existe un OED o driver de Dell mas viejo o mas nuevo | **Descartada.** `Windows.old` trae los mismos paquetes y hashes; Dell Command Update 5.7.0 no ofrece audio nuevo |
| Integridad de memoria (HVCI) bloquea el OED | **Descartada.** Activa desde 2022 en ambos Windows; el audio funcionaba a ratos |
| La reinstalacion de Windows del 2026-11-01 lo causo | **Descartada.** Fallaba desde 2026-09-26 |
| Otros paquetes Realtek de Dell del catalogo (hd4wf, 88ttt, p07ch, t55wp) | **No sirven**: son de otros modelos |
| Falta del dispositivo HECI/MEI (`PCI\VEN_8086&DEV_A360`, existia en el Windows anterior) | **Sin evidencia.** El `.sys` del OED no lo menciona; el reset de energia tampoco lo trajo de vuelta |
| Restaurar el BIOS a valores por defecto | **Descartada por el dueno**: nunca lo modifico (BIOS 1.27.0 de 2022) |

## 5. Por que no hay Waves/MaxxAudio (lo que NO funciona)

- Los efectos Waves se enlazan a las salidas mediante las extensiones de Dell
  `Realtek\ExtRtk_8991.1\HDX_DellCSMBExt_*` (instaladas como `oem61`, ExtensionId `{3ED78669-...}`).
- Para esta laptop (`087C`) esas extensiones tienen **una sola linea activa, la de `INTELAUDIO`** (modo SST, con
  politicas `SSTEnablePP`/`SSTEnableWOV`). La linea de `HDAUDIO` para `087C` **esta comentada por Dell**.
- Conclusion: **en el paquete oficial de Dell, Waves solo funciona con el OED sano.** Medido: con el driver
  de Dell en modo HDA, `audiodg.exe` no carga ningun modulo de Waves/Maxx.
- Tampoco se recupera el procesamiento de microfono por DSP ni la activacion por voz de Intel (Windows usa su
  `VocaEffectPack`).
- Se propuso **emular el enlace de Waves en el registro** (copiar las claves que el INF escribe en modo SST).
  **No se hizo**: no esta soportado por Dell, son centenares de claves y puede dejar el audio inestable. Ademas
  puede que Waves necesite el DSP de Intel para procesar.

## 6. Fallas y errores encontrados en el camino

- **El audio de monitores desaparecio.** Reinstalar a la fuerza `hdaudbus` sobre un controlador que ya lo usaba
  hizo desaparecer el codec "Intel Display Audio" (2026-11-08 17:18). Corregido: el script no reinstala si ya esta.
  Reiniciar el controlador con los monitores conectados lo trae de vuelta, pero **no es fiable**.
- Antes de verificarlo se dijo que el audio por HDMI no se afectaba: era falso (el codec era un fantasma). Corregido
  con el dueno tras comprobar.
- El script reinstalaba el driver en cada ejecucion: corregido (`alreadyGeneric`).
- Script lento (58 s) por consultas de dispositivos: bajo a ~10-20 s con consultas CIM.
- Deshabilitar el OED fantasma daba "Generic failure": hay que usar `-PresentOnly`.
- Prueba de microfono: MCI se colgaba y `waveIn` daba `-1001` en PowerShell 7. **Funciona solo con Windows
  PowerShell 5.1** (el `.bat` ya lo usa).
- Descarga de Dell: `expand.exe` no extrajo nada, se uso 7-Zip; la propiedad de hash del catalogo estaba mal
  (el atributo correcto es `hashMD5`, y coincidio).
- `Install-DellRealtekDriver` marcaba error aunque instalaba bien: comparaba el campo equivocado
  (`Manufacturer` dice "Microsoft"; el proveedor real esta en `DriverProviderName`). Corregido.

## 7. Estado final (2026-11-08)

| Elemento | Estado |
|---|---|
| Controlador de audio | Microsoft `hdaudbus.inf` (10.0.26100.9711) |
| Intel SST OED | Deshabilitado / no presente |
| Codec Realtek | Dell/Realtek 6.0.8991.1 (`oem54`), HDA, **funciona** |
| Salidas | "Speakers/Headphones (Realtek Audio)", "Microphone (Realtek Audio)", ambos monitores: OK |
| Audio de monitores (con dock) | Presente, **pero no fiable** al conectar el dock; a veces exige reiniciar con el dock puesto |
| Bluetooth | No afectado |
| Waves/MaxxAudio | **No funciona** (necesita OED sano) |
| DSP de microfono / activacion por voz de Intel | **No funciona** |

## 8. No verificado

- Que el sonido "mejore" de forma objetiva: solo hay la percepcion del dueno.
- La ruta de `Install-DellRealtekDriver` partiendo del driver generico de Microsoft en el codec: se probo la
  ruta "ya instalado" y la ruta `-Force` (misma API), no el cambio desde cero.
- Si la app MaxxAudio Pro abre o hace algo util.
- Si existe un driver Intel SST mas nuevo (desde Intel, no desde Dell) que haga arrancar el OED: no se probo.
- La causa raiz del fallo del OED sigue **desconocida**.

## 9. Caminos que quedan

1. Averiguar por que el OED devuelve `0xC000009E` (unico camino soportado por Dell hacia Waves). Ideas sin
   probar: un paquete Intel SST mas nuevo de Intel, revisar el firmware/ME del equipo.
2. Emular el enlace de Waves por registro (riesgoso, sin soporte; descartado por ahora).
3. Quedarse como esta: driver de Dell en modo HDA, sin Waves.
