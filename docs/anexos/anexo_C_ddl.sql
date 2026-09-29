-- Anexo C — DDL de la base de datos
-- Generado con `python herramientas/extraer_anexos.py`. No editar a mano.
-- database/schema.sql  SHA-256 223475baaeaff31cf8fe2aa46168d8d3368763303fa80430e2509c0c05afb80b
-- database/migraciones/001_capturas_ejecuciones_sesion_indices.sql  SHA-256 613a68ab6b0d3965941217f82a27cdb3e7c5efa3d185b9e1ee50ac0ace175dcf

-- =====================================================================
-- database/schema.sql
-- =====================================================================

--
-- Schema completo de la base del observatorio (sin datos) — estado final.
--
-- Instalación desde cero:
--   docker exec -i postgres_n8n psql -U <usuario> -d <base> < database/schema.sql
--
-- Si la base ya existía con la versión anterior (solo posts_bluesky), NO correr este archivo:
-- correr database/migraciones/001_capturas_ejecuciones_sesion_indices.sql, que además hace el
-- backfill de `capturas` a partir de los datos ya recolectados.
--

-- Lista cerrada de países (evita "México" / "mexico" / "Mexico" como valores distintos).
CREATE TABLE paises (
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
    ('venezuela', 'Venezuela', 'VE');

-- Una fila por publicación (deduplicada por post_uri).
-- keyword_busqueda / pais / pagina_recoleccion guardan la ÚLTIMA búsqueda que trajo el post
-- (se pisan en cada upsert). Para desgloses por país o keyword usar `capturas` / `pertenencias`.
CREATE TABLE posts_bluesky (
    id                                SERIAL PRIMARY KEY,
    post_uri                          TEXT UNIQUE,
    post_cid                          TEXT,
    texto                             TEXT,
    autor_handle                      TEXT,
    autor_display_name                TEXT,
    fecha_creacion                    TIMESTAMP,
    fecha_indexado                    TIMESTAMP,
    likes                             INTEGER,
    reposts                           INTEGER,
    replies                           INTEGER,
    quotes                            INTEGER,
    engagement_score                  NUMERIC,   -- el driver de Node (pg) lo devuelve como STRING: castear a float8 al leer
    fuente_dominio                    TEXT,
    es_bridged                        BOOLEAN,
    keyword_busqueda                  TEXT,
    fecha_insercion                   TIMESTAMP DEFAULT now(),
    pais                              TEXT REFERENCES paises (slug),
    posible_falso_positivo_geografico BOOLEAN DEFAULT false,
    pagina_recoleccion                INTEGER
);

-- Una fila por corrida de búsqueda (Workflow 1 o Workflow 3).
CREATE TABLE ejecuciones_recoleccion (
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

-- Modelo N:M: cada vez que una combinación keyword×país devuelve un post.
CREATE TABLE capturas (
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

CREATE UNIQUE INDEX capturas_ejecucion_post_uq ON capturas (ejecucion_id, post_uri) WHERE ejecucion_id IS NOT NULL;
CREATE UNIQUE INDEX capturas_backfill_uq       ON capturas (post_uri) WHERE origen = 'atribucion_unica_previa';

CREATE VIEW pertenencias AS
SELECT DISTINCT post_uri, keyword_busqueda, pais
FROM capturas;

-- Sesión de Bluesky reutilizable entre corridas (una sola fila).
CREATE TABLE bluesky_sesion (
    id          SMALLINT PRIMARY KEY DEFAULT 1 CHECK (id = 1),
    did         TEXT,
    handle      TEXT,
    access_jwt  TEXT NOT NULL,
    refresh_jwt TEXT NOT NULL,
    origen      TEXT NOT NULL CHECK (origen IN ('createSession', 'refreshSession')),
    actualizado TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX posts_bluesky_pais_idx           ON posts_bluesky (pais);
CREATE INDEX posts_bluesky_keyword_idx        ON posts_bluesky (keyword_busqueda);
CREATE INDEX posts_bluesky_fecha_creacion_idx ON posts_bluesky (fecha_creacion);
CREATE INDEX capturas_post_uri_idx            ON capturas (post_uri);
CREATE INDEX capturas_pais_keyword_idx        ON capturas (pais, keyword_busqueda);
CREATE INDEX ejecuciones_combinacion_idx      ON ejecuciones_recoleccion (keyword_busqueda, pais, inicio);

-- =====================================================================
-- database/migraciones/001_capturas_ejecuciones_sesion_indices.sql
-- =====================================================================

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

BEGIN;

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

COMMIT;
