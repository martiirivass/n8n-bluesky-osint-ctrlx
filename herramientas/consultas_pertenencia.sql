-- Mediciones posteriores a la re-ejecución de las búsquedas (tesis, recomendaciones 8.12-a y 8.3).
--
-- ANTES de re-ejecutar: hacer un backup de la base. El upsert de los Workflows 1 y 3 pisa
-- keyword_busqueda, pais y pagina_recoleccion de los posts que ya existían. No cambia el export
-- congelado ni las cifras del Capítulo 5, pero sí la base en uso:
--   docker exec postgres_n8n pg_dump -U <usuario> -d <base> > database/backups/antes_reejecucion.sql
--
-- Uso, con la hora de inicio que imprime herramientas/recolectar_combinaciones.py:
--   docker exec -i postgres_n8n psql -U <usuario> -d <base> \
--     -v desde="2026-10-22 10:00:00-03" < herramientas/consultas_pertenencia.sql
--
-- Corpus analizado: las publicaciones insertadas hasta el 24/09/2026 14:16 UTC (sección 3.3).
-- El upsert no modifica fecha_insercion, así que ese corte sigue identificando las mismas filas.
-- La consulta 0 tiene que devolver 3908; si no, revisar la zona horaria de fecha_insercion.
--
-- Todas las cifras resultantes describen lo que la API devolvió EN LA FECHA de la re-ejecución
-- (el índice de búsqueda de Bluesky cambia con el tiempo): informarlas con esa fecha.

\set ON_ERROR_STOP on
\pset footer off

CREATE TEMP VIEW corpus AS
SELECT post_uri, pais AS pais_asignado, keyword_busqueda AS keyword_asignada
FROM posts_bluesky
WHERE fecha_insercion < TIMESTAMP '2026-09-24 14:17:00';

-- Capturas hechas por la re-ejecución (solo corridas terminadas sin error).
CREATE TEMP VIEW capturas_nuevas AS
SELECT c.post_uri, c.keyword_busqueda, c.pais
FROM capturas c
JOIN ejecuciones_recoleccion e ON e.id = c.ejecucion_id
WHERE c.origen = 'pipeline' AND e.estado = 'ok' AND e.inicio >= :'desde'::timestamptz;

\echo '0. Tamaño del corpus identificado (tiene que ser 3908)'
SELECT count(*) AS publicaciones_corpus FROM corpus;

\echo '1. Corridas de la re-ejecución'
SELECT workflow, estado, count(*) AS corridas, sum(posts_devueltos) AS posts_devueltos,
       min(inicio) AS primera, max(fin) AS ultima
FROM ejecuciones_recoleccion
WHERE inicio >= :'desde'::timestamptz
GROUP BY workflow, estado ORDER BY workflow, estado;

\echo '2. Atribución múltiple dentro del corpus (recomendación 8.12-a)'
WITH por_post AS (
    SELECT k.post_uri,
           count(DISTINCT (n.keyword_busqueda, n.pais)) AS combinaciones,
           count(DISTINCT n.pais)                       AS paises,
           count(DISTINCT n.keyword_busqueda)           AS keywords
    FROM corpus k JOIN capturas_nuevas n USING (post_uri)
    GROUP BY k.post_uri
)
SELECT (SELECT count(*) FROM corpus)                    AS corpus,
       count(*)                                         AS devueltas_de_nuevo,
       count(*) FILTER (WHERE combinaciones > 1)        AS en_mas_de_una_combinacion,
       round(100.0 * count(*) FILTER (WHERE combinaciones > 1) / count(*), 1) AS pct_sobre_devueltas,
       count(*) FILTER (WHERE paises > 1)               AS en_mas_de_un_pais,
       count(*) FILTER (WHERE keywords > 1)             AS en_mas_de_una_keyword
FROM por_post;

\echo '3. Distribución por país: atribución única del Capítulo 5 frente a pertenencia (Tabla 5.2)'
\echo '   La pertenencia suma la atribución original y lo que devolvió la re-ejecución; la suma por país puede superar 3908.'
WITH pertenencia AS (
    SELECT post_uri, pais_asignado AS pais FROM corpus
    UNION
    SELECT n.post_uri, n.pais FROM capturas_nuevas n JOIN corpus k USING (post_uri)
)
SELECT p.pais,
       (SELECT count(*) FROM corpus k WHERE k.pais_asignado = p.pais)       AS atribucion_unica,
       round(100.0 * (SELECT count(*) FROM corpus k WHERE k.pais_asignado = p.pais) / (SELECT count(*) FROM corpus), 1) AS pct_unica,
       count(DISTINCT p.post_uri)                                           AS por_pertenencia,
       round(100.0 * count(DISTINCT p.post_uri) / (SELECT count(*) FROM pertenencia), 1) AS pct_de_pertenencias
FROM pertenencia p
GROUP BY p.pais ORDER BY por_pertenencia DESC;

\echo '4. Publicaciones del corpus que la re-ejecución ya no devolvió (borradas, editadas o fuera del índice)'
SELECT k.pais_asignado AS pais, count(*) AS no_devueltas
FROM corpus k
WHERE NOT EXISTS (SELECT 1 FROM capturas_nuevas n WHERE n.post_uri = k.post_uri)
GROUP BY k.pais_asignado ORDER BY no_devueltas DESC;

\echo '5. Experimento en portugués para Brasil (recomendación 8.3)'
WITH pt AS (
    SELECT n.post_uri, n.keyword_busqueda
    FROM capturas_nuevas n
    WHERE n.pais = 'brasil'
      AND n.keyword_busqueda IN ('cibersegurança', 'ataque cibernético', 'vazamento de dados', 'segurança da informação')
)
SELECT keyword_busqueda,
       count(DISTINCT post_uri)                                                      AS devueltas,
       count(DISTINCT post_uri) FILTER (WHERE post_uri IN (SELECT post_uri FROM corpus)) AS ya_en_corpus,
       count(DISTINCT post_uri) FILTER (WHERE post_uri NOT IN (SELECT post_uri FROM corpus)) AS nuevas
FROM pt GROUP BY ROLLUP (keyword_busqueda) ORDER BY keyword_busqueda NULLS LAST;
\echo '   La fila con keyword vacía es el total sin duplicar. Comparar «nuevas» con las 621 de Brasil del Capítulo 5.'
