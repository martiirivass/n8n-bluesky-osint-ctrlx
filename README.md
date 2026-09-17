# Observatorio OSINT — Ciberseguridad en redes sociales argentinas

Sistema de recolección y análisis de publicaciones públicas sobre ciberseguridad en Argentina, usando Bluesky (AT Protocol) como fuente de datos. El pipeline recolecta posts, los limpia, calcula métricas de engagement y los persiste en PostgreSQL; un dashboard web consume esos datos a través de un Webhook de n8n.

## Arquitectura

```
Bluesky (searchPosts) → n8n (Workflow 1: Recolección) → PostgreSQL
                                                              ↓
                          n8n (Workflow 2: API) ← ← ← ← ← ← ←┘
                                ↓ (Webhook JSON)
                          dashboard.html (front)
```

- **Workflow 1 — Recolección**: se ejecuta manualmente. Login en Bluesky → búsqueda por keyword → separación de posts → limpieza/cálculo de métricas → guardado en Postgres (con deduplicación por `post_uri`).
- **Workflow 2 — API para el dashboard**: siempre activo. Expone un Webhook que trae el historial completo de Postgres, calcula agregados (fuentes, frecuencia temporal, mayor engagement) y devuelve todo en un JSON.
- **dashboard.html**: página estática que consume el Webhook y renderiza las métricas y el listado de posts. No necesita servidor propio, se abre directo en el navegador.

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

Deberías ver `postgres_n8n` y `n8n_local` con status "Up".

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
1. `n8n/workflow-recoleccion.json`
2. `n8n/workflow-api-dashboard.json`

Una vez importados, en **cada nodo Postgres** de ambos workflows, seleccionar la credential creada en el paso 3.2 (las credentials no se exportan por seguridad, hay que volver a asignarlas).

### 3.4. Configurar la cuenta de Bluesky

1. Crear una cuenta gratuita en [bsky.app](https://bsky.app)
2. Ir a **Settings → Privacy and Security → App Passwords → Add App Password**
3. Copiar el App Password generado (no es la contraseña normal de la cuenta)
4. En el Workflow 1, nodo **"Login Bluesky"**, completar el body JSON con:
   ```json
   {
     "identifier": "tu_usuario.bsky.social",
     "password": "TU_APP_PASSWORD"
   }
   ```

### 3.5. Crear la tabla en Postgres

Ejecutar una vez el nodo **"Crear tabla posts_bluesky"** del Workflow 1 (botón "Execute step"), o correr manualmente el schema:

```bash
docker exec -i postgres_n8n psql -U tu_usuario -d tu_base < database/schema.sql
```

Si preferís arrancar con los datos ya recolectados durante el desarrollo, usar `database/backup_con_datos.sql` en su lugar.

### 3.6. Activar el Workflow 2 (API)

El Workflow 1 se ejecuta manualmente, pero el **Workflow 2 tiene que quedar publicado/activo** para que el Webhook responda en todo momento:

1. Abrir el Workflow 2
2. Click en **"Publish"** (o el toggle "Active", según la versión de n8n)
3. Confirmar que la URL de producción responda: abrir `http://localhost:5678/webhook/dashboard-data` en una pestaña nueva — debería devolver un JSON.

> **Nota de troubleshooting**: si la URL de producción devuelve 404 ("webhook is not registered") aunque el workflow figure como activo, reiniciar el contenedor fuerza el re-registro de los webhooks:
> ```bash
> docker restart n8n_local
> ```
> Esperar ~15 segundos y volver a publicar/activar el workflow.

---

## 4. Usar el pipeline de recolección

1. Abrir el Workflow 1 en n8n
2. En el nodo **"Keyword"**, ajustar el término de búsqueda si hace falta (por defecto: `ciberseguridad argentina`)
3. Click en **"Execute workflow"**
4. Verificar en el nodo final que no haya errores (todos los nodos en verde)

Se recomienda correrlo manualmente con cierta frecuencia (por ejemplo, una vez por día) para ir acumulando historial, ya que `searchPosts` devuelve principalmente los posts más recientes y correr el workflow muchas veces seguidas no trae datos nuevos.

---

## 5. Usar el dashboard

1. Abrir `frontend/dashboard.html` con doble click (se abre en el navegador, no necesita servidor)
2. Confirmar que el campo de URL (arriba a la derecha) diga `http://localhost:5678/webhook/dashboard-data`
3. Click en **"Actualizar datos"**

### Troubleshooting: error de CORS

Si el dashboard muestra error de conexión y la consola del navegador (F12 → Console) dice algo de `CORS policy`, hay que agregar un header de respuesta en el Workflow 2:

1. Abrir el nodo **"Respond to Webhook"**
2. En **Options → Response Headers**, agregar:
   - Name: `Access-Control-Allow-Origin`
   - Value: `*`
   - Tipo de campo: **Fixed** (no expresión)
3. Guardar y volver a publicar el workflow

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

---

## 7. Decisiones de diseño (para consulta rápida)

- **Bluesky en vez de Reddit/X**: Reddit rechazó la solicitud de acceso a su API, y su fallback (.json sin auth) fue discontinuado; X pasó a modelo pago por uso. Bluesky no requiere aprobación ni tiene costo.
- **Upsert por `post_uri`** en vez de Insert simple: evita duplicados si se corre el workflow varias veces sobre los mismos posts, y permite que las métricas de engagement se actualicen con el tiempo.
- **`engagement_score` compuesto** en vez de un solo campo tipo "score": da más peso a reposts/quotes (difusión activa) que a likes (aprobación pasiva).
- **Ejecución manual del Workflow 1** en vez de Schedule Trigger automático: decisión tomada por la disponibilidad del entorno local de desarrollo (la máquina no queda encendida 24/7). La arquitectura soporta pasar a ejecución programada sin cambios estructurales, reemplazando el nodo trigger manual por un Schedule Trigger.
- **n8n como capa de API** (Webhook) en vez de un backend dedicado: evita duplicar infraestructura para un caso de uso de lectura simple, reutilizando la herramienta ya presente en el pipeline.

---

## 8. Pendientes / próximos pasos

- [ ] Automatizar la recolección con Schedule Trigger (cuando haya un entorno con disponibilidad continua)
- [ ] Ampliar a más de un keyword en paralelo
- [ ] Validación manual de una muestra de posts (relevancia temática)
- [ ] Documentar consideraciones éticas/legales de la recolección OSINT
