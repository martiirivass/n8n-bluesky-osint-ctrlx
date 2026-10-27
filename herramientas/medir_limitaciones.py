"""
Mide sobre el export congelado algunas limitaciones que la tesis declara sin cuantificar.
No consulta la API ni la base: solo lee el JSON del export, así que las cifras se pueden citar como
«calculado sobre export_posts_latam_v2.json (SHA-256 fbfe11d3…)».

Mide:
  (1) Recomendación 8.1: publicaciones de México que NO quedaron marcadas como colisión
      «New Mexico» pero mencionan variantes que el patrón actual no cubre (#NewMexico, NewMexico,
      «Nuevo México», «NM» en mayúsculas). Son CANDIDATAS: hay que revisarlas a mano antes de
      afirmar que son falsos negativos («NM» en particular puede significar otra cosa).
  (2) Recomendación 8.10: handles con formato de dominio propio (no *.bsky.social ni *.brid.gy),
      en total y entre las publicaciones anteriores a 2023. Es una COTA SUPERIOR del contenido
      sindicado: muchas cuentas nativas usan su propio dominio como handle.
  (3) Sección 5.3: publicaciones cuyo texto menciona dos o más de los cinco países. Es una
      medición textual reproducible, no la atribución múltiple real (esa requiere volver a
      ejecutar las búsquedas; ver herramientas/recolectar_combinaciones.py).
  (4) Sección 5.3 y recomendación 8.12 (a): publicaciones cuyo texto contiene los términos de dos
      o más de las 40 combinaciones keyword×país, es decir, candidatas a haber sido devueltas por
      más de una búsqueda. Reemplaza la «estimación textual» de METODOLOGIA.md (sección 5.2) por una
      medición reproducible. Sigue sin ser la atribución múltiple real de la API.

Uso (desde la raíz del repo):
    python herramientas/medir_limitaciones.py database/export_posts_latam_v2.json
    python herramientas/medir_limitaciones.py database/export_posts_latam_v2.json --detalle

Con --detalle imprime además el post_uri de cada candidata, para revisarlas a mano. Los post_uri
incluyen el DID del autor: no pegar esa salida en el repositorio ni en la tesis.
"""

import argparse
import collections
import hashlib
import json
import re
import sys
import unicodedata

HASH_ESPERADO = "fbfe11d3ea7c9415b63983ca1441457baa94b70b01f01f29e1da710a4a5b5c6d"
PAISES = ["mexico", "argentina", "chile", "brasil", "colombia"]

# Patrón vigente en el nodo de limpieza (Anexo B.1): /\bnew\s+mexico\b/i
PATRON_ACTUAL = re.compile(r"\bnew\s+mexico\b", re.I)
VARIANTES_8_1 = {
    "#NewMexico o NewMexico (sin espacio)": re.compile(r"\bnew_?mexico\b", re.I),
    "New-Mexico (con guion)": re.compile(r"\bnew-mexico\b", re.I),
    "Nuevo México (en español)": re.compile(r"\bnuevo\s+m[eé]xico\b", re.I),
    "NM en mayúsculas (revisar a mano)": re.compile(r"\bNM\b"),
}

# Menciones de cada país en el texto, con variantes de idioma frecuentes.
MENCIONES_PAIS = {
    "mexico": re.compile(r"\bm[eé]xico\b|\bmexican[oa]s?\b|\bmexicans?\b", re.I),
    "argentina": re.compile(r"\bargentin[ao]s?\b|\bargentinian?s?\b", re.I),
    "chile": re.compile(r"\bchilen[oa]s?\b|\bchile\b|\bchilean?s?\b", re.I),
    "brasil": re.compile(r"\bbra[sz]il\b|\bbrasileir[oa]s?\b|\bbrasileñ[oa]s?\b|\bbrazilians?\b", re.I),
    "colombia": re.compile(r"\bcolombia\b|\bcolombian[oa]s?\b|\bcolombians?\b", re.I),
}
# Las 8 keywords activas y los 5 países, tal como se envían en q = "{keyword} {país}".
KEYWORDS_ACTIVAS = ["ransomware", "ciberseguridad", "malware", "hacking", "data breach",
                    "ciberataque", "filtración de datos", "seguridad informática"]
