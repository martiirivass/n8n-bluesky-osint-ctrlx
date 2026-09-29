"""
Genera la versión PÚBLICA (seudonimizada) de la muestra de validación clasificada.

Por qué no alcanza con reemplazar el handle: el post_uri contiene el DID de la cuenta
(at://did:plc:.../app.bsky.feed.post/...), que se resuelve al perfil, y el texto del post se
encuentra buscándolo literal en Bluesky. Cualquiera de los tres identifica al autor. Por eso la
versión pública:
  - reemplaza post_uri por `id_publicacion` = HMAC-SHA256(clave privada, post_uri), truncado a
    16 hex. Con la clave, el equipo puede volver a vincular cada fila con su post; sin ella, no
    se puede (un hash sin clave sí se podría revertir probando URIs candidatas);
  - elimina `texto` y `autor_handle`, y agrega `tiene_texto` (lo único que las estadísticas
    necesitan del texto: las filas vacías se cuentan como no clasificables).

Entrada:  validacion/privado/validacion_muestra_80_clasificada.csv  (sale de unir_clasificaciones.py)
Clave:    validacion/privado/clave_seudonimos.txt  (se crea si no existe; NO se versiona)
Salida:   validacion/validacion_muestra_80_seudonimizada.csv  (se versiona)

Uso:
    python validacion/seudonimizar_validacion.py
"""

import csv
import hashlib
import hmac
import secrets
import sys
from pathlib import Path

DIR = Path(__file__).resolve().parent
PRIVADO = DIR / "privado"
ENTRADA = PRIVADO / "validacion_muestra_80_clasificada.csv"
CLAVE = PRIVADO / "clave_seudonimos.txt"
SALIDA = DIR / "validacion_muestra_80_seudonimizada.csv"

COLUMNAS = [
    "id_publicacion", "pais", "keyword_busqueda", "posible_falso_positivo_geografico", "es_bridged",
    "tiene_texto", "clasificacion", "motivo_si_no_relevante", "pais_correcto", "evaluador",
    "clasificacion_b", "pais_correcto_b", "evaluador_b",
]


def clave():
    if not CLAVE.exists():
        CLAVE.write_text(secrets.token_hex(32), encoding="utf-8")
        print(f"Clave nueva creada en {CLAVE} (guardarla: sin ella no se puede re-vincular).")
    return bytes.fromhex(CLAVE.read_text(encoding="utf-8").strip())


def main():
    if not ENTRADA.exists():
        sys.exit(f"No existe {ENTRADA}. Correr antes: python validacion/unir_clasificaciones.py")
    k = clave()
    with open(ENTRADA, encoding="utf-8-sig", newline="") as f:
        filas = list(csv.DictReader(f))
    with open(SALIDA, "w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=COLUMNAS)
        w.writeheader()
        for r in filas:
            fila = {c: r.get(c, "") for c in COLUMNAS}
            fila["id_publicacion"] = hmac.new(k, r["post_uri"].encode("utf-8"), hashlib.sha256).hexdigest()[:16]
            fila["tiene_texto"] = "si" if (r.get("texto") or "").strip() else "no"
            # Las notas son texto libre del evaluador y pueden citar el post o la cuenta: no se publican.
            w.writerow(fila)
    print(f"Escrito: {SALIDA} ({len(filas)} filas)")


if __name__ == "__main__":
    main()
