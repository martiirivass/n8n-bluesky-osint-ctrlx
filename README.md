# Observatorio OSINT — Ciberseguridad en redes sociales de LATAM

Sistema de recolección y análisis de publicaciones públicas sobre ciberseguridad en América Latina, usando Bluesky (AT Protocol) como fuente de datos. El pipeline recolecta posts (manualmente o bajo demanda desde el dashboard), los limpia, calcula métricas de engagement y país, y los persiste en PostgreSQL; un dashboard web interactivo consume esos datos a través de un Webhook de n8n, con filtros por país/keyword y un mapa clickeable de la región.

## Arquitectura

```
Bluesky (searchPosts) → n8n (Workflow 1: Recolección manual) ──┐
                                                                  ├─→ PostgreSQL
dashboard.html (form "Nueva búsqueda") → n8n (Workflow 3: bajo demanda) ┘
                                                                     ↓
                           n8n (Workflow 2: API) ← ← ← ← ← ← ← ← ← ←┘
                                 ↓ (Webhook JSON)
                           dashboard.html (front)
```

- **Workflow 1 — Recolección manual**: se ejecuta a mano desde el editor de n8n. Login en Bluesky → búsqueda por keyword + país con **paginación por cursor** (hasta 10 páginas de 100 resultados) → separación de posts → limpieza/cálculo de métricas → guardado en Postgres (con deduplicación por `post_uri`).
- **Workflow 3 — Nueva búsqueda (bajo demanda)**: mismo pipeline de recolección que el Workflow 1 (incluida la paginación), pero disparado por un Webhook POST en vez del botón manual. Permite lanzar una búsqueda nueva (keyword + país) directamente desde el formulario del dashboard, sin abrir n8n.
- **Workflow 2 — API para el dashboard**: siempre activo. Expone un Webhook que trae el historial completo de Postgres, calcula agregados (fuentes, frecuencia temporal, mayor engagement, posts por país) y devuelve todo en un JSON.
- **dashboard.html**: página estática (dark, estilo dossier editorial) que consume el Webhook y renderiza las métricas, el mapa interactivo y el listado de posts. No necesita servidor propio, se abre directo en el navegador.

---

## 1. Requisitos

