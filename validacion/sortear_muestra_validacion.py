"""
Sorteo de la muestra de validación manual de relevancia temática — corte final (n=3.908).

Contexto: la muestra de validación de la versión anterior de este capítulo (n=80, sobre un
universo de 4.016 publicaciones) no se conservó en el repositorio (ni semilla, ni lista de
posts, ni script). El universo también cambió: se retiraron 113 posts de "CERT" y 141 de
"incidente de seguridad" (sección 5.2 de la tesis), por lo que aunque se recuperara la semilla
original, el sorteo caería sobre otros posts. Esta es, por lo tanto, una muestra NUEVA,
metodológicamente equivalente a la anterior pero no una continuación de ella. Se documenta así
en la tesis para no sugerir una comparabilidad que no existe entre las publicaciones puntuales
elegidas.

Uso (desde cualquier carpeta):
    python3 validacion/sortear_muestra_validacion.py

Requiere: database/export_posts_latam.json en el mismo formato que expone el Workflow 2
(clave "posts": lista de publicaciones). OJO: el sorteo depende del ORDEN y del CONTENIDO de
ese archivo. Si se vuelve a exportar con datos nuevos, el resultado cambia. Para reproducir la
muestra hay que usar el export con el mismo SHA-256 que imprime este script (ver abajo).

Salida: validacion/validacion_muestra_80.csv, con una fila por publicación sorteada y columnas
vacías para que el equipo complete la clasificación manual.
"""

import csv
import hashlib
import json
import random
import sys
from collections import Counter
from pathlib import Path

SEED = 2026          # semilla fija — reutilizar este valor reproduce exactamente esta muestra
N = 80                # tamaño de muestra (2,05% del universo de 3.908)

RAIZ = Path(__file__).resolve().parent.parent
INPUT_PATH = RAIZ / "database" / "export_posts_latam.json"
OUTPUT_PATH = Path(__file__).resolve().parent / "validacion_muestra_80.csv"


def main():
    raw = INPUT_PATH.read_bytes()
    data = json.loads(raw.decode("utf-8"))
    posts = data["posts"]

    universo = len(posts)
    print(f"Universo: {universo} publicaciones")
    print(f"SHA-256 del export: {hashlib.sha256(raw).hexdigest()}")
    print(f"Python {sys.version.split()[0]} | semilla {SEED} | n {N}")

    random.seed(SEED)
    sample = random.sample(posts, N)

    fieldnames = [
        "post_uri", "texto", "autor_handle", "pais", "keyword_busqueda",
        "posible_falso_positivo_geografico", "es_bridged",
        # Evaluador A (clasifica las 80): relevancia temática + relevancia geográfica
        "clasificacion", "motivo_si_no_relevante", "pais_correcto", "evaluador", "notas",
        # Evaluador B (clasifica solo un subconjunto en común, para el kappa)
        "clasificacion_b", "pais_correcto_b", "evaluador_b",
    ]
    with open(OUTPUT_PATH, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        for p in sample:
            w.writerow({
                "post_uri": p.get("post_uri"),
                "texto": (p.get("texto") or "").replace("\n", " ").strip(),
                "autor_handle": p.get("autor_handle"),
                "pais": p.get("pais"),
                "keyword_busqueda": p.get("keyword_busqueda"),
                "posible_falso_positivo_geografico": p.get("posible_falso_positivo_geografico"),
                "es_bridged": p.get("es_bridged"),
                "clasificacion": "",
                "motivo_si_no_relevante": "",
                "pais_correcto": "",
                "evaluador": "",
                "notas": "",
                "clasificacion_b": "",
                "pais_correcto_b": "",
                "evaluador_b": "",
            })

    vacios = sum(1 for p in sample if not (p.get("texto") or "").strip())
    print(f"Muestra: {N} publicaciones ({vacios} con texto vacío, no clasificables)")
    print("Por país:", dict(Counter(p.get("pais") for p in sample)))
    print(f"Escrito: {OUTPUT_PATH}")


if __name__ == "__main__":
    sys.exit(main())
