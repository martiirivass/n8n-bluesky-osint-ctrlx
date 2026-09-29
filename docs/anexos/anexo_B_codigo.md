# Anexo B — Código de los workflows de n8n

Generado con `python herramientas/extraer_anexos.py` a partir de los archivos exportados de n8n. No editar a mano.

| Archivo | SHA-256 |
|---|---|
| `n8n/Workflow 1_ Recolección de datos - Bluesky OSINT V2.json` | `e7a45b60a24c079ccd778426682ffe54d304658f17611adef9477dbc109ef34e` |
| `n8n/Workflow 2_ API para el dashboard - Bluesky OSINT V2.json` | `b571a1f02cd43c54a1bff358fffc452488427ac1dabd45c1ebdafb05a189d171` |
| `n8n/Workflow 3_ Nueva búsqueda desde el dashboard - Bluesky OSINT.json` | `654c067460add7dc36d8e38bd7055b1e7e2af2e036b66df31ea821fb16b31ef1` |

## Workflow 1: Recolección de datos - Bluesky OSINT V2

### Conexiones

- Limpieza y recopilación de datos → Insertar/actualizar posts
- Keyword → Normalizar búsqueda
- Frecuencia temporal → Promedio diario
- Nodo: LoginBluesky → Guardar sesión
- HTTP Request → Etiquetar página
- Fuentes → Fuente dominante
- Traer historial completo → Conteo de items, Fuentes, Frecuencia temporal, mayor engagement, Posts por pais
- Insertar/actualizar posts → Preparar capturas
- Separar posts individuales → Limpieza y recopilación de datos
- Ejecución con click manual → Keyword
- Etiquetar página → Resumen de corrida
- Registrar inicio de ejecución → Leer sesión Bluesky
- Leer sesión Bluesky → Evaluar sesión
- Evaluar sesión → ¿Sesión vigente?
- ¿Sesión vigente? (salida 0) → HTTP Request
- ¿Sesión vigente? (salida 1) → ¿Se puede refrescar?
- ¿Se puede refrescar? (salida 0) → Refrescar sesión
- ¿Se puede refrescar? (salida 1) → Nodo: LoginBluesky
- Refrescar sesión (salida 0) → Guardar sesión
- Refrescar sesión (salida 1) → Nodo: LoginBluesky
- Guardar sesión → HTTP Request
- Resumen de corrida → Cerrar ejecución
- Cerrar ejecución → Recuperar páginas
- Recuperar páginas → Separar posts individuales
- Preparar capturas → Insertar capturas
- Normalizar búsqueda → Registrar inicio de ejecución
- Insertar capturas → Traer historial completo

### Nodos (en orden de recorrido del grafo, desde el disparador)

#### Crear/migrar esquema (ejecutar una vez)

Tipo: `postgres` (v2.6) · executeOnce=True

```sql
CREATE TABLE IF NOT EXISTS posts_bluesky (
  id SERIAL PRIMARY KEY,
  post_uri TEXT UNIQUE,
  post_cid TEXT,
  texto TEXT,
  autor_handle TEXT,
  autor_display_name TEXT,
  fecha_creacion TIMESTAMP,
  fecha_indexado TIMESTAMP,
  likes INT,
  reposts INT,
  replies INT,
  quotes INT,
  engagement_score NUMERIC,
  fuente_dominio TEXT,
  es_bridged BOOLEAN,
  keyword_busqueda TEXT,
  fecha_insercion TIMESTAMP DEFAULT NOW(),
  pais TEXT,
  posible_falso_positivo_geografico BOOLEAN DEFAULT FALSE,
  pagina_recoleccion INTEGER
);

--
-- Migración 001 — correcciones de la auditoría académica (2ª instancia)
--
-- Qué hace (idempotente: se puede correr más de una vez sin romper nada):
--   1. Tabla de referencia `paises` (lista cerrada) + FK desde posts_bluesky.pais.
--   2. Tabla `ejecuciones_recoleccion`: una fila por corrida de búsqueda (fecha, consulta exacta,
--      parámetros de searchPosts, páginas recorridas, si el cursor se agotó).
--   3. Tabla `capturas` (modelo N:M): una fila por cada vez que una combinación keyword×país
--      devolvió un post. posts_bluesky.keyword_busqueda / pais quedan como "última atribución"
--      por compatibilidad, pero los desgloses por país y keyword se calculan desde `capturas`.
--   4. Tabla `bluesky_sesion`: reutiliza la sesión de Bluesky entre corridas (refreshSession)
--      en vez de llamar a createSession en cada una.
--   5. Índices para agregación del lado del servidor (recomendación 8.9).
--
-- Uso:
--   docker exec -i postgres_n8n psql -U <usuario> -d <base> < database/migraciones/001_capturas_ejecuciones_sesion_indices.sql
--
-- IMPORTANTE sobre el backfill de `capturas`: los datos recolectados antes de esta migración
-- solo conservan UNA atribución por post (la última búsqueda que lo trajo; el upsert pisó las
-- anteriores). El backfill copia esa única atribución con origen = 'atribucion_unica_previa'.
-- Las pertenencias múltiples perdidas NO se pueden reconstruir desde la base: solo re-ejecutando
-- las búsquedas con el pipeline nuevo (ver METODOLOGIA.md, sección 5).
--


-- 1. Países: lista cerrada ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS paises (
    slug   TEXT PRIMARY KEY CHECK (slug ~ '^[a-z]+( [a-z]+)*$'),  -- minúsculas, sin tildes
    nombre TEXT NOT NULL,
    iso2   CHAR(2) NOT NULL UNIQUE
);

INSERT INTO paises (slug, nombre, iso2) VALUES
    ('argentina', 'Argentina', 'AR'),
    ('bahamas', 'Bahamas', 'BS'),
    ('belice', 'Belice', 'BZ'),
    ('bolivia', 'Bolivia', 'BO'),
    ('brasil', 'Brasil', 'BR'),
    ('chile', 'Chile', 'CL'),
    ('colombia', 'Colombia', 'CO'),
    ('costa rica', 'Costa Rica', 'CR'),
    ('cuba', 'Cuba', 'CU'),
    ('dominica', 'Dominica', 'DM'),
    ('ecuador', 'Ecuador', 'EC'),
    ('el salvador', 'El Salvador', 'SV'),
    ('guatemala', 'Guatemala', 'GT'),
    ('guyana', 'Guyana', 'GY'),
    ('haiti', 'Haití', 'HT'),
    ('honduras', 'Honduras', 'HN'),
    ('jamaica', 'Jamaica', 'JM'),
    ('mexico', 'México', 'MX'),
    ('nicaragua', 'Nicaragua', 'NI'),
    ('panama', 'Panamá', 'PA'),
    ('paraguay', 'Paraguay', 'PY'),
    ('peru', 'Perú', 'PE'),
    ('puerto rico', 'Puerto Rico', 'PR'),
    ('republica dominicana', 'República Dominicana', 'DO'),
    ('san vicente y las granadinas', 'San Vicente y las Granadinas', 'VC'),
    ('santa lucia', 'Santa Lucía', 'LC'),
    ('surinam', 'Surinam', 'SR'),
    ('trinidad y tobago', 'Trinidad y Tobago', 'TT'),
    ('uruguay', 'Uruguay', 'UY'),
    ('venezuela', 'Venezuela', 'VE')
ON CONFLICT (slug) DO NOTHING;

-- Normaliza lo que ya exista en posts_bluesky antes de exigir la FK (minúsculas, sin tildes).
UPDATE posts_bluesky
SET pais = translate(lower(btrim(pais)), 'áéíóúüñ', 'aeiouun')
WHERE pais IS NOT NULL
  AND pais <> translate(lower(btrim(pais)), 'áéíóúüñ', 'aeiouun');

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'posts_bluesky_pais_fkey') THEN
        ALTER TABLE posts_bluesky
            ADD CONSTRAINT posts_bluesky_pais_fkey FOREIGN KEY (pais) REFERENCES paises (slug) NOT VALID;
        -- Si esto falla, hay valores de pais fuera de la lista: revisarlos a mano antes de seguir.
        ALTER TABLE posts_bluesky VALIDATE CONSTRAINT posts_bluesky_pais_fkey;
    END IF;
END $$;

-- 2. Registro de ejecuciones --------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS ejecuciones_recoleccion (
    id                SERIAL PRIMARY KEY,
    workflow          TEXT NOT NULL,                 -- 'W1-manual' | 'W3-webhook'
    n8n_execution_id  TEXT,
    keyword_busqueda  TEXT NOT NULL,
    pais              TEXT NOT NULL REFERENCES paises (slug),
    consulta_q        TEXT NOT NULL,                 -- valor EXACTO enviado en q=
    limit_por_pagina  INTEGER NOT NULL,
    max_paginas       INTEGER NOT NULL,
    intervalo_ms      INTEGER NOT NULL,
    sort              TEXT,                          -- NULL = no se envía (default de la API: latest)
    lang              TEXT,                          -- NULL = no se envía (sin filtro de idioma)
    inicio            TIMESTAMPTZ NOT NULL DEFAULT now(),
    fin               TIMESTAMPTZ,
    paginas_obtenidas INTEGER,
    posts_devueltos   INTEGER,
    cursor_agotado    BOOLEAN,                       -- false => se cortó por el tope de páginas
    estado            TEXT NOT NULL DEFAULT 'en_curso'
                      CHECK (estado IN ('en_curso', 'ok', 'error'))
);

-- 3. Capturas (N:M post × combinación de búsqueda) -----------------------------------------------

CREATE TABLE IF NOT EXISTS capturas (
    id               SERIAL PRIMARY KEY,
    post_uri         TEXT NOT NULL REFERENCES posts_bluesky (post_uri) ON DELETE CASCADE,
    ejecucion_id     INTEGER REFERENCES ejecuciones_recoleccion (id) ON DELETE CASCADE,
    keyword_busqueda TEXT NOT NULL,
    pais             TEXT NOT NULL REFERENCES paises (slug),
    pagina           INTEGER,
    fecha_captura    TIMESTAMPTZ NOT NULL DEFAULT now(),
    origen           TEXT NOT NULL DEFAULT 'pipeline'
                     CHECK (origen IN ('pipeline', 'atribucion_unica_previa'))
);

-- Un post aparece una sola vez por corrida (el cursor de la API puede repetir un post entre páginas).
CREATE UNIQUE INDEX IF NOT EXISTS capturas_ejecucion_post_uq
    ON capturas (ejecucion_id, post_uri) WHERE ejecucion_id IS NOT NULL;
-- El backfill deja una sola fila por post.
CREATE UNIQUE INDEX IF NOT EXISTS capturas_backfill_uq
    ON capturas (post_uri) WHERE origen = 'atribucion_unica_previa';

INSERT INTO capturas (post_uri, ejecucion_id, keyword_busqueda, pais, pagina, fecha_captura, origen)
SELECT post_uri, NULL, keyword_busqueda, pais, pagina_recoleccion,
       COALESCE(fecha_insercion, now()), 'atribucion_unica_previa'
FROM posts_bluesky
WHERE keyword_busqueda IS NOT NULL AND pais IS NOT NULL
ON CONFLICT DO NOTHING;

-- Vista de pertenencias distintas: un post cuenta UNA vez por cada combinación que lo trajo,
-- sin importar cuántas veces se repitió esa combinación.
CREATE OR REPLACE VIEW pertenencias AS
SELECT DISTINCT post_uri, keyword_busqueda, pais
FROM capturas;

-- 4. Sesión de Bluesky reutilizable -------------------------------------------------------------

CREATE TABLE IF NOT EXISTS bluesky_sesion (
    id             SMALLINT PRIMARY KEY DEFAULT 1 CHECK (id = 1),  -- una sola fila
    did            TEXT,
    handle         TEXT,
    access_jwt     TEXT NOT NULL,
    refresh_jwt    TEXT NOT NULL,
    origen         TEXT NOT NULL CHECK (origen IN ('createSession', 'refreshSession')),
    actualizado    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 5. Índices ------------------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS posts_bluesky_pais_idx             ON posts_bluesky (pais);
CREATE INDEX IF NOT EXISTS posts_bluesky_keyword_idx          ON posts_bluesky (keyword_busqueda);
CREATE INDEX IF NOT EXISTS posts_bluesky_fecha_creacion_idx   ON posts_bluesky (fecha_creacion);
CREATE INDEX IF NOT EXISTS capturas_post_uri_idx              ON capturas (post_uri);
CREATE INDEX IF NOT EXISTS capturas_pais_keyword_idx          ON capturas (pais, keyword_busqueda);
CREATE INDEX IF NOT EXISTS ejecuciones_combinacion_idx        ON ejecuciones_recoleccion (keyword_busqueda, pais, inicio);
```

