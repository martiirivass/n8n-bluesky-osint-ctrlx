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

- **Workflow 1 — Recolección manual**: se ejecuta a mano desde el editor de n8n. Login en Bluesky → búsqueda por keyword + país → separación de posts → limpieza/cálculo de métricas → guardado en Postgres (con deduplicación por `post_uri`).
- **Workflow 3 — Nueva búsqueda (bajo demanda)**: mismo pipeline de recolección que el Workflow 1, pero disparado por un Webhook POST en vez del botón manual. Permite lanzar una búsqueda nueva (keyword + país) directamente desde el formulario del dashboard, sin abrir n8n.
- **Workflow 2 — API para el dashboard**: siempre activo. Expone un Webhook que trae el historial completo de Postgres, calcula agregados (fuentes, frecuencia temporal, mayor engagement, posts por país) y devuelve todo en un JSON.
- **dashboard.html**: página estática (dark, estilo dossier editorial) que consume el Webhook y renderiza las métricas, el mapa interactivo y el listado de posts. No necesita servidor propio, se abre directo en el navegador.

---

## 1. Requisitos

- Docker Desktop instalado y corriendo
- Cuenta gratuita en [bsky.app](https://bsky.app) (para la recolección)
- Navegador (para el dashboard y la UI de n8n)

---

## 2. Levantar la infraestructura (Postgres + n8n)

### 2.1. Crear los contenedores

Si ya tenés contenedores de Postgres y n8n corriendo, saltá a 2.2. Si arrancás de cero:

```bash
docker run -d --name postgres_n8n -e POSTGRES_PASSWORD=tu_password -p 5432:5432 postgres
docker run -d --name n8n_local -p 5678:5678 n8nio/n8n:latest
```

### 2.2. Conectar ambos contenedores a una red común

**Importante**: si los contenedores no comparten red, n8n no puede resolver `postgres_n8n` por nombre (solo por IP, la cual cambia en cada reinicio del contenedor y rompe la conexión). Se recomienda crear la red desde el inicio para evitar este problema:

```bash
docker network create osint-net
docker network connect osint-net postgres_n8n
docker network connect osint-net n8n_local
```

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

Se recomienda correr recolecciones con cierta frecuencia (por ejemplo, una vez por día por keyword/país) para ir acumulando historial, ya que `searchPosts` devuelve principalmente los posts más recientes y buscar lo mismo muchas veces seguidas no trae datos nuevos. El límite actual es de 100 resultados por corrida (sin paginación — ver sección de pendientes).

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
- [ ] Paginación con `cursor` en `searchPosts` (tope actual: 100 resultados por corrida).
- [ ] Detectar links compartidos como texto plano vía `record.facets`, no solo como tarjeta embebida (`embed.external.uri`) — hoy se pierden fuentes externas que no generan preview card.
- [ ] Automatizar la recolección con Schedule Trigger (cuando haya un entorno con disponibilidad continua).
- [ ] Validación manual de una muestra de posts (relevancia temática).
- [ ] `.gitignore` del repo.
- [ ] Sticky Notes explicativas en el canvas de los workflows (útil para mostrar el pipeline en vivo durante la defensa).
- [ ] Autenticación en los Webhooks si se exponen fuera de `localhost` (hoy están abiertos, aceptable solo para uso local).
- [ ] Ampliar/revisar la sección 8 (ética/legal) con el director de tesis.
