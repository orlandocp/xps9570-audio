# Origen del driver Realtek

`drivers\realtek-6.0.8991.1\` **no esta en el repo**: son binarios con licencia de Dell/Realtek y no se
redistribuyen (`.gitignore` los excluye). Quien clone el repo debe rehacer la carpeta con esta guia.

## Paquete oficial

- Dell ID `T2GDD`, Realtek HD Audio 6.0.8991.1 A10 (431 MB, publicado por Dell el 2024-01-31):
  `https://downloads.dell.com/FOLDER06445667M/4/Realtek-High-Definition-Audio-Driver_T2GDD_WIN_6.0.8991.1_A10_02.EXE`
- Pagina de Dell: `http://www.dell.com/support/home/us/en/19/Drivers/DriversDetails?driverId=T2GDD`
- Encontrado en el catalogo publico de Dell (`https://downloads.dell.com/catalog/CatalogPC.cab`, version
  26.06.12) buscando el ID de sistema `087C` (XPS 15 9570).
- MD5 del EXE segun el catalogo: `3fa435cedcc7a55370c4b1196ef3ca77` (verificado el 2026-11-08). Firma Dell valida.

## Que archivos usa el script

Solo el driver base HDA (no el de Intel SST): `HDXDELLCSMB2018.inf`, `HDXRT.CAT`, `RTKVHD64.sys`,
`RTAIODAT.DAT`. Se extrajeron del EXE con 7-Zip, sin ejecutar el instalador. La copia original salio del
almacen de drivers de Windows (misma version, `oem54.inf`).

## Rehacer la carpeta

1. Baja el EXE y comprueba el MD5.
2. Abrelo con 7-Zip (no lo ejecutes), busca la carpeta que contiene `HDXDELLCSMB2018.inf` y copia esos
   4 archivos a `drivers\realtek-6.0.8991.1\`. (No se verifico la ruta exacta dentro del EXE.)