#### Ejecución con click manual

Tipo: `manualTrigger` (v1)

#### Keyword

Tipo: `set` (v3.4)

```json
{
  "assignments": {
    "assignments": [
      {
        "id": "2ce548c3-1236-40be-ab34-08d8172fcde1",
        "name": "keyword",
        "value": "ransomware",
        "type": "string"
      },
      {
        "id": "7f7f5bc2-e39d-46e3-b112-a76877093d81",
        "name": "pais",
        "value": "brasil",
        "type": "string"
      }
    ]
  },
  "options": {}
}
```

#### Normalizar búsqueda

Tipo: `code` (v2)

```javascript
// Normaliza keyword y país ANTES de buscar y de guardar. Sin esto, "México", "mexico" y "Mexico"
// quedaban como tres países distintos en la base. El país tiene que estar en la lista cerrada
// (la misma que la tabla `paises`, ver database/schema.sql); si no está, la corrida se rechaza.
const PAISES = [
  'argentina', 'bahamas', 'belice', 'bolivia', 'brasil', 'chile',
  'colombia', 'costa rica', 'cuba', 'dominica', 'ecuador', 'el salvador',
  'guatemala', 'guyana', 'haiti', 'honduras', 'jamaica', 'mexico',
  'nicaragua', 'panama', 'paraguay', 'peru', 'puerto rico', 'republica dominicana',
  'san vicente y las granadinas', 'santa lucia', 'surinam', 'trinidad y tobago', 'uruguay', 'venezuela'
];
const ALIAS = {
  brazil: 'brasil', belize: 'belice', suriname: 'surinam', 'dominican republic': 'republica dominicana',
  'saint lucia': 'santa lucia', 'trinidad and tobago': 'trinidad y tobago'
};

// Parámetros de searchPosts. Se registran tal cual en ejecuciones_recoleccion.
// OJO: MAX_PAGINAS e INTERVALO_MS tienen que coincidir con "HTTP Request" → Options → Pagination.
const LIMIT_POR_PAGINA = 100;
const MAX_PAGINAS = 10;
const INTERVALO_MS = 500;

function normalizar(s) {
  return String(s ?? '').toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '').replace(/\s+/g, ' ').trim();
}

const entrada = $input.first().json;
const keyword = String(entrada.keyword ?? '').replace(/\s+/g, ' ').trim();
const paisNormalizado = normalizar(entrada.pais);
const pais = ALIAS[paisNormalizado] || paisNormalizado;

let error = null;
if (!keyword || !pais) error = "Faltan los campos 'keyword' y/o 'pais'.";
else if (keyword.length > 100) error = "La keyword no puede superar los 100 caracteres.";
else if (!PAISES.includes(pais)) error = `País no válido: "${entrada.pais}". Valores aceptados: ${PAISES.join(', ')}.`;

if (error) throw new Error(error);

return [{
  json: {
    keyword,
    pais,
    q: `${keyword} ${pais}`,   // valor EXACTO que se manda en q= (el país va normalizado: "mexico", "brasil")
    limit_por_pagina: LIMIT_POR_PAGINA,
    max_paginas: MAX_PAGINAS,
    intervalo_ms: INTERVALO_MS,
    error
  }
}];
```