RE_NUEVO_MEXICO = re.compile(r"\b(new\s*|nuevo\s+)m[eé]xico\b", re.I)


def sha256(ruta):
    h = hashlib.sha256()
    with open(ruta, "rb") as f:
        for bloque in iter(lambda: f.read(1 << 20), b""):
            h.update(bloque)
    return h.hexdigest()


def cargar_posts(ruta):
    with open(ruta, encoding="utf-8") as f:
        datos = json.load(f)
    if isinstance(datos, list):  # n8n puede envolver la respuesta en un array
        datos = datos[0]
    return datos["posts"]


def sin_tildes(s):
    return unicodedata.normalize("NFD", s or "").encode("ascii", "ignore").decode().lower()


def es_handle_de_dominio(handle):
    h = (handle or "").lower()
    return "." in h and not h.endswith(".bsky.social") and ".brid.gy" not in h


def pct(a, b):
    return f"{100 * a / b:.1f}%".replace(".", ",") if b else "—"


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("export")
    ap.add_argument("--detalle", action="store_true", help="imprime el post_uri de cada candidata")
    args = ap.parse_args()
    sys.stdout.reconfigure(encoding="utf-8")

    hash_real = sha256(args.export)
    print(f"Export: {args.export}\nSHA-256: {hash_real}")
    if hash_real != HASH_ESPERADO:
        print("ATENCIÓN: el hash no coincide con el export citado en la tesis (fbfe11d3…). "
              "Las cifras de abajo NO deben citarse como calculadas sobre ese export.")
    posts = cargar_posts(args.export)
    n = len(posts)
    print(f"Publicaciones: {n}\n")

    # (1) Recomendación 8.1 -------------------------------------------------------------------
    mx = [p for p in posts if p.get("pais") == "mexico"]
    marcadas = [p for p in mx if p.get("posible_falso_positivo_geografico")]
    no_marcadas = [p for p in mx if not p.get("posible_falso_positivo_geografico")]
    print("(1) Colisión «New Mexico» (recomendación 8.1)")
    print(f"    Publicaciones de México: {len(mx)}; marcadas por el patrón actual: {len(marcadas)}")
    inconsistentes = [p for p in no_marcadas if PATRON_ACTUAL.search(p.get("texto") or "")]
    if inconsistentes:
        print(f"    AVISO: {len(inconsistentes)} no marcadas coinciden con el patrón actual "
              "(¿texto editado después de la recolección?)")
    union = {}
    for nombre, patron in VARIANTES_8_1.items():
        hits = [p for p in no_marcadas if patron.search(p.get("texto") or "")]
        print(f"    No marcadas que contienen {nombre}: {len(hits)}")
        for p in hits:
            union.setdefault(p["post_uri"], p)
    sin_nm = [r for nombre, r in VARIANTES_8_1.items() if not nombre.startswith("NM")]
    estrictas = {u for u, p in union.items() if any(r.search(p.get("texto") or "") for r in sin_nm)}
    print(f"    Candidatas en total (unión, sin duplicar): {len(union)} "
          f"({pct(len(union), len(mx))} de México); sin contar las que solo tienen «NM»: {len(estrictas)}")
    if args.detalle:
        for u in sorted(union):
            print(f"      {u}")
    print()

    # (2) Recomendación 8.10 ------------------------------------------------------------------
    dominio = [p for p in posts if es_handle_de_dominio(p.get("autor_handle"))]
    antiguas = [p for p in posts if (p.get("fecha_creacion") or "9999") < "2023-01-01"]
    antiguas_dominio = [p for p in antiguas if es_handle_de_dominio(p.get("autor_handle"))]
    antiguas_bridged = [p for p in antiguas if p.get("es_bridged")]
    print("(2) Handles con formato de dominio propio (recomendación 8.10)")
    print(f"    Publicaciones con handle de dominio propio: {len(dominio)} ({pct(len(dominio), n)}), "
          f"de {len({p['autor_handle'] for p in dominio})} cuentas; marcadas es_bridged: "
          f"{sum(bool(p.get('es_bridged')) for p in dominio)}")
    print(f"    Anteriores a 2023: {len(antiguas)}; con handle de dominio propio: {len(antiguas_dominio)}; "
          f"marcadas es_bridged: {len(antiguas_bridged)}")
    por_pais = collections.Counter(p.get("pais") for p in dominio)
    print("    Por país: " + "; ".join(f"{k} {por_pais.get(k, 0)}" for k in PAISES))
    print("    Cota superior: un handle de dominio no implica sindicación (hay cuentas nativas con dominio).")
    if args.detalle:
        for p in antiguas_dominio:
            print(f"      {p['post_uri']}  {p.get('fecha_creacion')}")
    print()

    # (3) Menciones de dos o más países -------------------------------------------------------
    multi = []
    for p in posts:
        texto = RE_NUEVO_MEXICO.sub(" ", p.get("texto") or "")  # «New Mexico» no cuenta como México
        mencionados = {k for k, r in MENCIONES_PAIS.items() if r.search(texto) or r.search(sin_tildes(texto))}
        if len(mencionados) >= 2:
            multi.append((p, mencionados))
    print("(3) Publicaciones cuyo texto menciona dos o más de los cinco países (sección 5.3)")
    print(f"    {len(multi)} de {n} ({pct(len(multi), n)})")
    combos = collections.Counter(len(m) for _, m in multi)
    print("    Por cantidad de países mencionados: " + "; ".join(f"{k}: {v}" for k, v in sorted(combos.items())))
    print("    Es una medición textual: no equivale a la atribución múltiple de la API.")
    if args.detalle:
        for p, m in multi:
            print(f"      {p['post_uri']}  {sorted(m)}")

    print()

    # (4) Candidatas a más de una combinación keyword×país --------------------------------------
    # Criterio: texto en minúsculas y sin tildes; la combinación (k, p) «coincide» si el texto
    # contiene, como palabras completas, todos los términos de k y el nombre del país p (igual que
    # la consulta q, que no es una frase exacta). «New Mexico» no cuenta como México.
    def terminos(s):
        return [re.compile(r"\b" + re.escape(w) + r"\b") for w in sin_tildes(s).split()]
    kw_re = {k: terminos(k) for k in KEYWORDS_ACTIVAS}
    pais_re = {p: terminos(p) for p in PAISES}
    multi_comb, multi_kw, multi_pa = [], 0, 0
    for p in posts:
        t = sin_tildes(RE_NUEVO_MEXICO.sub(" ", p.get("texto") or ""))
        ks = [k for k, rs in kw_re.items() if all(r.search(t) for r in rs)]
        ps = [q for q, rs in pais_re.items() if all(r.search(t) for r in rs)]
        if len(ks) * len(ps) >= 2:
            multi_comb.append((p, ks, ps))
            multi_kw += len(ks) >= 2
            multi_pa += len(ps) >= 2
    print("(4) Publicaciones cuyo texto coincide con dos o más combinaciones keyword×país")
    print(f"    {len(multi_comb)} de {n} ({pct(len(multi_comb), n)}); "
          f"con 2+ keywords: {multi_kw}; con 2+ países (nombre literal): {multi_pa}")
    # Criterio de la estimación anterior (METODOLOGIA.md, sección 5.2): keyword como frase exacta
    # y sin excluir «New Mexico». Se informa solo para conciliar con la cifra previa (163).
    def frase(s):
        return re.compile(r"\b" + r"\s+".join(map(re.escape, sin_tildes(s).split())) + r"\b")
    kw_f = [frase(k) for k in KEYWORDS_ACTIVAS]
    pa_f = [frase(q) for q in PAISES]
    previo = 0
    for p in posts:
        t = sin_tildes(p.get("texto") or "")
        previo += sum(bool(r.search(t)) for r in kw_f) * sum(bool(r.search(t)) for r in pa_f) >= 2
    print(f"    Con el criterio de la estimación anterior (frase exacta, sin excluir «New Mexico»): {previo}")
    print("    Es una medición textual: el buscador de Bluesky no hace coincidencia literal.")
    if args.detalle:
        for p, ks, ps in multi_comb:
            print(f"      {p['post_uri']}  {ks} × {ps}")


if __name__ == "__main__":
    main()
