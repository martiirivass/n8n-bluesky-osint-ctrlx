# Metodología de recolección y reproducibilidad

Este documento reúne lo necesario para reconstruir, desde el repositorio, cómo se obtuvo el corpus
analizado en la tesis: qué versión del código se usó, qué consultas exactas se enviaron a Bluesky,
con qué parámetros, qué se sabe (y qué no) de las corridas, y qué correcciones se aplicaron después
de la auditoría académica de segunda instancia.

Todo lo que se afirma acá sobre el corpus se calculó sobre `database/export_posts_latam.json`
(SHA-256 más abajo), salvo que se indique otra fuente.

---

## 1. Repositorio

| | |
|---|---|
| URL | https://github.com/martiirivass/n8n-bluesky-osint-ctrlx |
| Visibilidad | Pública |
| Licencia | Código: MIT (`LICENSE`). Documentación (`*.md`, `docs/`): CC BY 4.0 (`LICENSE-docs`) |
| Autores | Enzo Dengra, Martiniano Rivas — UTN Mendoza, Tecnicatura en Programación. Director: Alberto Cortez |

---

## 2. Versiones del código y del corpus

### 2.1. Código con el que se recolectó el corpus

La recolección final (paginada) se hizo con los workflows en el estado de estos commits. Los
hashes están completos, no truncados. Son los hashes **posteriores a la purga del historial del
2026-09-29** (sección 8): el contenido de código de cada commit es el mismo que antes, solo
cambió el hash (la equivalencia con los anteriores está en la sección 8).

| Commit | Fecha (UTC−3) | Qué fija |
|---|---|---|
| `e536dbc5fe16ae246ec1a3be225e17134243be50` | 2026-09-24 10:34 | Workflow 1 y Workflow 3 tal como recolectaron: paginación por cursor, flag `posible_falso_positivo_geografico`, columna `pagina_recoleccion`. Última modificación de ambos workflows antes de la auditoría. |
| `9838fd3c98b40c4db7ab3716ead6b844742f421b` | 2026-09-24 10:55 | Workflow 2 (API) que generó el export analizado. Última modificación del Workflow 2 antes de la auditoría. |
| `e549ae19ca0ed9331b942d65a49fcaed272cad3e` | 2026-09-24 17:41 | Script de sorteo de la validación manual (semilla 2026), que fija el hash del export. |
| `e16a93964049660f4d64b639c6a313db42fd0516` | 2026-09-28 11:35 | Estado del repositorio entregado para la auditoría. |

Commits anteriores relevantes para interpretar datos viejos: `32201dd38ad86ab966f37a5a86fa088ffdc348e8`
(2026-09-23) corrigió que la limpieza procesara un solo post por búsqueda y que `fuente_dominio`
quedara siempre en `null`. Los datos insertados antes de esa fecha fueron re-recolectados después.

### 2.2. Código corregido después de la auditoría

Las correcciones de la sección 7 están integradas en `main` y la versión evaluada es la etiqueta
**`v1.0-defensa`** (`git checkout v1.0-defensa`). El hash del commit etiquetado se obtiene con
`git rev-parse v1.0-defensa^{commit}`; no puede figurar dentro de este mismo archivo, porque
escribirlo cambiaría el hash.

### 2.3. Corpus

| Archivo | SHA-256 | Contenido |
|---|---|---|
| `database/export_posts_latam.json` | `73c35ee1454eaa63528350061186fdecf849812fcfb7842c048e9a0e8d373c00` | Respuesta del Workflow 2 (commit `9838fd3…`) sobre la base al cierre de la recolección. 3.908 publicaciones. Es el insumo de la muestra de validación y de los capítulos 5.x. |
| `database/export_posts_latam_v2.json` | `fbfe11d3ea7c9415b63983ca1441457baa94b70b01f01f29e1da710a4a5b5c6d` | Mismas 3.908 filas, en el mismo orden, procesadas con el Workflow 2 corregido (sección 7.1). Generado con `node herramientas/regenerar_export_corregido.mjs`, que verifica el hash de entrada. |

Ninguno de los dos archivos está versionado: contienen handles y textos de usuarios reales
(sección 8). Se entregan por canal privado a quien evalúe la tesis.

Diferencias entre ambos exports (verificadas campo por campo):