#### Registrar inicio de ejecución

Tipo: `postgres` (v2.6) · executeOnce=True

```sql
-- Una fila por corrida: deja registrada la consulta exacta y los parámetros enviados a searchPosts.
-- sort y lang no se envían (NULL): la API usa su default (sort=latest, sin filtro de idioma).
INSERT INTO ejecuciones_recoleccion
  (workflow, n8n_execution_id, keyword_busqueda, pais, consulta_q,
   limit_por_pagina, max_paginas, intervalo_ms, sort, lang)
VALUES ('W1-manual', $1, $2, $3, $4, $5, $6, $7, NULL, NULL)
RETURNING id, inicio;
```

Parámetros ($1, $2, …): `={{ $execution.id }}, {{ $json.keyword }}, {{ $json.pais }}, {{ $json.q }}, {{ $json.limit_por_pagina }}, {{ $json.max_paginas }}, {{ $json.intervalo_ms }}`

#### Leer sesión Bluesky

Tipo: `postgres` (v2.6) · executeOnce=True, alwaysOutputData=True

```sql
SELECT access_jwt, refresh_jwt FROM bluesky_sesion WHERE id = 1;
```

#### Evaluar sesión

Tipo: `code` (v2)

```javascript
// Reutiliza la sesión de Bluesky entre corridas en vez de hacer createSession cada vez
// (createSession tiene límite propio: 30 cada 5 min y 300 por día por cuenta).
//   usar      -> el accessJwt guardado sigue vigente
//   refrescar -> se renueva con refreshSession (no consume cupo de createSession)
//   login     -> no hay sesión usable: createSession
// Los vencimientos se leen del claim `exp` de cada JWT, no se asumen. Si no se puede
// decodificar, se cae a login (el comportamiento anterior), nunca a un token vencido.
const MARGEN_MS = 10 * 60 * 1000; // no usar un token al que le quedan menos de 10 minutos

function venceEn(jwt) {
  try {
    const payload = JSON.parse(Buffer.from(String(jwt).split('.')[1], 'base64url').toString('utf8'));
    return typeof payload.exp === 'number' ? payload.exp * 1000 : 0;
  } catch (e) {
    return 0;
  }
}

const sesion = $input.first().json;
const ahora = Date.now();
let accion = 'login';
if (sesion.access_jwt && venceEn(sesion.access_jwt) - ahora > MARGEN_MS) accion = 'usar';
else if (sesion.refresh_jwt && venceEn(sesion.refresh_jwt) - ahora > MARGEN_MS) accion = 'refrescar';

return [{
  json: {
    accion,
    accessJwt: accion === 'usar' ? sesion.access_jwt : null,
    refreshJwt: sesion.refresh_jwt || null
  }
}];
```

#### ¿Sesión vigente?

Tipo: `if` (v2)

```json
{
  "conditions": {
    "options": {
      "caseSensitive": true,
      "leftValue": "",
      "typeValidation": "strict"
    },
    "conditions": [
      {
        "id": "4bbcdb7a-111e-45d9-95ce-abaa5b70de13",
        "leftValue": "={{ $json.accion }}",
        "rightValue": "usar",
        "operator": {
          "type": "string",
          "operation": "equals"
        }
      }
    ],
    "combinator": "and"
  },
  "options": {}
}
```

#### HTTP Request

Tipo: `httpRequest` (v4.4) · retryOnFail=True, maxTries=4, waitBetweenTries=5000

```json
{
  "url": "https://bsky.social/xrpc/app.bsky.feed.searchPosts",
  "sendQuery": true,
  "queryParameters": {
    "parameters": [
      {
        "name": "q",
        "value": "={{ $('Normalizar búsqueda').first().json.q }}"
      },
      {
        "name": "limit",
        "value": "={{ $('Normalizar búsqueda').first().json.limit_por_pagina }}"
      }
    ]
  },
  "sendHeaders": true,
  "headerParameters": {
    "parameters": [
      {
        "name": "Authorization",
        "value": "=Bearer {{ $json.accessJwt }}"
      }
    ]
  },
  "options": {
    "pagination": {
      "pagination": {
        "paginationMode": "updateAParameterInEachRequest",
        "parameters": {
          "parameters": [
            {
              "type": "qs",
              "name": "cursor",
              "value": "={{ $response.body.cursor }}"
            }
          ]
        },
        "paginationCompleteWhen": "other",
        "completeExpression": "={{ !$response.body.cursor }}",
        "limitPagesFetched": true,
        "maxRequests": 10,
        "requestInterval": 500
      }
    }
  }
}
```

#### ¿Se puede refrescar?

Tipo: `if` (v2)

```json
{
  "conditions": {
    "options": {
      "caseSensitive": true,
      "leftValue": "",
      "typeValidation": "strict"
    },
    "conditions": [
      {
        "id": "5f1a90eb-6a05-4489-a709-ef47687e77a4",
        "leftValue": "={{ $json.accion }}",
        "rightValue": "refrescar",
        "operator": {
          "type": "string",
          "operation": "equals"
        }
      }
    ],
    "combinator": "and"
  },
  "options": {}
}
```

#### Etiquetar página

Tipo: `code` (v2)

```javascript
// Numera cada página de resultados (1 = la primera que devuelve la API) y se lo agrega a
// cada post, para poder analizar después el sesgo de recencia entre páginas tempranas y tardías.
return $input.all().map((item, i) => ({
  json: {
    ...item.json,
    posts: (item.json.posts || []).map(p => ({ ...p, pagina_recoleccion: i + 1 }))
  }
}));
```

#### Refrescar sesión

Tipo: `httpRequest` (v4.4) · onError=continueErrorOutput

```json
{
  "method": "POST",
  "url": "https://bsky.social/xrpc/com.atproto.server.refreshSession",
  "sendHeaders": true,
  "headerParameters": {
    "parameters": [
      {
        "name": "Authorization",
        "value": "=Bearer {{ $json.refreshJwt }}"
      }
    ]
  },
  "options": {}
}
```

#### Nodo: LoginBluesky

Tipo: `httpRequest` (v4.4) · retryOnFail=True, maxTries=3, waitBetweenTries=5000

```json
{
  "method": "POST",
  "url": "https://bsky.social/xrpc/com.atproto.server.createSession",
  "authentication": "genericCredentialType",
  "genericAuthType": "httpCustomAuth",
  "sendBody": true,
  "specifyBody": "json",
  "jsonBody": "{\n  \"identifier\": \"identifier\",\n  \"password\": \"password\"\n}",
  "options": {}
}
```

#### Resumen de corrida

Tipo: `code` (v2)

```javascript
// Metadatos de la corrida para ejecuciones_recoleccion. Cada item de "Etiquetar página" es una
// página de respuesta de searchPosts. Si la última página todavía trae cursor, la corrida se
// cortó por el tope de páginas (cursor_agotado = false) y la muestra de esa búsqueda está truncada.
const paginas = $('Etiquetar página').all();
const ultima = paginas.length ? paginas[paginas.length - 1].json : {};
return [{
  json: {
    ejecucion_id: $('Registrar inicio de ejecución').first().json.id,
    paginas_obtenidas: paginas.length,
    posts_devueltos: paginas.reduce((n, p) => n + (p.json.posts || []).length, 0),
    cursor_agotado: !ultima.cursor
  }
}];
```

#### Guardar sesión

Tipo: `postgres` (v2.6) · executeOnce=True

```sql
INSERT INTO bluesky_sesion (id, did, handle, access_jwt, refresh_jwt, origen, actualizado)
VALUES (1, $1, $2, $3, $4, $5, now())
ON CONFLICT (id) DO UPDATE SET
  did = EXCLUDED.did, handle = EXCLUDED.handle,
  access_jwt = EXCLUDED.access_jwt, refresh_jwt = EXCLUDED.refresh_jwt,
  origen = EXCLUDED.origen, actualizado = now()
RETURNING access_jwt AS "accessJwt";
```

