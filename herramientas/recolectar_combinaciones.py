"""
Corre la recolección completa (8 keywords × 5 países = 40 combinaciones) llamando al webhook del
Workflow 3, una combinación por vez. Cada llamada queda registrada en `ejecuciones_recoleccion`
y cada post devuelto en `capturas` (N:M), así que al terminar se puede medir exactamente cuántas
publicaciones fueron devueltas por más de una combinación (ver METODOLOGIA.md, sección 5).

Uso (desde la raíz del repo, con n8n levantado y el Workflow 3 publicado):
    set OSINT_API_KEY=<valor de la credential "Header Auth" de los webhooks>     (Windows)
    export OSINT_API_KEY=<...>                                                   (Linux/macOS)
    python herramientas/recolectar_combinaciones.py

Opcional:
    OSINT_WEBHOOK_URL   (default http://localhost:5678/webhook/nueva-busqueda)
    OSINT_API_HEADER    (default X-API-Key)

Rate limit: la sesión de Bluesky se reutiliza entre corridas (tabla bluesky_sesion), así que las
40 combinaciones consumen como mucho 1 createSession. Igual se espera PAUSA_S segundos entre
combinaciones para no concentrar las llamadas a searchPosts.
"""

import json
import os
import sys
import time
import urllib.error
import urllib.request

KEYWORDS = [
    "ransomware", "ciberseguridad", "malware", "hacking", "data breach",
    "ciberataque", "filtración de datos", "seguridad informática",
]
PAISES = ["argentina", "brasil", "chile", "colombia", "mexico"]
PAUSA_S = 10

URL = os.environ.get("OSINT_WEBHOOK_URL", "http://localhost:5678/webhook/nueva-busqueda")
HEADER = os.environ.get("OSINT_API_HEADER", "X-API-Key")
API_KEY = os.environ.get("OSINT_API_KEY")


def buscar(keyword, pais):
    cuerpo = json.dumps({"keyword": keyword, "pais": pais}).encode("utf-8")
    req = urllib.request.Request(URL, data=cuerpo, method="POST", headers={
        "Content-Type": "application/json", HEADER: API_KEY,
    })
    with urllib.request.urlopen(req, timeout=600) as resp:
        return json.loads(resp.read().decode("utf-8"))


def main():
    if not API_KEY:
        sys.exit("Falta la variable de entorno OSINT_API_KEY.")
    sys.stdout.reconfigure(encoding="utf-8")
    combinaciones = [(k, p) for p in PAISES for k in KEYWORDS]
    fallidas = []
    for i, (keyword, pais) in enumerate(combinaciones, 1):
        try:
            r = buscar(keyword, pais)
            print(f"[{i:2}/{len(combinaciones)}] {pais:9} | {keyword:22} | ejecución {r.get('ejecucion_id')} | "
                  f"{r.get('posts_procesados')} posts | {r.get('paginas_obtenidas')} pág. | "
                  f"cursor agotado: {r.get('cursor_agotado')}")
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as e:
            print(f"[{i:2}/{len(combinaciones)}] {pais:9} | {keyword:22} | ERROR: {e}")
            fallidas.append((keyword, pais))
        if i < len(combinaciones):
            time.sleep(PAUSA_S)
    if fallidas:
        print("\nCombinaciones con error (volver a correrlas):")
        for keyword, pais in fallidas:
            print(f"  {keyword} × {pais}")
        sys.exit(1)


if __name__ == "__main__":
    main()
