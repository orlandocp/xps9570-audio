# Versiones y fechas

Todo verificado el **2026-11-08**. Si cambian los drivers o Windows, compara con esta tabla antes de culpar a
los scripts.

| Componente | Version / dato | Fecha |
|---|---|---|
| Equipo | Dell XPS 15 9570, ID de sistema Dell `087C` | - |
| BIOS | 1.27.0 | 2022 |
| Windows | 11 26H2, build 26300 (instalado el 2026-11-01) | 2026-11-01 |
| Driver Realtek de Dell (el que se instala) | 6.0.8991.1 A10, `HDXDELLCSMB2018.inf` | driver 2020-07-21; publicado por Dell 2024-01-31 |
| Catalogo de Dell donde se encontro | `CatalogPC.cab` version 26.06.12 | 2026-06-12 |
| Driver generico de Microsoft del controlador | `hdaudbus.inf` 10.0.26100.9711 | 2026-10-09 |
| Intel SST OED (el que falla) | IntcOED 10.23.3349.219 | 2020-07 |
| Bus Intel SST original de Dell | intcaudiobus 10.23.0.2427 (`SUBSYS_1028087C`) | 2019-02 |
| Extension Waves de Dell (instalada, sin efecto) | dellaudioextwaves 1.4.2.378 | 2020-04-01 |
| Dell Command Update | 5.7.0: sin drivers de audio nuevos para este modelo | 2026-11-08 |

Los scripts se probaron por ultima vez el 2026-11-08 con estas versiones. `Install-GenericAudioController` no
fija la version del driver generico: usa el que traiga Windows en ese momento.