Parámetros ($1, $2, …): `={{ $json.did }}, {{ $json.handle }}, {{ $json.accessJwt }}, {{ $json.refreshJwt }}, {{ $prevNode.name === 'Refrescar sesión' ? 'refreshSession' : 'createSession' }}`

#### Cerrar ejecución

Tipo: `postgres` (v2.6) · executeOnce=True

```sql
UPDATE ejecuciones_recoleccion
SET fin = now(), paginas_obtenidas = $2, posts_devueltos = $3, cursor_agotado = $4, estado = 'ok'
WHERE id = $1
RETURNING id;
```

Parámetros ($1, $2, …): `={{ $json.ejecucion_id }}, {{ $json.paginas_obtenidas }}, {{ $json.posts_devueltos }}, {{ $json.cursor_agotado }}`

#### Recuperar páginas

Tipo: `code` (v2)

```javascript
// Vuelve a emitir las páginas de "Etiquetar página" (el registro de la corrida se hizo en el medio).
return $('Etiquetar página').all().map(item => ({ json: item.json }));
```

#### Separar posts individuales

Tipo: `splitOut` (v1)

```json
{
  "fieldToSplitOut": "posts",
  "options": {}
}
```

#### Limpieza y recopilación de datos

Tipo: `code` (v2)

```javascript
const post = $input.item.json;

// Colisiones geográficas conocidas. Para cada país buscado, frases que indican que el
// post habla de otro lugar con el mismo nombre. Solo se MARCA, nunca se descarta.
// Para sumar otro caso, agregar una entrada (ej.: colombia: [/\bcolumbia\b/i]).
const COLISIONES_GEOGRAFICAS = {
  mexico: [/\bnew\s+mexico\b/i]
};

function normalizarPais(pais) {
  return String(pais || '').toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '').trim();
}

function esPosibleFalsoPositivoGeografico(pais, texto) {
  const patrones = COLISIONES_GEOGRAFICAS[normalizarPais(pais)] || [];
  return patrones.some(re => re.test(texto || ''));
}

// Detección de bridging (cuenta puenteada desde otra plataforma, no nativa de Bluesky)
const handle = post.author?.handle || '';
const esBridged = handle.includes('.brid.gy') || handle.includes('.web.brid.gy');

// Extracción de dominio de fuente externa (si el post comparte un link)
let fuenteDominio = null;
const externalUri = post.record?.embed?.external?.uri || post.embed?.external?.uri;
if (externalUri) {
  const m = String(externalUri).match(/^https?:\/\/([^\/?#:]+)/i);
  fuenteDominio = m ? m[1].toLowerCase().replace(/^www\./, '') : null;
}

// Métricas de engagement
const likes = post.likeCount || 0;
const reposts = post.repostCount || 0;
const replies = post.replyCount || 0;
const quotes = post.quoteCount || 0;

const engagementScore = likes + (reposts * 2) + (replies * 1.5) + (quotes * 2);

const busqueda = $('Normalizar búsqueda').first().json; // keyword y país ya normalizados
const texto = post.record?.text || '';

return {
  json: {
    id: post.uri,
    cid: post.cid,
    texto: texto,
    autor_handle: handle,
    autor_display_name: post.author?.displayName || '',
    fecha_creacion: post.record?.createdAt || null,
    fecha_indexado: post.indexedAt || null,
    likes: likes,
    reposts: reposts,
    replies: replies,
    quotes: quotes,
    engagement_score: Math.round(engagementScore * 100) / 100,
    fuente_dominio: fuenteDominio,
    es_bridged: esBridged,
    keyword_busqueda: busqueda.keyword,
    pais: busqueda.pais,
    posible_falso_positivo_geografico: esPosibleFalsoPositivoGeografico(busqueda.pais, texto),
    pagina_recoleccion: post.pagina_recoleccion ?? null
  }
};
```

#### Insertar/actualizar posts

Tipo: `postgres` (v2.6)

Operación `upsert` sobre `posts_bluesky`, coincidencia por `post_uri`.

```json
{
  "es_bridged": "={{ $json.es_bridged }}",
  "likes": "={{ $json.likes }}",
  "reposts": "={{ $json.reposts }}",
  "replies": "={{ $json.replies }}",
  "quotes": "={{ $json.quotes }}",
  "engagement_score": "={{ $json.engagement_score }}",
  "post_uri": "={{ $json.id }}",
  "post_cid": "={{ $json.cid }}",
  "texto": "={{ $json.texto }}",
  "autor_handle": "={{ $json.autor_handle }}",
  "autor_display_name": "={{ $json.autor_display_name }}",
  "fecha_indexado": "={{ $json.fecha_indexado }}",
  "fecha_creacion": "={{ $json.fecha_creacion }}",
  "fuente_dominio": "={{ $json.fuente_dominio }}",
  "keyword_busqueda": "={{ $json.keyword_busqueda }}",
  "pais": "={{ $json.pais }}",
  "posible_falso_positivo_geografico": "={{ $json.posible_falso_positivo_geografico }}",
  "pagina_recoleccion": "={{ $json.pagina_recoleccion }}"
}
```

#### Preparar capturas

Tipo: `code` (v2)

```javascript
// Una captura por post devuelto en ESTA corrida (modelo N:M). A diferencia de posts_bluesky,
// acá no se pisa nada: si "ransomware mexico" y "malware chile" traen el mismo post, quedan las
// dos pertenencias.
const ejecucionId = $('Registrar inicio de ejecución').first().json.id;
return $('Limpieza y recopilación de datos').all().map(item => ({
  json: {
    ejecucion_id: ejecucionId,
    post_uri: item.json.id,
    keyword_busqueda: item.json.keyword_busqueda,
    pais: item.json.pais,
    pagina: item.json.pagina_recoleccion
  }
}));
```

#### Insertar capturas

Tipo: `postgres` (v2.6)

```sql
-- ON CONFLICT: el cursor de la API puede repetir un post entre páginas; se guarda una vez por corrida.
INSERT INTO capturas (ejecucion_id, post_uri, keyword_busqueda, pais, pagina)
VALUES ($1, $2, $3, $4, $5)
ON CONFLICT DO NOTHING;
```

Parámetros ($1, $2, …): `={{ $json.ejecucion_id }}, {{ $json.post_uri }}, {{ $json.keyword_busqueda }}, {{ $json.pais }}, {{ $json.pagina }}`

#### Traer historial completo

Tipo: `postgres` (v2.6) · executeOnce=True

```sql
-- engagement_score es NUMERIC: el driver de Node lo devuelve como string. Se castea a float8
-- para que las comparaciones sean numéricas. paises / keywords vienen de `capturas` (N:M).
SELECT
  p.post_uri, p.texto, p.autor_handle, p.fuente_dominio, p.fecha_creacion,
  p.likes, p.reposts, p.replies,
  p.engagement_score::float8 AS engagement_score,
  p.pais, p.keyword_busqueda,
  COALESCE(m.paises, ARRAY_REMOVE(ARRAY[p.pais], NULL)) AS paises
FROM posts_bluesky p
LEFT JOIN (
  SELECT post_uri, array_agg(DISTINCT pais ORDER BY pais) AS paises
  FROM capturas GROUP BY post_uri
) m ON m.post_uri = p.post_uri
ORDER BY p.fecha_creacion DESC, p.post_uri;
```

#### Conteo de items

Tipo: `code` (v2)

```javascript
return [
  {
    json: {
      total_posts: items.length
    }
  }
];
```

#### Fuentes

Tipo: `code` (v2)

```javascript
const fuenteCount = {};
for (const item of items) {
  const fuente = item.json.fuente_dominio || 'sin_fuente_externa';
  if (!fuenteCount[fuente]) {
    fuenteCount[fuente] = 1;
  } else {
    fuenteCount[fuente]++;
  }
}
return Object.keys(fuenteCount).map(fuente => {
  return {
    json: {
      fuente_dominio: fuente,
      total_posts: fuenteCount[fuente]
    }
  };
});
```