- `mayor_engagement`: **9,5 → 230** (sección 7.1). Es el único cambio sustantivo.
- `engagement_score` de cada post: pasa de texto (`"9.5"`) a número (`9.5`). Mismo valor.
- `resumen` agrega `posts_multi_pais` y `posts_multi_keyword` (ambos 0 en este corpus: ver 5.2).
- Se agregan `posts_por_keyword` y, por post, `paises` / `keywords`.
- `fuentes`, `fuente_dominante`, `frecuencia_temporal` y `posts_por_pais`: **idénticos**.
- La muestra de validación (`random.seed(2026)`, n=80) sale **idéntica** con cualquiera de los dos.

Ventana de inserción en la base (`fecha_insercion`, UTC): 2026-09-03 14:01 a 2026-09-24 14:16.
Fechas de publicación de los posts (`fecha_creacion`): 847 días distintos.

---

## 3. Consulta exacta y parámetros de `searchPosts`

### 3.1. Endpoint y autenticación

```
GET https://bsky.social/xrpc/app.bsky.feed.searchPosts
Authorization: Bearer <accessJwt>
```

El `accessJwt` se obtenía con `POST https://bsky.social/xrpc/com.atproto.server.createSession`
(App Password de una cuenta de los autores, guardado en el vault de credenciales de n8n), **una vez
por corrida**. Desde la corrección 7.5 la sesión se reutiliza entre corridas.

### 3.2. Parámetros enviados

| Parámetro | Valor | Nota |
|---|---|---|
| `q` | `"<keyword> <pais>"` | Concatenación con un espacio. Ver 3.3 |
| `limit` | `100` | Máximo que admite la API |
| `cursor` | el `cursor` de la respuesta anterior | Ausente en la primera página |
| `sort` | **no se envía** | La API usa su valor por defecto, `latest` (más recientes primero) |
| `lang` | **no se envía** | Sin filtro de idioma |
| `since`, `until`, `author`, `domain`, `tag`… | **no se envían** | Sin filtros adicionales |

Paginación (nodo HTTP Request de n8n, modo "update a parameter in each request"):

- Se pide la página siguiente mientras la respuesta traiga `cursor`.
- Tope: **10 páginas** por corrida (`maxRequests = 10`), es decir, 1.000 resultados.
- Intervalo entre páginas: **500 ms**.
- Criterio de corte: lo que ocurra primero entre (a) la respuesta no trae `cursor` (se agotaron los
  resultados que la API está dispuesta a devolver) y (b) se alcanzó el tope de 10 páginas.

### 3.3. Cadenas de consulta

El país se escribía en el nodo "Keyword" del Workflow 1 en **minúsculas y sin tildes**, y el mismo
valor se guardaba en la columna `pais`. Como las 3.908 filas del corpus tienen exactamente cinco
valores de `pais` (`argentina`, `brasil`, `chile`, `colombia`, `mexico`), esos son los sufijos
literales que se enviaron: `mexico` (no "México"), `brasil` (no "Brazil"). La keyword se enviaba
tal como figura en `keyword_busqueda`, **con tildes** cuando las tiene.

Keywords base (8) × países (5) = 40 combinaciones. Ejemplos de `q` literal:

```
ransomware argentina        ciberseguridad mexico        data breach brasil
filtración de datos chile   seguridad informática colombia
```

Keywords base: `ransomware`, `ciberseguridad`, `malware`, `hacking`, `data breach`, `ciberataque`,
`filtración de datos`, `seguridad informática`.

El corpus conserva además 26 publicaciones de búsquedas exploratorias que se descartaron como
keyword (README, sección 6): `CERT` (13, las que sobrevivieron a la limpieza), `CSIRT` (11),
`ciberincidente` (1) y `BCRA ciberseguridad` (1, anterior a la paginación: es la única con
`pagina_recoleccion` nula).

### 3.4. Profundidad de paginación alcanzada

Distribución de `pagina_recoleccion` en el corpus:

| Página | 1 | 2 | 3 | 4 | 5 | 6 | 7–10 | sin dato |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Posts | 2.017 | 938 | 547 | 279 | 121 | 5 | 0 | 1 |

Ninguna publicación quedó en páginas 7 a 10: ninguna búsqueda alcanzó el tope, el cursor se agotó
en todas. La más profunda fue `ransomware mexico` (6 páginas). **Salvedad**: `pagina_recoleccion`
guarda la página de la *última* corrida que trajo el post (se pisa en cada upsert), así que la
tabla describe la última pasada, no todas.

