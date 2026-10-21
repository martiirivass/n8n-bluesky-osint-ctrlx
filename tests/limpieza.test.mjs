// Pruebas mínimas del nodo Code «Limpieza y recopilación de datos» (tesis, sección 8.6).
//
// El código NO se copia: se lee tal cual del JSON exportado de cada workflow, de modo que
// la prueba falla si alguien cambia el nodo en n8n y lo reexporta con otro comportamiento.
//
// Uso (Node 18 o superior, sin dependencias):
//   node --test tests/limpieza.test.mjs
//
// Las pruebas marcadas «LIMITACIÓN CONOCIDA» documentan comportamientos que la tesis declara
// como pendientes (recomendaciones 8.1 y 8.12-c). Si se corrige el nodo, hay que actualizarlas.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const raiz = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const NOMBRE_NODO = 'Limpieza y recopilación de datos';
const WORKFLOWS = {
  'Workflow 1': 'n8n/Workflow 1_ Recolección de datos - Bluesky OSINT V2.json',
  'Workflow 3': 'n8n/Workflow 3_ Nueva búsqueda desde el dashboard - Bluesky OSINT.json',
};

function codigoDelNodo(archivo) {
  const wf = JSON.parse(readFileSync(path.join(raiz, archivo), 'utf8'));
  const nodo = wf.nodes.find((n) => n.name === NOMBRE_NODO);
  assert.ok(nodo, `no se encontró el nodo «${NOMBRE_NODO}» en ${archivo}`);
  assert.equal(nodo.parameters.mode, 'runOnceForEachItem');
  return nodo.parameters.jsCode;
}

// Ejecuta el nodo como lo haría n8n en modo «una vez por ítem», con stubs de $input y $().
function ejecutar(codigo, post, busqueda = { keyword: 'ransomware', pais: 'mexico' }) {
  const $input = { item: { json: post } };
  const $ = (nombre) => {
    assert.equal(nombre, 'Normalizar búsqueda');
    return { first: () => ({ json: busqueda }) };
  };
  return new Function('$input', '$', codigo)($input, $).json;
}

function post({ handle = 'alguien.bsky.social', texto = 'texto', embedUri, counts = {}, pagina } = {}) {
  const p = {
    uri: 'at://did:plc:prueba/app.bsky.feed.post/1',
    cid: 'cid-prueba',
    author: { handle, displayName: 'Prueba' },
    record: { text: texto, createdAt: '2026-01-01T00:00:00.000Z' },
    indexedAt: '2026-01-01T00:00:01.000Z',
    ...counts,
  };
  if (embedUri) p.record.embed = { external: { uri: embedUri } };
  if (pagina !== undefined) p.pagina_recoleccion = pagina;
  return p;
}

const codigos = Object.fromEntries(Object.entries(WORKFLOWS).map(([k, f]) => [k, codigoDelNodo(f)]));

test('el nodo de limpieza es idéntico en los Workflows 1 y 3', () => {
  assert.equal(codigos['Workflow 1'], codigos['Workflow 3']);
});

for (const [wf, codigo] of Object.entries(codigos)) {
  const run = (p, b) => ejecutar(codigo, p, b);

  test(`${wf}: engagement = likes + 2·reposts + 1,5·replies + 2·quotes`, () => {
    const r = run(post({ counts: { likeCount: 10, repostCount: 2, replyCount: 1, quoteCount: 1 } }));
    assert.equal(r.engagement_score, 17.5);
    // Caso real del Anexo D.1: 126 likes, 46 reposts, 4 replies, 3 quotes -> 230.
    const d1 = run(post({ counts: { likeCount: 126, repostCount: 46, replyCount: 4, quoteCount: 3 } }));
    assert.equal(d1.engagement_score, 230);
  });

  test(`${wf}: métricas ausentes cuentan como 0`, () => {
    const r = run(post());
    assert.deepEqual([r.likes, r.reposts, r.replies, r.quotes, r.engagement_score], [0, 0, 0, 0, 0]);
  });

  test(`${wf}: dominio de la tarjeta de enlace, sin www, en minúsculas y sin puerto`, () => {
    assert.equal(run(post({ embedUri: 'https://www.Example.COM/nota?id=1' })).fuente_dominio, 'example.com');
    assert.equal(run(post({ embedUri: 'http://sitio.com.ar:8080/a' })).fuente_dominio, 'sitio.com.ar');
    assert.equal(run(post()).fuente_dominio, null);
  });

  test(`${wf}: publicación sin texto pero con tarjeta de enlace (sección 5.6)`, () => {
    const r = run(post({ texto: '', embedUri: 'https://medio.com.br/x' }));
    assert.equal(r.texto, '');
    assert.equal(r.fuente_dominio, 'medio.com.br');
  });

  test(`${wf}: LIMITACIÓN CONOCIDA (8.12-c): una URL escrita solo en el texto no se detecta`, () => {
    const r = run(post({ texto: 'Ver https://ejemplo.com/alerta' }));
    assert.equal(r.fuente_dominio, null);
  });

  test(`${wf}: detección de cuentas puenteadas por Bridgy Fed`, () => {
    assert.equal(run(post({ handle: 'alice.mastodon.social.ap.brid.gy' })).es_bridged, true);
    assert.equal(run(post({ handle: 'blog.ejemplo.com.web.brid.gy' })).es_bridged, true);
    assert.equal(run(post({ handle: 'alguien.bsky.social' })).es_bridged, false);
  });

  test(`${wf}: LIMITACIÓN CONOCIDA (8.10): handle de dominio propio no se marca como puenteado`, () => {
    assert.equal(run(post({ handle: 'projetfox.com' })).es_bridged, false);
  });

  test(`${wf}: colisión «New Mexico» solo para México`, () => {
    const texto = 'Juicio contra Facebook en New Mexico';
    assert.equal(run(post({ texto }), { keyword: 'hacking', pais: 'mexico' }).posible_falso_positivo_geografico, true);
    assert.equal(run(post({ texto: 'NEW   MEXICO' }), { keyword: 'hacking', pais: 'México' }).posible_falso_positivo_geografico, true);
    assert.equal(run(post({ texto }), { keyword: 'hacking', pais: 'chile' }).posible_falso_positivo_geografico, false);
    assert.equal(run(post({ texto: 'Ataque en Ciudad de México' })).posible_falso_positivo_geografico, false);
  });

  test(`${wf}: LIMITACIÓN CONOCIDA (8.1): «#NewMexico» y «NM» no se marcan`, () => {
    assert.equal(run(post({ texto: 'Ransomware #NewMexico' })).posible_falso_positivo_geografico, false);
    assert.equal(run(post({ texto: 'Ransomware en Albuquerque, NM' })).posible_falso_positivo_geografico, false);
  });

  test(`${wf}: propaga keyword, país y página; página ausente queda en null`, () => {
    const b = { keyword: 'malware', pais: 'brasil' };
    const r = run(post({ pagina: 3 }), b);
    assert.deepEqual([r.keyword_busqueda, r.pais, r.pagina_recoleccion, r.id], ['malware', 'brasil', 3, 'at://did:plc:prueba/app.bsky.feed.post/1']);
    assert.equal(run(post(), b).pagina_recoleccion, null);
  });
}