#### Frecuencia temporal

Tipo: `code` (v2)

```javascript
const postsPerDay = {};
for (const item of items) {
  const dateObj = new Date(item.json.fecha_creacion);
  const day = String(dateObj.getUTCDate()).padStart(2, '0');
  const month = String(dateObj.getUTCMonth() + 1).padStart(2, '0');
  const year = dateObj.getUTCFullYear();
  const formattedDate = `${day}/${month}/${year}`;
  if (!postsPerDay[formattedDate]) {
    postsPerDay[formattedDate] = 1;
  } else {
    postsPerDay[formattedDate]++;
  }
}
return Object.keys(postsPerDay).map(date => {
  return {
    json: {
      date: date,
      total_posts: postsPerDay[date]
    }
  };
});
```

#### mayor engagement

Tipo: `code` (v2)

```javascript
// Number(): Postgres NUMERIC llega del driver como string, y "9.5" > "230.0" es true en orden
// lexicográfico. Sin esta conversión el nodo reportaba 9,5 como el mayor engagement en vez de 230.
let maxScore = -Infinity;
let topPost = null;
for (const item of items) {
  const score = Number(item.json.engagement_score);
  if (Number.isFinite(score) && score > maxScore) {
    maxScore = score;
    topPost = item.json;
  }
}
if (!topPost) return [];
return [
  {
    json: {
      texto: topPost.texto,
      autor: topPost.autor_handle,
      fuente_dominio: topPost.fuente_dominio,
      engagement_score: maxScore,
      likes: topPost.likes,
      reposts: topPost.reposts,
      replies: topPost.replies,
      post_uri: topPost.post_uri
    }
  }
];
```

#### Posts por pais

Tipo: `code` (v2)

```javascript
// Cuenta por PERTENENCIA (tabla capturas): un post que trajeron búsquedas de dos países suma en
// los dos, así que la suma por país puede superar el total de posts.
const paisCount = {};
for (const item of items) {
  const paises = (item.json.paises || []).filter(Boolean);
  for (const pais of (paises.length ? paises : ['sin_especificar'])) {
    paisCount[pais] = (paisCount[pais] || 0) + 1;
  }
}
return Object.keys(paisCount).map(pais => {
  return {
    json: {
      pais: pais,
      total_posts: paisCount[pais]
    }
  };
});
```

#### Fuente dominante

Tipo: `code` (v2)

```javascript
let maxFuente = null;
let maxPosts = 0;
for (const item of items) {
  if (item.json.total_posts > maxPosts) {
    maxPosts = item.json.total_posts;
    maxFuente = item.json.fuente_dominio;
  }
}
return [
  {
    json: {
      fuente_dominante: maxFuente,
      total_posts: maxPosts
    }
  }
];
```

#### Promedio diario

Tipo: `code` (v2)

```javascript
let totalPosts = 0;
let totalDays = items.length;

let maxDay = null;
let maxPosts = 0;

for (const item of items) {
  const posts = item.json.total_posts;

  totalPosts += posts;

  if (posts > maxPosts) {
    maxPosts = posts;
    maxDay = item.json.date;
  }
}

const averagePerDay = totalPosts / totalDays;

return [
  {
    json: {
      total_dias_analizados: totalDays,
      total_publicaciones: totalPosts,
      promedio_publicaciones_por_dia: averagePerDay.toFixed(2),
      dia_mayor_actividad: maxDay,
      publicaciones_en_dia_mayor_actividad: maxPosts
    }
  }
];
```

## Workflow 2: API para el dashboard - Bluesky OSINT V2

### Conexiones

- Execute a SQL query → Code in JavaScript
- Code in JavaScript → Respond to Webhook
- Webhook → Execute a SQL query

### Nodos (en orden de recorrido del grafo, desde el disparador)

#### Webhook

Tipo: `webhook` (v2.1)

```json
{
  "path": "dashboard-data",
  "responseMode": "responseNode",
  "options": {
    "allowedOrigins": "http://localhost:8080,http://127.0.0.1:8080"
  },
  "authentication": "headerAuth"
}
```

#### Execute a SQL query

Tipo: `postgres` (v2.6)

```sql
-- engagement_score es NUMERIC y el driver de Node (pg) lo entrega como STRING: se castea a float8
-- para que el JSON lleve números y cualquier comparación u orden sea numérico, no lexicográfico.
-- paises / keywords: TODAS las combinaciones de búsqueda que trajeron el post (tabla capturas, N:M).
-- El desempate por post_uri hace que el orden (y el hash del export) sea reproducible.
SELECT
  p.post_uri, p.texto, p.autor_handle, p.autor_display_name,
  p.fecha_creacion, p.likes, p.reposts, p.replies, p.quotes,
  p.engagement_score::float8 AS engagement_score,
  p.fuente_dominio, p.es_bridged, p.keyword_busqueda,
  p.pais, p.fecha_insercion,
  p.posible_falso_positivo_geografico, p.pagina_recoleccion,
  COALESCE(m.paises, ARRAY_REMOVE(ARRAY[p.pais], NULL)) AS paises,
  COALESCE(m.keywords, ARRAY_REMOVE(ARRAY[p.keyword_busqueda], NULL)) AS keywords
FROM posts_bluesky p
LEFT JOIN (
  SELECT post_uri,
         array_agg(DISTINCT pais ORDER BY pais) AS paises,
         array_agg(DISTINCT keyword_busqueda ORDER BY keyword_busqueda) AS keywords
  FROM capturas
  GROUP BY post_uri
) m ON m.post_uri = p.post_uri
ORDER BY p.fecha_creacion DESC, p.post_uri;
```

#### Code in JavaScript

Tipo: `code` (v2)

```javascript
//Calculamos las métricas agregadas (mismo criterio que usamos en los 6 nodos de análisis) 
//y empaquetamos junto con el listado de posts, todo en una sola respuesta


// engagement_score: se fuerza Number() aunque la consulta ya castee. Postgres NUMERIC llega del
// driver como string y "9.5" > "230.0" es true en orden lexicográfico: así el campo
// mayor_engagement reportó 9,5 en vez de 230.
const posts = items.map(i => ({ ...i.json, engagement_score: Number(i.json.engagement_score) || 0 }));

// Total de posts
const total_posts = posts.length;

// Fuentes
const fuenteCount = {};
for (const p of posts) {
  const f = p.fuente_dominio || 'sin_fuente_externa';
  fuenteCount[f] = (fuenteCount[f] || 0) + 1;
}
const fuentes = Object.entries(fuenteCount).map(([fuente, total]) => ({ fuente, total }));
const fuente_dominante = fuentes.reduce((max, f) => f.total > (max?.total || 0) ? f : max, null);

// Frecuencia temporal
const postsPerDay = {};
for (const p of posts) {
  const d = new Date(p.fecha_creacion);
  const key = `${String(d.getUTCDate()).padStart(2,'0')}/${String(d.getUTCMonth()+1).padStart(2,'0')}/${d.getUTCFullYear()}`;
  postsPerDay[key] = (postsPerDay[key] || 0) + 1;
}
const frecuencia_temporal = Object.entries(postsPerDay)
  .map(([date, total]) => ({ date, total }))
  .sort((a, b) => {
    const [da, ma, ya] = a.date.split('/');
    const [db, mb, yb] = b.date.split('/');
    return new Date(ya, ma-1, da) - new Date(yb, mb-1, db);
  });

const total_dias = frecuencia_temporal.length;
const promedio_diario = total_dias > 0 ? (total_posts / total_dias).toFixed(2) : 0;

// Mayor engagement
const mayor_engagement = posts.reduce((max, p) =>
  (max === null || p.engagement_score > max.engagement_score) ? p : max, null);

// Bridged vs nativo
const bridged_count = posts.filter(p => p.es_bridged).length;


// Posts por país y por keyword, por PERTENENCIA (tabla capturas): un post que devolvieron
// "ransomware mexico" y "malware chile" suma en México y en Chile. La suma por país puede
// superar total_posts; posts_multi_pais / posts_multi_keyword dicen cuántos están en ese caso.
function contarPorPertenencia(campo, nombre) {
  const cuenta = {};
  for (const p of posts) {
    const valores = (p[campo] || []).filter(Boolean);
    for (const v of (valores.length ? valores : ['sin_especificar'])) cuenta[v] = (cuenta[v] || 0) + 1;
  }
  return Object.entries(cuenta).map(([valor, total]) => ({ [nombre]: valor, total }));
}
const posts_por_pais = contarPorPertenencia('paises', 'pais');
const posts_por_keyword = contarPorPertenencia('keywords', 'keyword');
const posts_multi_pais = posts.filter(p => (p.paises || []).length > 1).length;
const posts_multi_keyword = posts.filter(p => (p.keywords || []).length > 1).length;

return [{
  json: {
    resumen: {
      total_posts,
      total_dias_analizados: total_dias,
      promedio_publicaciones_por_dia: promedio_diario,
      posts_bridged: bridged_count,
      posts_nativos: total_posts - bridged_count,
      posts_multi_pais,
      posts_multi_keyword
    },
    fuente_dominante,
    fuentes,
    frecuencia_temporal,
    mayor_engagement,
    posts_por_pais,
    posts_por_keyword,
    posts
  }
}];
```