Publicaciones por combinación en el corpus (entre paréntesis, la página máxima observada). Estas
cifras aplican la regla de atribución de la sección 5.1:

| keyword | argentina | brasil | chile | colombia | mexico | total |
|---|---:|---:|---:|---:|---:|---:|
| ransomware | 326 (4) | 170 (2) | 197 (3) | 226 (3) | 466 (6) | 1385 |
| ciberseguridad | 114 (2) | 26 (1) | 266 (4) | 123 (2) | 376 (5) | 905 |
| malware | 47 (1) | 270 (3) | 32 (1) | 75 (1) | 158 (2) | 582 |
| hacking | 62 (2) | 99 (2) | 34 (1) | 46 (1) | 238 (3) | 479 |
| data breach | 32 (1) | 9 (1) | 17 (1) | 41 (1) | 136 (2) | 235 |
| ciberataque | 30 (1) | 43 (1) | 51 (1) | 17 (1) | 49 (1) | 190 |
| filtración de datos | 21 (1) | 1 (1) | 7 (1) | 3 (1) | 26 (1) | 58 |
| seguridad informática | 18 (1) | 3 (1) | 7 (1) | 7 (1) | 13 (1) | 48 |
| **total** | 650 | 621 | 611 | 538 | 1462 | 3882 |

(+ 26 de keywords exploratorias = 3.908.)

---

## 4. Corridas: qué se puede reconstruir y qué no

**No se pueden reconstruir la cantidad exacta de corridas por combinación ni sus fechas.** Hay que
declararlo como limitación. Los motivos son verificables:

1. n8n estaba configurado con `EXECUTIONS_DATA_SAVE_ON_SUCCESS=none` y
   `EXECUTIONS_DATA_PRUNE_MAX_COUNT=100` (README, sección 2.1, para evitar que su base interna
   creciera sin control). Las ejecuciones exitosas no quedaron registradas en n8n.
2. La base no tenía un registro de corridas. `fecha_insercion` se fija solo en el **primer** insert
   de cada post y ninguna corrida posterior la toca.
3. `keyword_busqueda` y `pais` guardan la **última** combinación que trajo el post. En una misma
   fila, entonces, `fecha_insercion` corresponde a una combinación y `keyword`/`pais` pueden
   corresponder a otra. Por eso no sirve agrupar `fecha_insercion` por combinación para contar
   corridas: se probó y los "lotes" resultantes cruzan combinaciones distintas en el mismo minuto.

Lo que sí se sabe:

- Modo: ejecución manual del Workflow 1, editando keyword y país en el nodo "Keyword" antes de cada
  corrida (una combinación por corrida). El Workflow 3 permitía hacer lo mismo desde el tablero.
- Ventana: primeras inserciones el 2026-09-03; última el 2026-09-24 14:16 UTC.
- La pasada completa con paginación se hizo el 2026-09-23/24, con los workflows que quedaron
  exportados en el commit `e536dbc…`.
- Cada combinación base se corrió al menos una vez con paginación (4.015 de los 4.016 posts
  existentes en ese momento tenían página; README, sección 6).

**Desde la corrección 7.3**, cada corrida queda registrada en `ejecuciones_recoleccion`
(inicio, fin, consulta `q` exacta, parámetros, páginas obtenidas, posts devueltos y si el cursor se
agotó). Esa tabla responde esta sección para cualquier recolección futura.

---

## 5. Atribución de keyword y país

### 5.1. Regla aplicada en el corpus

`posts_bluesky` tiene una fila por publicación (clave `post_uri`) y el guardado es un upsert que
**sobrescribe** `keyword_busqueda`, `pais` y `pagina_recoleccion`. Regla resultante: *cada
publicación queda atribuida a la última combinación keyword×país ejecutada que la devolvió*.
Las tablas por país y por keyword dependen, entonces, del orden en que se corrieron las búsquedas.

### 5.2. Magnitud

El corpus no conserva las pertenencias perdidas, así que la cifra exacta no se puede calcular
desde él (por eso `posts_multi_pais` y `posts_multi_keyword` dan 0 en el export v2: no es que no
haya casos, es que la base guardó uno solo por post). Dos indicadores:

- **Casos confirmados**: la auditoría señala al menos 8 (los posts de «incidente de seguridad» a
  los que se les restauró la etiqueta original, README sección 6).