- Docker Desktop instalado y corriendo
- Cuenta gratuita en [bsky.app](https://bsky.app) (para la recolección)
- Navegador (para el dashboard y la UI de n8n)

---

## 2. Levantar la infraestructura (Postgres + n8n)

### 2.1. Crear la red y los contenedores (con volúmenes persistentes)

Si ya tenés contenedores creados, mirá 2.2 (para comprobar que tengan volumen y migrarlos si no) y después seguí en 2.3. Si arrancás de cero:

```bash
docker network create osint-net

docker run -d --name postgres_n8n --network osint-net --restart unless-stopped \
  -e POSTGRES_PASSWORD=tu_password -p 5432:5432 \
  -v postgres_data:/var/lib/postgresql \
  postgres

docker run -d --name n8n_local --network osint-net --restart unless-stopped \
  -p 5678:5678 \
  -v n8n_data:/home/node/.n8n \
  -e NODE_OPTIONS=--max-old-space-size=4096 \
  -e EXECUTIONS_DATA_SAVE_ON_SUCCESS=none \
  -e EXECUTIONS_DATA_PRUNE=true -e EXECUTIONS_DATA_PRUNE_MAX_COUNT=100 \
  n8nio/n8n:latest
```

**Por qué los volúmenes (`-v`) no son opcionales.** Sin ellos, los datos viven *dentro* del contenedor: si se lo elimina (`docker rm`), se pierden los workflows, las credenciales de n8n y la clave que las encripta. El volumen `n8n_data` guarda todo el directorio de datos de n8n (`/home/node/.n8n`) y `postgres_data` guarda la base con los posts. Cuidado con `docker system prune --volumes` y `docker rm -v`, que sí borran volúmenes.

**Por qué las variables de n8n.** En la recolección con paginación cada ejecución maneja cientos de posts; sin estos ajustes n8n llegó a quedarse sin memoria (`JavaScript heap out of memory`) y su base interna creció a más de 600 MB solo con el historial de ejecuciones. `NODE_OPTIONS` sube el tope de memoria a 4 GB, `EXECUTIONS_DATA_SAVE_ON_SUCCESS=none` evita guardar los datos de las ejecuciones exitosas (los errores sí se guardan), y `EXECUTIONS_DATA_PRUNE*` conserva solo las últimas 100. `--restart unless-stopped` levanta los contenedores solos cuando arranca Docker.

**Respaldo de los datos** (recomendado antes de cualquier cambio grande):

```bash
docker exec postgres_n8n pg_dump -U postgres -d postgres -t posts_bluesky > respaldo_posts.sql
```

### 2.2. Si ya tenías contenedores creados sin volumen

Si armaste n8n con el comando viejo (sin `-v`), se puede migrar **sin perder nada**. Con n8n detenido, se copia su directorio de datos a un volumen y se recrea el contenedor con **la misma imagen exacta** (para no disparar migraciones por cambio de versión):

```bash
docker stop n8n_local
docker volume create n8n_data
IMG=$(docker inspect n8n_local --format '{{.Image}}')
docker create --name n8n_new --network osint-net -p 5678:5678 --restart unless-stopped \
  -v n8n_data:/home/node/.n8n -e NODE_OPTIONS=--max-old-space-size=4096 \
  -e EXECUTIONS_DATA_SAVE_ON_SUCCESS=none -e EXECUTIONS_DATA_PRUNE=true -e EXECUTIONS_DATA_PRUNE_MAX_COUNT=100 $IMG
docker cp n8n_local:/home/node/.n8n/. - | docker cp - n8n_new:/home/node/.n8n/
docker rename n8n_local n8n_local_old && docker rename n8n_new n8n_local
docker start n8n_local
```

Quedan el contenedor viejo detenido (`n8n_local_old`) como respaldo; se elimina cuando se confirme que todo funciona. Ojo: `docker cp` no copia directo entre contenedores, por eso el `tar` intermedio; y hay que verificar después que las credenciales sigan funcionando (por ejemplo, con una búsqueda real), porque dependen de la clave de encriptación que vive en ese directorio.

### 2.3. Verificar que ambos estén corriendo

```bash
docker ps
```

Deberías ver `postgres_n8n` y `n8n_local` con status "Up". Si los contenedores ya existían de una sesión anterior y aparecen como `Exited`, alcanza con:

```bash
docker start postgres_n8n n8n_local
```

---

## 3. Configurar n8n

### 3.1. Acceder a la interfaz

Abrí `http://localhost:5678` en el navegador.

### 3.2. Crear la credential de Postgres

En n8n: **Settings → Credentials → New → Postgres**

| Campo | Valor |
|---|---|
| Host | `postgres_n8n` (el nombre del contenedor, no una IP) |
| Port | `5432` |
| Database | *(la que hayan definido)* |
| User | *(el usuario configurado en el contenedor)* |
| Password | *(la del contenedor)* |

### 3.3. Importar los workflows

En n8n: **Overview → Import from File** (o el ícono de importar en el menú "...")

Importar, en este orden:
1. `n8n/Workflow 1_ Recolección de datos - Bluesky OSINT V2.json`
2. `n8n/Workflow 2_ API para el dashboard - Bluesky OSINT V2.json`
3. `n8n/Workflow 3_ Nueva búsqueda desde el dashboard - Bluesky OSINT.json`

Una vez importados, en **cada nodo Postgres** de los tres workflows, seleccionar la credential creada en el paso 3.2 (las credentials no se exportan por seguridad, hay que volver a asignarlas). Ojo: a veces el dropdown ya muestra el nombre de la credential por herencia del export, pero no está realmente vinculada — si un nodo tira "Node does not have any credentials set" aunque el dropdown parezca tener algo seleccionado, abrilo y volvé a elegir la credential explícitamente de la lista.

### 3.4. Configurar la cuenta de Bluesky (Custom Auth — importante por seguridad)

1. Crear una cuenta gratuita en [bsky.app](https://bsky.app)
2. Ir a **Settings → Privacy and Security → App Passwords → Add App Password**
3. Copiar el App Password generado (no es la contraseña normal de la cuenta)
4. En **cada workflow que tenga un nodo "Nodo: LoginBluesky"** (Workflow 1 y Workflow 3), configurar así:
   - **Authentication** → `Generic Credential Type`
   - **Generic Auth Type** → `Custom Auth`
   - Crear una credential nueva con este JSON:
     ```json
     {
       "body": {
         "identifier": "tu_usuario.bsky.social",
         "password": "TU_APP_PASSWORD"
       }
     }
     ```

> ⚠️ **No pongas el usuario/password directo en el campo "Body" del nodo HTTP Request.** Ese campo se exporta tal cual al archivo `.json` del workflow — si en algún momento reexportás y commiteás, el password queda en texto plano en el historial de git para siempre (nos pasó una vez en este proyecto: un App Password real terminó pusheado a GitHub y tuvo que revocarse). El método Custom Auth guarda las credenciales encriptadas en el vault de n8n, igual que Postgres, y el export solo lleva una referencia.

### 3.5. Crear la tabla en Postgres

Ejecutar una vez el nodo **"Crear tabla posts_bluesky"** del Workflow 1 (botón "Execute step"), o correr manualmente el schema:

```bash
docker exec -i postgres_n8n psql -U tu_usuario -d tu_base < database/schema.sql
```

Si preferís arrancar con datos ya recolectados durante el desarrollo, usar `database/backup_con_datos.sql` en su lugar (dump completo con schema + datos reales).

### 3.6. Activar el Workflow 2 (API)

El Workflow 1 y el Workflow 3 se ejecutan bajo demanda, pero el **Workflow 2 tiene que quedar publicado/activo** para que el Webhook responda en todo momento:

1. Abrir el Workflow 2
2. Click en **"Publish"** (o el toggle "Active", según la versión de n8n)
3. Confirmar que la URL de producción responda: abrir `http://localhost:5678/webhook/dashboard-data` en una pestaña nueva — debería devolver un JSON.

Repetir el mismo paso de publicar para el **Workflow 3** (su webhook es el que recibe las búsquedas nuevas desde el dashboard).

> **Nota de troubleshooting — webhook en 404 pese a estar publicado**: si la URL de producción devuelve `404 "webhook is not registered"` aunque el workflow figure como activo/publicado, puede ser por dos motivos:
> 1. **Registro no refrescado**: reiniciar el contenedor fuerza el re-registro de los webhooks:
>    ```bash
>    docker restart n8n_local
>    ```
>    Esperar ~15-20 segundos y reintentar.
> 2. **El campo "Path" del nodo Webhook tiene la URL completa en vez de solo el segmento final.** Este bug nos costó bastante tiempo depurar: el campo debe decir solo `dashboard-data` (o `nueva-busqueda`), **nunca** `http://localhost:5678/webhook/dashboard-data`. Si tiene la URL completa, ningún reinicio lo va a arreglar — hay que corregir el campo Path manualmente y volver a publicar.
> 3. Si tenías versiones anteriores de un workflow importadas (sin el sufijo V2, de una sesión previa), asegurate de que **solo una quede activa** por cada path de webhook — dos workflows activos con el mismo path generan conflictos de registro.

### 3.7. Endpoint del Workflow 3 en el dashboard

El dashboard trae un campo **"Endpoint del webhook"** en el formulario de "Nueva búsqueda" que por defecto apunta a `http://localhost:5678/webhook/nueva-busqueda`. Si cambiaste el path del Webhook del Workflow 3, actualizá ese campo también.

---

## 4. Usar el pipeline de recolección

### Opción A — Manual, desde n8n (Workflow 1)

1. Abrir el Workflow 1 en n8n
2. En el nodo **"Keyword"**, ajustar `keyword` y `pais` si hace falta
3. Click en **"Execute workflow"**
4. Verificar en el nodo final que no haya errores (todos los nodos en verde)

### Opción B — Bajo demanda, desde el dashboard (Workflow 3)

1. Abrir `frontend/dashboard.html`
2. En el panel **"Nueva búsqueda"**, elegir una keyword del dropdown (o "+ Otra" para escribir una nueva) y un país
3. Click en **"Buscar y recolectar"** — el dashboard llama al Webhook, espera la respuesta (puede tardar unos segundos por el login + búsqueda en Bluesky) y se refresca solo al terminar

**Paginación**: cada búsqueda pide páginas de 100 resultados a `searchPosts` y avanza con el `cursor` que devuelve la API, hasta que el cursor se agota o se llega al tope de **10 páginas (1.000 resultados por corrida)**. El tope se cambia en el nodo **"HTTP Request" → Options → Pagination → Max Requests**. Entre páginas hay 500 ms de intervalo para no saturar la API, por lo que una búsqueda puede tardar varias decenas de segundos (el formulario del dashboard espera la respuesta).

Se recomienda correr recolecciones con cierta frecuencia para ir acumulando historial: buscar lo mismo muchas veces seguidas trae pocos datos nuevos. Cada corrida sigue teniendo un tope de 1.000 resultados, así que una búsqueda que lo alcance está truncada.

---

## 5. Usar el dashboard

Abrir `frontend/dashboard.html` con doble click (se abre en el navegador, no necesita servidor).

- **KPIs**: publicaciones recolectadas, días con actividad, promedio diario, y un donut con el % de cuentas *bridged* (puenteadas desde otra plataforma vía Bridgy Fed) vs. nativas.
- **Fuentes citadas** y **Frecuencia temporal**: se recalculan en el navegador a partir del set de posts filtrado — no vienen fijos del webhook.
- **Mapa interactivo de LATAM**: SVG con los países de la región; click en un país lo activa/desactiva como filtro. Los países con datos se resaltan distinto de los vacíos.
- **Filtros por país y keyword**: selects poblados dinámicamente con los valores reales que hay en tu base. Al filtrar, **todos** los gráficos y KPIs se recalculan (no solo la lista de posts).
- **Registro de publicaciones**: buscador por texto/autor, orden (fecha o engagement, asc/desc), y **exportar a CSV** (respeta los filtros y el buscador activos).
- **Nueva búsqueda**: dispara el Workflow 3 (ver sección 4, Opción B).
- **Auto-actualizar**: checkbox + intervalo (30s/60s/5min) para refrescar solo.
- **Última recolección real**: además de la hora de conexión, muestra el `fecha_insercion` más reciente entre todos los posts — para distinguir "cuándo cargó la página" de "cuándo se recolectó el dato realmente".
- **Impresión**: `Ctrl+P` aplica una hoja de estilos clara pensada para anexar una captura al documento de tesis (oculta los controles interactivos).

### Troubleshooting: error de CORS

El Workflow 2 ya trae configurado el header `Access-Control-Allow-Origin: *` en el nodo "Respond to Webhook". Si por algún motivo lo perdés (por ejemplo al reconstruir el workflow desde cero), agregalo en **Options → Response Headers** de ese nodo.

---

## 6. Estructura de datos (tabla `posts_bluesky`)

| Columna | Tipo | Descripción |
|---|---|---|
| `id` | SERIAL | PK autogenerada |
| `post_uri` | TEXT (UNIQUE) | Identificador único del post en Bluesky, usado para deduplicar |
| `post_cid` | TEXT | Hash de contenido del post |
| `texto` | TEXT | Contenido del post |
| `autor_handle` | TEXT | Handle del autor (ej. `usuario.bsky.social`) |
| `autor_display_name` | TEXT | Nombre visible del autor |
| `fecha_creacion` | TIMESTAMP | Fecha de creación del post en Bluesky |
| `fecha_indexado` | TIMESTAMP | Fecha en que Bluesky indexó el post |
| `likes`, `reposts`, `replies`, `quotes` | INT | Métricas de interacción |
| `engagement_score` | NUMERIC | `likes + reposts*2 + replies*1.5 + quotes*2` |
| `fuente_dominio` | TEXT | Dominio del link externo compartido, si tiene (ej. `infobae.com`) |
| `es_bridged` | BOOLEAN | `true` si la cuenta es un puente automático desde otra plataforma (vía Bridgy Fed) |
| `keyword_busqueda` | TEXT | Término de búsqueda que trajo este post |
| `fecha_insercion` | TIMESTAMP | Fecha en que se guardó en la base (default `NOW()`) |
| `pais` | TEXT | País asociado a la búsqueda que trajo este post (ej. `argentina`, `mexico`) |
| `posible_falso_positivo_geografico` | BOOLEAN | `true` si el texto contiene una frase que indica otro lugar con el mismo nombre que el país buscado (hoy: «New Mexico» cuando `pais = 'mexico'`). Solo marca, no descarta el post |
| `pagina_recoleccion` | INTEGER | Número de página de resultados (1 = la primera que devuelve la API) en la que apareció el post **en la última corrida que lo trajo**. Sirve para medir el sesgo de recencia; ver la nota de abajo |

### Notas de calidad de los datos

- **Sesgo de recencia.** `searchPosts` devuelve primero lo más reciente. Desde el 24/09/2026 cada búsqueda recorre todas las páginas que entrega la API (hasta 10); en la recolección completa (9 keywords × 5 países, 45 búsquedas) ninguna llegó al tope de páginas (la mayor fue de 507 posts en 6 páginas), o sea que el cursor se agotó en todas y no hubo truncamiento por el tope. Aun así el sesgo se reduce pero no desaparece: a igual cantidad de posts, la distribución por página sigue mostrando que lo reciente pesa más (página 1: 54 % de los posts son de los últimos 6 meses; páginas 2-3: 14 %; páginas 4 en adelante: 0 %). Un aumento de volumen reciente debe interpretarse con esto en mente.
- **`pagina_recoleccion` se pisa.** Como el guardado es un upsert por `post_uri`, si un post reaparece en otra corrida queda con la página de la **última** corrida, no de la primera. Hoy 4.015 de los 4.016 posts tienen página (todos fueron re-recolectados con paginación); un post que solo apareció en una corrida anterior a la paginación tendría `NULL`.
- **`keyword_busqueda` también se pisa**, por el mismo motivo: guarda la última búsqueda que encontró el post, por lo que los desgloses por keyword subestiman.
- **Colisión México / Nuevo México.** En la recolección completa, 81 de 1.509 posts con `pais = 'mexico'` (5,4 %) mencionan «New Mexico» (EE. UU.) y quedaron marcados con `posible_falso_positivo_geografico`; en la primera muestra de 600 posts eran 21 (3,5 %), lo que sugiere que la colisión pesa más a mayor profundidad histórica. El flag lo puso el propio workflow de n8n (verificado de punta a punta con datos reales: 0 posts sin marcar que debieran estarlo, 0 marcados en otros países). No detecta variantes como `new-mexico` (con guion). El dashboard todavía no excluye estos posts; hoy el Workflow 2 ya entrega el campo.
- **Keywords probadas y descartadas** (con respaldo en `database/backups/`, no versionado por contener handles reales):
  - `CERT`: de 126 posts etiquetados, solo 10 (8 %) usaban la sigla; el resto eran coincidencias sueltas con otras palabras (pasaportes, gastronomía, videojuegos). Se borraron los 113 de ruido puro (sin sigla en mayúscula ni ningún término de seguridad) y se conservaron 13.
  - `CSIRT` (reemplazo propuesto): preciso pero de volumen casi nulo, 11 posts entre los 5 países (Chile 9, Colombia 1, México 1, Argentina 0, Brasil 0). No permite comparar entre países.
  - `incidente de seguridad`: 149 posts, en su gran mayoría de seguridad **pública** (tiroteos, riñas, operativos policiales), no informática. Solo el 0-25 % tenía algún término informático. Se borraron 141; los otros 8 ya habían sido hallados por otras keywords y se les restauró su etiqueta original.
  - `ciberincidente`: sin ambigüedad de sentido pero sin volumen (0 resultados en 4 países y 1 en México). Los datos de los 5 países quedan con las 8 keywords base restantes.
  Lección metodológica: las palabras cortas o genéricas ("CERT", "seguridad") colisionan con otros significados; los términos que obligan al sentido informático ("ciberincidente") son precisos pero casi no se usan en redes sociales. La cobertura de un término técnico y su precisión tienden a ir en sentidos opuestos.
- **Bugs corregidos en los workflows de recolección** (los datos recolectados antes de la corrección están submuestreados): el nodo de limpieza corría en modo «All Items» y procesaba solo el primer resultado de cada búsqueda (1 post de ~50-100), y la extracción de `fuente_dominio` usaba `new URL()`, que falla en el sandbox del nodo Code y dejaba el campo en `null` en todos los posts.

---

## 7. Decisiones de diseño (para consulta rápida)

- **Bluesky en vez de Reddit/X**: Reddit rechazó la solicitud de acceso a su API, y su fallback (.json sin auth) fue discontinuado; X pasó a modelo pago por uso. Bluesky no requiere aprobación ni tiene costo.
- **Upsert por `post_uri`** en vez de Insert simple: evita duplicados si se corre una búsqueda varias veces sobre los mismos posts, y permite que las métricas de engagement se actualicen con el tiempo.
- **`engagement_score` compuesto** en vez de un solo campo tipo "score": da más peso a reposts/quotes (difusión activa) que a likes (aprobación pasiva).
- **Ejecución manual del Workflow 1** en vez de Schedule Trigger automático: decisión tomada por la disponibilidad del entorno local de desarrollo (la máquina no queda encendida 24/7). La arquitectura soporta pasar a ejecución programada sin cambios estructurales, reemplazando el nodo trigger manual por un Schedule Trigger.
- **n8n como capa de API** (Webhook) en vez de un backend dedicado: evita duplicar infraestructura para un caso de uso de lectura simple, reutilizando la herramienta ya presente en el pipeline.
- **Alcance ampliado a LATAM** en vez de limitarlo solo a Argentina: se agregó `pais` como dimensión propia (separada de la keyword de búsqueda) para poder segmentar la conversación de ciberseguridad por país sin mezclar ese eje con el temático.
- **Workflow 3 separado del Workflow 1** en vez de agregarle un trigger extra al mismo workflow: mantiene la separación entre "recolección batch manual" y "recolección bajo demanda vía HTTP" como dos responsabilidades distintas, cada una con su propio modo de disparo y su propio log de ejecuciones en n8n.
- **Agregación de métricas recalculada en el cliente** (dashboard) al aplicar filtros, en vez de pedirle al webhook datos ya filtrados: mantiene el Workflow 2 simple (siempre devuelve el historial completo) y evita tener que ir y volver al backend por cada combinación de filtro — el filtrado es una capa de presentación pura.
- **Credential Custom Auth para el login de Bluesky** en vez de hardcodear usuario/password en el body del nodo HTTP Request: ver la advertencia de seguridad en la sección 3.4.
- **Paginación nativa del nodo HTTP Request** en vez de un loop armado a mano con IF / Loop Over Items: n8n ya trae la lógica de pasar un parámetro (el `cursor`) de una respuesta a la siguiente, con tope de páginas e intervalo entre requests. Menos nodos y menos lugares donde equivocarse. Un nodo Code intermedio («Etiquetar página») numera cada página dentro de los posts antes del Split Out.
- **Marcar en vez de descartar** los posibles falsos positivos geográficos: el dato queda en la base con su flag y la decisión de excluirlo (o no) se toma en el análisis, no en el pipeline. La lista de colisiones conocidas es un objeto editable dentro del nodo de limpieza.
- **Mapa recortado a LATAM** en vez de mostrar el continente americano completo: coherencia con el alcance temático del proyecto (un mapa con EE.UU./Canadá visibles en un observatorio que se llama "LATAM" generaba una inconsistencia de encuadre).

---

## 8. Consideraciones éticas y legales de la recolección OSINT

> **Nota**: esta sección es un borrador de partida. Se recomienda revisarla con el director/a de tesis antes de la entrega final, ya que el criterio de la cátedra puede pedir mayor profundidad o un enfoque distinto.

- **Fuente exclusivamente pública**: el pipeline solo recolecta posts públicos de Bluesky, accesibles vía la API pública `app.bsky.feed.searchPosts` sin eludir ningún control de privacidad. No se accede a mensajes directos, contenido de cuentas privadas, ni ningún dato al que un usuario anónimo no pudiera acceder navegando la app.
- **Datos recolectados**: texto del post, handle y nombre visible del autor (información de perfil ya pública), métricas de interacción (likes/reposts/replies/quotes) y timestamps. No se recolectan direcciones de correo, teléfonos, ubicación geográfica precisa ni ningún dato sensible según la Ley 25.326 de Protección de Datos Personales (Argentina).
- **Cuentas *bridged***: una porción de los posts proviene de cuentas puenteadas automáticamente desde otras redes (vía Bridgy Fed) — esos usuarios no necesariamente eligieron estar en Bluesky de forma directa. El dashboard identifica estos casos explícitamente (`es_bridged`) para que cualquier análisis los distinga de las cuentas nativas.
- **Minimización y propósito**: los datos se usan exclusivamente con fines de investigación académica (análisis de tendencias de discurso sobre ciberseguridad en LATAM), no para perfilar, identificar ni tomar decisiones sobre personas individuales. No hay uso comercial.
- **Desactualización de datos**: si un usuario borra o edita un post en Bluesky después de haber sido recolectado, la copia en esta base no se actualiza ni se elimina automáticamente — es una limitación conocida a documentar si se publican hallazgos basados en estos datos.
- **Términos de servicio de Bluesky**: la recolección usa exclusivamente endpoints públicos de la AT Protocol API, dentro de los límites de uso razonable esperables de una cuenta de desarrollo/investigación. No se realiza scraping del HTML de la app ni se eluden mecanismos de autenticación.
- **Recomendación para publicación de resultados**: si se citan posts individuales en el documento de tesis o en una presentación, considerar anonimizar el handle del autor salvo que sea de una cuenta institucional/pública (medio de noticias, organismo, etc.), y evitar exponer negativamente a personas físicas identificables.

---

## 9. Pendientes / próximos pasos

- [ ] **Reexportar `Workflow 1 V2` y `Workflow 2 V2`** desde n8n después de cualquier cambio manual (actualmente el repo puede quedar desincronizado de lo que corre en la instancia real — pasó con el fix de Custom Auth y con el agregado de `pais`/`fecha_insercion` a la query del Workflow 2).
- [ ] Usar `posible_falso_positivo_geografico` y `pagina_recoleccion` en el dashboard (el Workflow 2 ya los entrega): excluir o resaltar los posibles falsos positivos y mostrar la distribución por página.
- [ ] **Mover la agregación al servidor** (Workflow 2): hoy devuelve todos los posts en un solo JSON (4.016 posts ≈ 2,9 MB; el dashboard lo renderiza sin problemas, pero crece linealmente con cada país o keyword nuevos). Que Postgres devuelva los agregados y el listado se pagine o se sirva aparte.
- [ ] Evaluar otras colisiones geográficas (ej. «Georgia», «Columbia») y agregarlas a `COLISIONES_GEOGRAFICAS` en el nodo de limpieza.
- [ ] Repetir la recolección de Brasil con keywords en portugués (las keywords en español favorecen los términos que se usan igual en inglés).
- [ ] Detectar links compartidos como texto plano vía `record.facets`, no solo como tarjeta embebida (`embed.external.uri`) — hoy se pierden fuentes externas que no generan preview card.
- [ ] Automatizar la recolección con Schedule Trigger (cuando haya un entorno con disponibilidad continua).
- [ ] Validación manual de una muestra de posts (relevancia temática).
- [ ] `.gitignore` del repo.
- [ ] Sticky Notes explicativas en el canvas de los workflows (útil para mostrar el pipeline en vivo durante la defensa).
- [ ] Autenticación en los Webhooks si se exponen fuera de `localhost` (hoy están abiertos, aceptable solo para uso local).
- [ ] Ampliar/revisar la sección 8 (ética/legal) con el director de tesis.