#### Respond to Webhook

Tipo: `respondToWebhook` (v1.5)

```json
{
  "respondWith": "json",
  "responseBody": "={{ $json }}",
  "options": {
    "responseHeaders": {
      "entries": [
        {
          "name": "Access-Control-Allow-Origin",
          "value": "={{ [\"http://localhost:8080\", \"http://127.0.0.1:8080\"].includes($('Webhook').first().json.headers.origin) ? $('Webhook').first().json.headers.origin : 'http://localhost:8080' }}"
        },
        {
          "name": "Vary",
          "value": "Origin"
        }
      ]
    }
  }
}
```

## Workflow 3: Nueva búsqueda desde el dashboard - Bluesky OSINT

### Conexiones

- Webhook - Nueva búsqueda → Keyword
- Keyword → Normalizar búsqueda
- Validar keyword y pais (salida 0) → Registrar inicio de ejecución
- Validar keyword y pais (salida 1) → Respond error
- Nodo: LoginBluesky → Guardar sesión
- HTTP Request → Etiquetar página
- Separar posts individuales → Limpieza y recopilación de datos
- Limpieza y recopilación de datos → Insertar/actualizar posts
- Insertar/actualizar posts → Preparar capturas
- Contar resultados → Respond ok
- Etiquetar página → Resumen de corrida
- Registrar inicio de ejecución → Leer sesión Bluesky
- Leer sesión Bluesky → Evaluar sesión
- Evaluar sesión → ¿Sesión vigente?
- ¿Sesión vigente? (salida 0) → HTTP Request
- ¿Sesión vigente? (salida 1) → ¿Se puede refrescar?
- ¿Se puede refrescar? (salida 0) → Refrescar sesión
- ¿Se puede refrescar? (salida 1) → Nodo: LoginBluesky
- Refrescar sesión (salida 0) → Guardar sesión
- Refrescar sesión (salida 1) → Nodo: LoginBluesky
- Guardar sesión → HTTP Request
- Resumen de corrida → Cerrar ejecución
- Cerrar ejecución → Recuperar páginas
- Recuperar páginas → Separar posts individuales
- Preparar capturas → Insertar capturas
- Normalizar búsqueda → Validar keyword y pais
- Insertar capturas → Contar resultados

### Nodos (en orden de recorrido del grafo, desde el disparador)

#### Webhook - Nueva búsqueda

Tipo: `webhook` (v2.1)

```json
{
  "httpMethod": "POST",
  "path": "nueva-busqueda",
  "responseMode": "responseNode",
  "options": {
    "allowedOrigins": "http://localhost:8080,http://127.0.0.1:8080"
  },
  "authentication": "headerAuth"
}
```

#### Keyword

Tipo: `set` (v3.4)

```json
{
  "assignments": {
    "assignments": [
      {
        "id": "a1b2c3d4-0002-4a11-9001-000000000002",
        "name": "keyword",
        "value": "={{ $json.body.keyword }}",
        "type": "string"
      },
      {
        "id": "a1b2c3d4-0003-4a11-9001-000000000003",
        "name": "pais",
        "value": "={{ $json.body.pais }}",
        "type": "string"
      }
    ]
  },
  "options": {}
}
```

#### Normalizar búsqueda

Tipo: `code` (v2)

```javascript
// Normaliza keyword y país ANTES de buscar y de guardar. Sin esto, "México", "mexico" y "Mexico"
// quedaban como tres países distintos en la base. El país tiene que estar en la lista cerrada
// (la misma que la tabla `paises`, ver database/schema.sql); si no está, la corrida se rechaza.
const PAISES = [
  'argentina', 'bahamas', 'belice', 'bolivia', 'brasil', 'chile',
  'colombia', 'costa rica', 'cuba', 'dominica', 'ecuador', 'el salvador',
  'guatemala', 'guyana', 'haiti', 'honduras', 'jamaica', 'mexico',
  'nicaragua', 'panama', 'paraguay', 'peru', 'puerto rico', 'republica dominicana',
  'san vicente y las granadinas', 'santa lucia', 'surinam', 'trinidad y tobago', 'uruguay', 'venezuela'
];
const ALIAS = {
  brazil: 'brasil', belize: 'belice', suriname: 'surinam', 'dominican republic': 'republica dominicana',
  'saint lucia': 'santa lucia', 'trinidad and tobago': 'trinidad y tobago'
};

// Parámetros de searchPosts. Se registran tal cual en ejecuciones_recoleccion.
// OJO: MAX_PAGINAS e INTERVALO_MS tienen que coincidir con "HTTP Request" → Options → Pagination.
const LIMIT_POR_PAGINA = 100;
const MAX_PAGINAS = 10;
const INTERVALO_MS = 500;

function normalizar(s) {
  return String(s ?? '').toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '').replace(/\s+/g, ' ').trim();
}

const entrada = $input.first().json;
const keyword = String(entrada.keyword ?? '').replace(/\s+/g, ' ').trim();
const paisNormalizado = normalizar(entrada.pais);
const pais = ALIAS[paisNormalizado] || paisNormalizado;

let error = null;
if (!keyword || !pais) error = "Faltan los campos 'keyword' y/o 'pais'.";
else if (keyword.length > 100) error = "La keyword no puede superar los 100 caracteres.";
else if (!PAISES.includes(pais)) error = `País no válido: "${entrada.pais}". Valores aceptados: ${PAISES.join(', ')}.`;

// Si hay error, el nodo "Validar keyword y pais" corta acá y responde 400.
return [{
  json: {
    keyword,
    pais,
    q: `${keyword} ${pais}`,   // valor EXACTO que se manda en q= (el país va normalizado: "mexico", "brasil")
    limit_por_pagina: LIMIT_POR_PAGINA,
    max_paginas: MAX_PAGINAS,
    intervalo_ms: INTERVALO_MS,
    error
  }
}];
```

#### Validar keyword y pais

Tipo: `if` (v2)

```json
{
  "conditions": {
    "options": {
      "caseSensitive": true,
      "leftValue": "",
      "typeValidation": "loose"
    },
    "conditions": [
      {
        "id": "0b59c647-c20e-4d3d-a571-9a6e5cb59d3f",
        "leftValue": "={{ $json.error }}",
        "rightValue": "",
        "operator": {
          "type": "string",
          "operation": "empty",
          "singleValue": true
        }
      }
    ],
    "combinator": "and"
  },
  "options": {}
}
```

#### Registrar inicio de ejecución

Tipo: `postgres` (v2.6) · executeOnce=True

