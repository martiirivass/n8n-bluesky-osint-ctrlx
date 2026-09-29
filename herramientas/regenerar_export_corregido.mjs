// Regenera el export del Workflow 2 con el código corregido, SIN volver a consultar Bluesky ni la
// base: toma las filas del export original (mismo corte de 3.908 publicaciones, mismo orden) y les
// aplica el nodo "Code in JavaScript" tal como está en el JSON del Workflow 2 (no una copia).
//
// Por qué así: el export es una función pura de las filas de posts_bluesky. Rehacerlo desde la
// base viva mezclaría la corrección del bug con datos nuevos o métricas actualizadas, y la
// muestra de validación (sección 5.6) depende del ORDEN de los posts.
//
// Qué emula de la consulta SQL corregida:
//   - engagement_score::float8   -> número en vez de string
//   - paises / keywords          -> [pais] / [keyword_busqueda]: es lo que produce el backfill de
//                                   la migración 001 (una sola atribución por post, la única que
//                                   se conservó en la base).
//
// Uso (desde la raíz del repo):
//   node herramientas/regenerar_export_corregido.mjs
// Entrada: database/export_posts_latam.json (SHA-256 73c35ee1…, no versionado: contiene handles)
// Salida:  database/export_posts_latam_v2.json (tampoco versionado)

import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const RAIZ = join(dirname(fileURLToPath(import.meta.url)), '..');
const ENTRADA = join(RAIZ, 'database', 'export_posts_latam.json');
const SALIDA = join(RAIZ, 'database', 'export_posts_latam_v2.json');
const WORKFLOW_2 = join(RAIZ, 'n8n', 'Workflow 2_ API para el dashboard - Bluesky OSINT V2.json');
const SHA_ESPERADO = '73c35ee1454eaa63528350061186fdecf849812fcfb7842c048e9a0e8d373c00';

const sha256 = buf => createHash('sha256').update(buf).digest('hex');

const raw = readFileSync(ENTRADA);
const shaEntrada = sha256(raw);
if (shaEntrada !== SHA_ESPERADO) {
  console.error(`El export de entrada no es el corte evaluado.\n  esperado: ${SHA_ESPERADO}\n  obtenido: ${shaEntrada}`);
  process.exit(1);
}
const original = JSON.parse(raw.toString('utf8'));

const filas = original.posts.map(p => ({
  ...p,
  engagement_score: parseFloat(p.engagement_score),
  paises: p.pais ? [p.pais] : [],
  keywords: p.keyword_busqueda ? [p.keyword_busqueda] : []
}));

const workflow = JSON.parse(readFileSync(WORKFLOW_2, 'utf8'));
const jsCode = workflow.nodes.find(n => n.name === 'Code in JavaScript').parameters.jsCode;
const nodo = new Function('items', jsCode);
const [{ json: corregido }] = nodo(filas.map(json => ({ json })));

const texto = JSON.stringify(corregido, null, 2);
writeFileSync(SALIDA, texto, 'utf8');

const antes = original.mayor_engagement;
const despues = corregido.mayor_engagement;
console.log(`Entrada: ${ENTRADA}\n  SHA-256 ${shaEntrada}`);
console.log(`Salida:  ${SALIDA}\n  SHA-256 ${sha256(Buffer.from(texto, 'utf8'))}`);
console.log(`Posts: ${corregido.posts.length} (mismo orden que el original: ${
  corregido.posts.every((p, i) => p.post_uri === original.posts[i].post_uri)})`);
console.log(`mayor_engagement antes:  ${antes.engagement_score} (${antes.post_uri})`);
console.log(`mayor_engagement despues: ${despues.engagement_score} (${despues.post_uri})`);