- **Estimación textual** (`python` sobre el export; texto normalizado a minúsculas y sin tildes,
  búsqueda por palabra completa):
  - **163 publicaciones (4,2 %)** contienen las palabras de dos o más combinaciones keyword×país
    base, es decir, son candidatas a haber sido devueltas por más de una búsqueda.
  - **68 publicaciones (1,7 %)** mencionan dos o más de los cinco países. Las combinaciones más
    frecuentes: argentina+colombia+mexico (26), colombia+mexico (7), argentina+mexico (5),
    brasil+mexico (5).

  Es una aproximación, no una medición: el buscador de Bluesky no es una búsqueda literal (puede
  normalizar términos o coincidir con el texto de la tarjeta de un link) y no garantiza devolver
  todas las coincidencias. Sirve para dimensionar: el problema es de un orden mayor que 8 casos.

### 5.3. Medición exacta (procedimiento)

Con el pipeline corregido (modelo N:M, sección 7.2):

1. Aplicar `database/migraciones/001_capturas_ejecuciones_sesion_indices.sql`. El backfill deja en
   `capturas` la atribución única de cada post del corpus, con `origen = 'atribucion_unica_previa'`.
2. Correr las 40 combinaciones: `python herramientas/recolectar_combinaciones.py`.
3. Medir, **restringido a las publicaciones del corpus**:

```sql
WITH corte AS (
  SELECT post_uri FROM capturas WHERE origen = 'atribucion_unica_previa'
),
n AS (
  SELECT c.post_uri,
         count(DISTINCT (c.keyword_busqueda, c.pais)) AS combinaciones,
         count(DISTINCT c.pais)                       AS paises
  FROM capturas c JOIN corte USING (post_uri)
  WHERE c.origen = 'pipeline'
  GROUP BY c.post_uri
)
SELECT (SELECT count(*) FROM corte)                    AS posts_corpus,
       count(*)                                        AS reencontrados,
       count(*) FILTER (WHERE combinaciones > 1)       AS en_mas_de_una_combinacion,
       count(*) FILTER (WHERE paises > 1)              AS en_mas_de_un_pais
FROM n;
```