```sql
-- Una fila por corrida: deja registrada la consulta exacta y los parámetros enviados a searchPosts.
-- sort y lang no se envían (NULL): la API usa su default (sort=latest, sin filtro de idioma).
INSERT INTO ejecuciones_recoleccion
  (workflow, n8n_execution_id, keyword_busqueda, pais, consulta_q,
   limit_por_pagina, max_paginas, intervalo_ms, sort, lang)
VALUES ('W3-webhook', $1, $2, $3, $4, $5, $6, $7, NULL, NULL)
RETURNING id, inicio;
```

Parámetros ($1, $2, …): `={{ $execution.id }}, {{ $json.keyword }}, {{ $json.pais }}, {{ $json.q }}, {{ $json.limit_por_pagina }}, {{ $json.max_paginas }}, {{ $json.intervalo_ms }}`

#### Respond error

Tipo: `respondToWebhook` (v1.5)

```json
{
  "respondWith": "json",
  "responseBody": "={{ { \"ok\": false, \"error\": $json.error } }}",
  "options": {
    "responseCode": 400,
    "responseHeaders": {
      "entries": [
        {
          "name": "Access-Control-Allow-Origin",
          "value": "={{ [\"http://localhost:8080\", \"http://127.0.0.1:8080\"].includes($('Webhook - Nueva búsqueda').first().json.headers.origin) ? $('Webhook - Nueva búsqueda').first().json.headers.origin : 'http://localhost:8080' }}"
        },
        {
          "name": "Vary",
          "value": "Origin"
        }
      ]
    }
  }
}
```

#### Leer sesión Bluesky

Tipo: `postgres` (v2.6) · executeOnce=True, alwaysOutputData=True

```sql
SELECT access_jwt, refresh_jwt FROM bluesky_sesion WHERE id = 1;
```

#### Evaluar sesión

Tipo: `code` (v2)

```javascript
// Reutiliza la sesión de Bluesky entre corridas en vez de hacer createSession cada vez
// (createSession tiene límite propio: 30 cada 5 min y 300 por día por cuenta).
//   usar      -> el accessJwt guardado sigue vigente
//   refrescar -> se renueva con refreshSession (no consume cupo de createSession)
//   login     -> no hay sesión usable: createSession
// Los vencimientos se leen del claim `exp` de cada JWT, no se asumen. Si no se puede
// decodificar, se cae a login (el comportamiento anterior), nunca a un token vencido.
const MARGEN_MS = 10 * 60 * 1000; // no usar un token al que le quedan menos de 10 minutos

function venceEn(jwt) {
  try {
    const payload = JSON.parse(Buffer.from(String(jwt).split('.')[1], 'base64url').toString('utf8'));
    return typeof payload.exp === 'number' ? payload.exp * 1000 : 0;
  } catch (e) {
    return 0;
  }
}

const sesion = $input.first().json;
const ahora = Date.now();
let accion = 'login';
if (sesion.access_jwt && venceEn(sesion.access_jwt) - ahora > MARGEN_MS) accion = 'usar';
else if (sesion.refresh_jwt && venceEn(sesion.refresh_jwt) - ahora > MARGEN_MS) accion = 'refrescar';

return [{
  json: {
    accion,
    accessJwt: accion === 'usar' ? sesion.access_jwt : null,
    refreshJwt: sesion.refresh_jwt || null
  }
}];
```

#### ¿Sesión vigente?

Tipo: `if` (v2)

```json
{
  "conditions": {
    "options": {
      "caseSensitive": true,
      "leftValue": "",
      "typeValidation": "strict"
    },
    "conditions": [
      {
        "id": "c6d2e5c6-86db-4187-a60b-86ceb7b91fbf",
        "leftValue": "={{ $json.accion }}",
        "rightValue": "usar",
        "operator": {
          "type": "string",
          "operation": "equals"
        }
      }
    ],
    "combinator": "and"
  },
  "options": {}
}
```

#### HTTP Request

Tipo: `httpRequest` (v4.4) · retryOnFail=True, maxTries=4, waitBetweenTries=5000

```json
{
  "url": "https://bsky.social/xrpc/app.bsky.feed.searchPosts",
  "sendQuery": true,
  "queryParameters": {
    "parameters": [
      {
        "name": "q",
        "value": "={{ $('Normalizar búsqueda').first().json.q }}"
      },
      {
        "name": "limit",
        "value": "={{ $('Normalizar búsqueda').first().json.limit_por_pagina }}"
      }
    ]
  },
  "sendHeaders": true,
  "headerParameters": {
    "parameters": [
      {
        "name": "Authorization",
        "value": "=Bearer {{ $json.accessJwt }}"
      }
    ]
  },
  "options": {
    "pagination": {
      "pagination": {
        "paginationMode": "updateAParameterInEachRequest",
        "parameters": {
          "parameters": [
            {
              "type": "qs",
              "name": "cursor",
              "value": "={{ $response.body.cursor }}"
            }
          ]
        },
        "paginationCompleteWhen": "other",
        "completeExpression": "={{ !$response.body.cursor }}",
        "limitPagesFetched": true,
        "maxRequests": 10,
        "requestInterval": 500
      }
    }
  }
}
```

#### ¿Se puede refrescar?

Tipo: `if` (v2)

```json
{
  "conditions": {
    "options": {
      "caseSensitive": true,
      "leftValue": "",
      "typeValidation": "strict"
    },
    "conditions": [
      {
        "id": "8cafdc43-4edf-4989-bd5f-e3f937c31891",
        "leftValue": "={{ $json.accion }}",
        "rightValue": "refrescar",
        "operator": {
          "type": "string",
          "operation": "equals"
        }
      }
    ],
    "combinator": "and"
  },
  "options": {}
}
```

#### Etiquetar página

Tipo: `code` (v2)

```javascript
// Numera cada página de resultados (1 = la primera que devuelve la API) y se lo agrega a
// cada post, para poder analizar después el sesgo de recencia entre páginas tempranas y tardías.
return $input.all().map((item, i) => ({
  json: {
    ...item.json,
    posts: (item.json.posts || []).map(p => ({ ...p, pagina_recoleccion: i + 1 }))
  }
}));
```

#### Refrescar sesión

Tipo: `httpRequest` (v4.4) · onError=continueErrorOutput

```json
{
  "method": "POST",
  "url": "https://bsky.social/xrpc/com.atproto.server.refreshSession",
  "sendHeaders": true,
  "headerParameters": {
    "parameters": [
      {
        "name": "Authorization",
        "value": "=Bearer {{ $json.refreshJwt }}"
      }
    ]
  },
  "options": {}
}
```

#### Nodo: LoginBluesky

Tipo: `httpRequest` (v4.4) · retryOnFail=True, maxTries=3, waitBetweenTries=5000

```json
{
  "method": "POST",
  "url": "https://bsky.social/xrpc/com.atproto.server.createSession",
  "authentication": "genericCredentialType",
  "genericAuthType": "httpCustomAuth",
  "sendBody": true,
  "specifyBody": "json",
  "jsonBody": "{\n  \"identifier\": \"identifier\",\n  \"password\": \"password\"\n}",
  "options": {}
}
```

#### Resumen de corrida

Tipo: `code` (v2)

```javascript
// Metadatos de la corrida para ejecuciones_recoleccion. Cada item de "Etiquetar página" es una
// página de respuesta de searchPosts. Si la última página todavía trae cursor, la corrida se
// cortó por el tope de páginas (cursor_agotado = false) y la muestra de esa búsqueda está truncada.
const paginas = $('Etiquetar página').all();
const ultima = paginas.length ? paginas[paginas.length - 1].json : {};
return [{
  json: {
    ejecucion_id: $('Registrar inicio de ejecución').first().json.id,
    paginas_obtenidas: paginas.length,
    posts_devueltos: paginas.reduce((n, p) => n + (p.json.posts || []).length, 0),
    cursor_agotado: !ultima.cursor
  }
}];
```

#### Guardar sesión

Tipo: `postgres` (v2.6) · executeOnce=True

