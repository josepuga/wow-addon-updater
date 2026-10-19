# WoW Addon Updater

Scripts Bash para automatizar el mantenimiento de compatibilidad de mis **addons de World of Warcraft** cuando Blizzard actualiza sus clientes, evitando los avisos de addons desactualizados.

## Funcionamiento

**Es recomendable ejecutar el script `0-publish-with-client-update.sh` que encadena la ejecucion de los demás**, se comprueba que no haya habido cambios den los clientes de wow antes de continuar. No obstante, los scripts funcionan de manera independiente:

1. `1-get-versions.sh` para obtener las últimas versiones de los clientes de WoW y guardarlas en un fichero CSV.
2. `2-update-addon.sh` para cada addon que se quiera actualizar.
3. `3-github.sh` Para publicar el addon en las plataformas en las que este, actualize el tag de github y subirlo al repositorio.
4. `4-bigwings.sh` Para publicar los addons en las diferentes plataformas.

## Requisitos

- Bash
- `curl` y `jq` (para `1-get-versions.sh`)
- Modificar la variable de `configuration.sh`.
  - La ruta raíz donde se encuentran nuestros addons en desarollo
  - El fichero donde se encuentran las API KEYS para publicar.
- Añadir el campo obligatorio `## TAG_ORDER` al fichero `.toc` de cada addon (sólo hay que hacerlo la primera vez). Ver más abajo `2-update-addons.sh`.
- Tener API KEYS de las diferentes plataformas de publicación.


## 1. `1-get-versions.sh`

Consulta la API de [BlizzTrack](https://blizztrack.com/) para obtener las últimas versiones de los diferentes clientes de World of Warcraft.

Genera una salida en formato CSV al fichero indicado en `configuration.sh`:

Cada línea del CSV contiene tres campos:

`CLIENTE,INTERFACE,VERSION_PUBLICA`

Ejemplo:

```csv
wow,120100,12.1.0.69933
wow_classic,50504,5.5.4.70032
wow_classic_era,11509,1.15.9.70003
wow_anniversary,20506,2.5.6.69795
wow_classic_beta,16001,1.60.1.70245
```

- **CLIENTE:** Identificador del cliente de WoW utilizado por BlizzTrack.
- **INTERFACE:** Número de versión utilizado en los ficheros `.toc` de los addons de WoW.
- **VERSION_PUBLICA:** Versión completa del cliente, incluido el número de compilación (_build_), tal como suele aparecer en los registros de cambios (_changelogs_), foros y notas de publicación. Sólo informativo.

Si no es posible obtener alguna versión, se utiliza `ERROR` como valor.

Este script sólo necesita ejecutarse cuando se quiera actualizar la información de las versiones de los clientes de WoW.

## 2. `2-update-addon.sh`

Actualiza el fichero `.toc` del addon utilizando las versiones obtenidas previamente mediante `get-versions.sh`.

**Uso:**

```bash
./2-update-addon.sh AddonName
```

El script compara las versiones del CSV con las declaradas en el fichero `.toc` del addon. Añade una entrada genérica a `CHANGELOG.md` si existe el fichero.

**Si detecta cambios:**

- Actualiza `## Interface:` con las últimas versiones de compatibilidad.
- Incrementa el número **PATCH** de la versión del addon (`MAJOR.MINOR.PATCH`) en `## Version:`.
- Conserva las versiones `Interface` existentes cuando no se dispone de información actualizada.
- Actualiza `## TAG_ORDER:` para mantener la correspondencia correcta entre los clientes y sus versiones `Interface`.
- Crea una copia de seguridad del fichero `.toc` original con la extensión `.toc.bak`.
- Si existe un fichero `CHANGELOG.md`, añade una entrada genérica "Updated Interface version".

**Si no detecta cambios**, el fichero `.toc` permanece intacto.

El script también muestra una advertencia si el fichero CSV tiene más de siete días de antigüedad.

## Configuración obligatoria del TOC: `TAG_ORDER`

El script `update-toc.sh` necesita un campo de metadatos adicional en el fichero `.toc` del addon:

```toc
## TAG_ORDER: wow wow_classic wow_classic_era wow_anniversary wow_classic_beta
## Interface: 120100, 50504, 11509, 20506, 16001
```

**`TAG_ORDER` es un campo de metadatos personalizado basado en la API de BlizzTrack**, no una directiva estándar de Blizzard. Indica al script a qué cliente de WoW corresponde cada versión de `Interface`.

La correspondencia se establece por posición:

| TAG_ORDER          | Interface | Cliente de WoW     |
| ------------------ | --------- | ------------------ |
| `wow`              | `120100`  | Retail             |
| `wow_classic`      | `50504`   | Classic progresivo |
| `wow_classic_era`  | `11509`   | Classic Era        |
| `wow_anniversary`  | `20506`   | Anniversary        |
| `wow_classic_beta` | `16001`   | Classic Beta       |

**Importante:**

- El número de elementos de `TAG_ORDER` debe coincidir con el número de versiones de `## Interface`.
- Ambos campos deben mantener el mismo orden.
- El orden en sí es arbitrario, siempre que se mantenga la correspondencia entre ambos campos.
- Sólo es necesario incluir los clientes de WoW compatibles con el addon.

El script actualiza automáticamente ambos campos cuando es necesario, manteniendo su correspondencia por posición aunque cambie el orden.

Sin `## TAG_ORDER`, el script no puede identificar a qué cliente de WoW pertenece cada versión de `Interface` y no actualizará el fichero `.toc`.


## 3. `3-github.sh`
**Uso:**

```bash
./3-github.sh AddonName
```

- Comprueba que el addon y su .toc existen.
- Valida la versión MAJOR.MINOR.PATCH.
- Comprueba que el repositorio está en la rama main.
- Exige que exista un tag Git local y que coincida con el remoto, tanto para tags ligeros como anotados.
- Si la versión del .toc es inferior a la del tag, termina con error.
- Si ambas versiones coinciden, termina correctamente sin modificar nada.
- Si la versión es superior, ejecuta git add, commit, tag y push.
- Si falla cualquier operación Git, termina con error.



## 4. `4-bigwigs.sh`
**Uso:**

```bash
./4-bigwigs.sh AddonName
```

Usando el script `release.sh` de `BigWings Packager`, se encarga de generar los ficheros ZIP correspondientes y subirlos a las siguientes plataformas:

- CurseForge
- WoWInterface
- Wago

Es necesario poner en la variable `api_keys_file` en `configuration.sh` la ruta del fichero que las contiene (no olvidar chmod 600 al fichero). Ejemplo de formato:

```ini
WAGO_API_TOKEN="YOUR WAGO API KEY"
CF_API_KEY="YOUR COURSE FORGE API KEY"
```

## Nota importante

Actualizar `## Interface` evita los avisos de addons desactualizados, pero **no garantiza que un addon sea compatible con los cambios introducidos en la API de Blizzard**.

La compatibilidad real debe comprobarse igualmente.

## Licencia

Licencia MIT.

Copyright (c) 2026 José Puga.