El resultado vale **a la fecha de la nueva corrida**: posts borrados desde entonces no reaparecen
y el índice de búsqueda de Bluesky cambia con el tiempo. Hay que informarlo así ("al DD/MM/2026,
X de las N publicaciones re-encontradas…").

### 5.4. Qué cambia en el sistema

Desde la corrección, un post que devuelven «ransomware mexico» y «malware chile» cuenta en México
**y** en Chile. La suma por país (o por keyword) puede superar el total de publicaciones, y el
tablero lo aclara en la nota metodológica.

---

## 6. Validación manual (sección 5.6 de la tesis)

Reproducción desde el repositorio público:

```
python validacion/calcular_estadisticas_validacion.py
```

usa `validacion/validacion_muestra_80_seudonimizada.csv` (sección 8). Verificado el 2026-09-29:

- El sorteo (`sortear_muestra_validacion.py`, semilla 2026) reproduce la muestra **byte a byte**
  a partir del export `73c35ee1…`.
- Precisión amplia (relevante + parcial): 68/76 = **89,5 %**, IC 95 % [80,6 %; 94,6 %]. Coincide
  con la tesis.
- **Precisión geográfica 85,5 %**: corresponde a 65/76, es decir, cuenta las 9 filas sin dato
  geográfico (`no_se`) como no correctas. El script informa 65/67 = 97,0 % excluyéndolas. Los dos
  cálculos son válidos, pero la tesis tiene que declarar el denominador que usa.
- **Acuerdo entre evaluadores (κ = 0,356 y κ = 0,758): no reproducible desde el repositorio.** La
  planilla del evaluador B que estaba versionada tiene las 40 filas sin clasificar. Hay que
  incorporar la planilla B completa (en `validacion/privado/`), correr
  `unir_clasificaciones.py` y `seudonimizar_validacion.py`, y versionar el CSV seudonimizado
  resultante.

---

## 7. Correcciones posteriores a la auditoría

### 7.1. Comparación numérica de `engagement_score` (crítico)

**Causa.** La columna es `NUMERIC`. El driver de PostgreSQL para Node.js (`pg`) devuelve `NUMERIC`
como *string* para no perder precisión. El nodo que calculaba el mayor engagement comparaba con
`>`: la primera comparación (string contra `-1`) es numérica, pero de ahí en adelante es string
contra string, que en JavaScript es **lexicográfica**. `"9.5" > "230.0"` es `true` porque el
carácter `"9"` es mayor que `"2"`.

**Reproducción.** Emulando esa comparación sobre las 3.908 filas del export se obtiene exactamente
el post de 9,5 que figura en el export original. El máximo real es **230** (`pais = mexico`,
`keyword = hacking`; 126 likes, 46 reposts, 4 respuestas, 3 citas; el identificador está en
`mayor_engagement` del export v2, que no se versiona).

**Alcance.**
- Afectado: el campo `mayor_engagement` del JSON del Workflow 2 (y por lo tanto del export) y el
  nodo "mayor engagement" del Workflow 1.
- **No afectado**: el tablero. Todas sus comparaciones y ordenamientos usan `parseFloat`, así que
  siempre mostró 230 como mayor engagement y ordenó bien por engagement. Tampoco se afectan los
  valores individuales de `engagement_score` ni ningún otro agregado del export.

**Corrección.** La consulta del Workflow 2 castea `engagement_score::float8` y el código fuerza
`Number()` antes de comparar (doble resguardo). Lo mismo en el Workflow 1.

### 7.2. Modelo N:M para keyword y país

Nueva tabla `capturas(post_uri, ejecucion_id, keyword_busqueda, pais, pagina, fecha_captura)`: una
fila cada vez que una corrida devuelve un post. Vista `pertenencias` con las combinaciones distintas
por post. `posts_bluesky.keyword_busqueda`/`pais` se mantienen como "última atribución" por
compatibilidad. El Workflow 2 devuelve, por post, `paises` y `keywords` (todas sus pertenencias) y
cuenta por pertenencia.

### 7.3. Registro de corridas

Nueva tabla `ejecuciones_recoleccion` (sección 4). La escriben los Workflows 1 y 3 al inicio y al
final de cada corrida. Una corrida que queda en `estado = 'en_curso'` sin `fin` es una corrida que
falló o se interrumpió.

### 7.4. Normalización del país

- Tabla `paises` (lista cerrada de 30 países de LATAM y el Caribe, con slug en minúsculas sin
  tildes) y claves foráneas desde `posts_bluesky`, `capturas` y `ejecuciones_recoleccion`: la base
  rechaza "México", "Mexico" o "brazil".
- Nodo "Normalizar búsqueda" en los Workflows 1 y 3: pasa a minúsculas, quita tildes, resuelve
  alias en inglés (`brazil` → `brasil`) y rechaza lo que no esté en la lista.
- Tablero: el formulario usa la misma lista (sale del mapa) y envía el slug. **Hallazgo adicional**:
  el desplegable anterior no incluía México y enviaba las etiquetas con mayúscula y tilde
  ("Brasil", "Perú"), distintas de lo que guardaba el Workflow 1.

### 7.5. Sesión de Bluesky y límite de tasa

- La sesión se guarda en `bluesky_sesion` y se reutiliza: si el `accessJwt` vence en más de 10
  minutos se usa tal cual; si no, se renueva con `com.atproto.server.refreshSession`; solo si eso
  falla (o no hay sesión) se llama a `createSession`. Los vencimientos se leen del claim `exp` del
  JWT. Las 40 combinaciones consumen, como mucho, un `createSession`, frente a 40 antes (el límite
  de ese endpoint es 30 cada 5 minutos y 300 por día por cuenta).
- Reintento ante errores transitorios (HTTP 429, 5xx) en la búsqueda: hasta 4 intentos con 5 s de
  espera (máximo que permite n8n por nodo), y 3 intentos en el login. **Limitación**: la espera es
  fija, no respeta el encabezado `ratelimit-reset`. Con la sesión reutilizada, la búsqueda es el
  único endpoint que se llama en volumen, y su límite es mucho más amplio.

### 7.6. Seguridad de los webhooks

- `/dashboard-data` y `/nueva-busqueda` exigen el encabezado `X-API-Key` (credential "Header Auth"
  de n8n).
- CORS restringido a `http://localhost:8080` y `http://127.0.0.1:8080` (opción *Allowed Origins*
  del Webhook y `Access-Control-Allow-Origin` en las respuestas, que antes era `*`). El tablero
  tiene que servirse desde ese origen (README, sección 5).
- **Riesgos que siguen abiertos** (aceptables en uso local, a declarar si se expone): tráfico HTTP
  sin TLS; la clave es un secreto compartido sin expiración ni rotación; `/dashboard-data` sigue
  devolviendo handles a quien tenga la clave; los tokens de sesión de Bluesky se guardan en claro
  en la base (el `refreshJwt` permite operar la cuenta hasta que vence o se revoca el App
  Password).

### 7.7. Índices

Sobre `posts_bluesky(pais)`, `(keyword_busqueda)`, `(fecha_creacion)`,
`capturas(post_uri)`, `capturas(pais, keyword_busqueda)` y
`ejecuciones_recoleccion(keyword_busqueda, pais, inicio)`.

### 7.8. Otros ajustes

- Orden del listado del Workflow 2: `ORDER BY fecha_creacion DESC, post_uri`. Antes los empates de
  fecha (49 publicaciones en el corpus) salían en orden arbitrario, así que dos exports de la misma
  base podían tener distinto hash y, en consecuencia, distinta muestra de validación.
- El nodo que creaba la tabla corría una vez **por cada post** en cada ejecución; ahora está
  desconectado del flujo y se ejecuta una sola vez al instalar.

---

## 8. Datos personales en el repositorio

- `database/export_posts_latam.json` **nunca** estuvo en el historial de git (verificado con
  `git log --all`).
- Sí estuvieron versionados, con handles, textos y/o URIs de posts (que contienen el DID de la
  cuenta, resoluble al perfil): `database/backup_con_datos.sql`,
  `validacion/validacion_muestra_80.csv` y las planillas `validacion/planilla_evaluador_{A,B}.xlsx`.
  Se sacaron del control de versiones (quedan en `database/backups/` y `validacion/privado/`,
  ignorados por git) y se reemplazaron por `validacion/validacion_muestra_80_seudonimizada.csv`.
- Seudonimización: `post_uri` → `id_publicacion` = HMAC-SHA256 con clave privada (no versionada),
  truncado a 16 caracteres hex; se eliminan `texto` y `autor_handle`. **No alcanza con reemplazar el
  handle**: el DID del `post_uri` y el texto literal (buscable en Bluesky) identifican igual al
  autor.
- **Purga del historial (2026-09-29)**: con `git filter-repo` se eliminaron esos cuatro archivos de
  todos los commits y se reemplazó por `***REVOCADO***` el App Password que había quedado en un
  commit de los workflows (revocado en la cuenta de Bluesky antes de la purga). Se verificó commit
  por commit que no queda ninguno de esos archivos, ni la contraseña, ni ningún DID de cuenta. El
  commit "Actualizo datos en el backup de la base de datos" quedó vacío y desapareció. Se pidió a
  GitHub Support que borre de sus cachés los commits anteriores.

  Equivalencia de hashes citados antes de la purga:

  | Antes | Después |
  |---|---|
  | `bac11b3fc8280d76b329a3f4751f6806db7baebd` | `e536dbc5fe16ae246ec1a3be225e17134243be50` |
  | `4897d47b9443e81980d82ee54495e56914819f92` | `9838fd3c98b40c4db7ab3716ead6b844742f421b` |
  | `82c51771f3ef8371a0ba69eb7314f8715896eab7` | `e549ae19ca0ed9331b942d65a49fcaed272cad3e` |
  | `fcd69cbe914c56350bbdf63eb48eac1a105346d5` | `e16a93964049660f4d64b639c6a313db42fd0516` |
  | `c4955cd8cd756ad71faa5ac164919f5a146ee3c5` | `32201dd38ad86ab966f37a5a86fa088ffdc348e8` |
  | `30154ed5cd75219735ee7a514fdbd4ebdb555dcf` | `faf932b8ee945a521acb5e187adff152f41100ff` |

---

## 9. Pendiente de verificación en n8n

Las consultas SQL de los workflows se probaron contra PostgreSQL 18 con las 3.908 filas reales, y
el código de los nodos Code con un arnés que emula a n8n. Queda probar en la instancia de n8n,
después de importar los workflows:

- [ ] Importación de los tres workflows y asignación de credentials (Postgres, Custom Auth de
      Bluesky y la nueva Header Auth).
- [ ] Una corrida real del Workflow 1: login (sin sesión) → segunda corrida reutilizando la sesión
      → fila en `ejecuciones_recoleccion` con `estado = 'ok'` y filas en `capturas`.
- [ ] Workflow 3 desde el tablero servido en `http://localhost:8080`: respuesta 200 con la clave,
      401/403 sin ella, y que el navegador no bloquee por CORS.