```sql
INSERT INTO bluesky_sesion (id, did, handle, access_jwt, refresh_jwt, origen, actualizado)
VALUES (1, $1, $2, $3, $4, $5, now())
ON CONFLICT (id) DO UPDATE SET
  did = EXCLUDED.did, handle = EXCLUDED.handle,
  access_jwt = EXCLUDED.access_jwt, refresh_jwt = EXCLUDED.refresh_jwt,
  origen = EXCLUDED.origen, actualizado = now()
RETURNING access_jwt AS "accessJwt";
```

Parámetros ($1, $2, …): `={{ $json.did }}, {{ $json.handle }}, {{ $json.accessJwt }}, {{ $json.refreshJwt }}, {{ $prevNode.name === 'Refrescar sesión' ? 'refreshSession' : 'createSession' }}`

#### Cerrar ejecución

Tipo: `postgres` (v2.6) · executeOnce=True

```sql
UPDATE ejecuciones_recoleccion
SET fin = now(), paginas_obtenidas = $2, posts_devueltos = $3, cursor_agotado = $4, estado = 'ok'
WHERE id = $1
RETURNING id;
```

Parámetros ($1, $2, …): `={{ $json.ejecucion_id }}, {{ $json.paginas_obtenidas }}, {{ $json.posts_devueltos }}, {{ $json.cursor_agotado }}`

#### Recuperar páginas

Tipo: `code` (v2)

```javascript
// Vuelve a emitir las páginas de "Etiquetar página" (el registro de la corrida se hizo en el medio).
return $('Etiquetar página').all().map(item => ({ json: item.json }));
```

#### Separar posts individuales

Tipo: `splitOut` (v1)

```json
{
  "fieldToSplitOut": "posts",
  "options": {}
}
```

#### Limpieza y recopilación de datos

Tipo: `code` (v2)

```javascript
const post = $input.item.json;

// Colisiones geográficas conocidas. Para cada país buscado, frases que indican que el
// post habla de otro lugar con el mismo nombre. Solo se MARCA, nunca se descarta.
// Para sumar otro caso, agregar una entrada (ej.: colombia: [/\bcolumbia\b/i]).
const COLISIONES_GEOGRAFICAS = {
  mexico: [/\bnew\s+mexico\b/i]
};

function normalizarPais(pais) {
  return String(pais || '').toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '').trim();
}

function esPosibleFalsoPositivoGeografico(pais, texto) {
  const patrones = COLISIONES_GEOGRAFICAS[normalizarPais(pais)] || [];
  return patrones.some(re => re.test(texto || ''));
}

// Detección de bridging (cuenta puenteada desde otra plataforma, no nativa de Bluesky)
const handle = post.author?.handle || '';
const esBridged = handle.includes('.brid.gy') || handle.includes('.web.brid.gy');

// Extracción de dominio de fuente externa (si el post comparte un link)
let fuenteDominio = null;
const externalUri = post.record?.embed?.external?.uri || post.embed?.external?.uri;
if (externalUri) {
  const m = String(externalUri).match(/^https?:\/\/([^\/?#:]+)/i);
  fuenteDominio = m ? m[1].toLowerCase().replace(/^www\./, '') : null;
}

// Métricas de engagement
const likes = post.likeCount || 0;
const reposts = post.repostCount || 0;
const replies = post.replyCount || 0;
const quotes = post.quoteCount || 0;

const engagementScore = likes + (reposts * 2) + (replies * 1.5) + (quotes * 2);

const busqueda = $('Normalizar búsqueda').first().json; // keyword y país ya normalizados
const texto = post.record?.text || '';

return {
  json: {
    id: post.uri,
    cid: post.cid,
    texto: texto,
    autor_handle: handle,
    autor_display_name: post.author?.displayName || '',
    fecha_creacion: post.record?.createdAt || null,
    fecha_indexado: post.indexedAt || null,
    likes: likes,
    reposts: reposts,
    replies: replies,
    quotes: quotes,
    engagement_score: Math.round(engagementScore * 100) / 100,
    fuente_dominio: fuenteDominio,
    es_bridged: esBridged,
    keyword_busqueda: busqueda.keyword,
    pais: busqueda.pais,
    posible_falso_positivo_geografico: esPosibleFalsoPositivoGeografico(busqueda.pais, texto),
    pagina_recoleccion: post.pagina_recoleccion ?? null
  }
};
```

#### Insertar/actualizar posts

Tipo: `postgres` (v2.6)

Operación `upsert` sobre `posts_bluesky`, coincidencia por `post_uri`.

```json
{
  "es_bridged": "={{ $json.es_bridged }}",
  "likes": "={{ $json.likes }}",
  "reposts": "={{ $json.reposts }}",
  "replies": "={{ $json.replies }}",
  "quotes": "={{ $json.quotes }}",
  "engagement_score": "={{ $json.engagement_score }}",
  "post_uri": "={{ $json.id }}",
  "post_cid": "={{ $json.cid }}",
  "texto": "={{ $json.texto }}",
  "autor_handle": "={{ $json.autor_handle }}",
  "autor_display_name": "={{ $json.autor_display_name }}",
  "fecha_indexado": "={{ $json.fecha_indexado }}",
  "fecha_creacion": "={{ $json.fecha_creacion }}",
  "fuente_dominio": "={{ $json.fuente_dominio }}",
  "keyword_busqueda": "={{ $json.keyword_busqueda }}",
  "pais": "={{ $json.pais }}",
  "posible_falso_positivo_geografico": "={{ $json.posible_falso_positivo_geografico }}",
  "pagina_recoleccion": "={{ $json.pagina_recoleccion }}"
}
```

#### Preparar capturas

Tipo: `code` (v2)

```javascript
// Una captura por post devuelto en ESTA corrida (modelo N:M). A diferencia de posts_bluesky,
// acá no se pisa nada: si "ransomware mexico" y "malware chile" traen el mismo post, quedan las
// dos pertenencias.
const ejecucionId = $('Registrar inicio de ejecución').first().json.id;
return $('Limpieza y recopilación de datos').all().map(item => ({
  json: {
    ejecucion_id: ejecucionId,
    post_uri: item.json.id,
    keyword_busqueda: item.json.keyword_busqueda,
    pais: item.json.pais,
    pagina: item.json.pagina_recoleccion
  }
}));
```

#### Insertar capturas

Tipo: `postgres` (v2.6)

```sql
-- ON CONFLICT: el cursor de la API puede repetir un post entre páginas; se guarda una vez por corrida.
INSERT INTO capturas (ejecucion_id, post_uri, keyword_busqueda, pais, pagina)
VALUES ($1, $2, $3, $4, $5)
ON CONFLICT DO NOTHING;
```

Parámetros ($1, $2, …): `={{ $json.ejecucion_id }}, {{ $json.post_uri }}, {{ $json.keyword_busqueda }}, {{ $json.pais }}, {{ $json.pagina }}`

#### Contar resultados

Tipo: `code` (v2) · executeOnce=True

```javascript
const busqueda = $('Normalizar búsqueda').first().json;
const resumen = $('Resumen de corrida').first().json;
return [{
  json: {
    ok: true,
    keyword: busqueda.keyword,
    pais: busqueda.pais,
    ejecucion_id: resumen.ejecucion_id,
    paginas_obtenidas: resumen.paginas_obtenidas,
    cursor_agotado: resumen.cursor_agotado,
    posts_procesados: $('Limpieza y recopilación de datos').all().length
  }
}];
```

#### Respond ok

Tipo: `respondToWebhook` (v1.5)

```json
{
  "respondWith": "json",
  "responseBody": "={{ $json }}",
  "options": {
    "responseHeaders": {
      "entries": [
        {
          "name": "Access-Control-Allow-Origin",
          "value": "={{ [\"http://localhost:8080\", \"http://127.0.0.1:8080\"].includes($('Webhook - Nueva búsqueda').first().json.headers.origin) ? $('Webhook - Nueva búsqueda').first().json.headers.origin : 'http://localhost:8080' }}"
        },
        {
          "name": "Vary",
          "value": "Origin"
        }
      ]
    }
  }
}
```
