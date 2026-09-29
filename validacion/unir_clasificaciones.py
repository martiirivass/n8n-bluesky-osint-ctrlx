"""
Une las dos planillas ya clasificadas (evaluador A y B) con la muestra base y genera el CSV que
lee calcular_estadisticas_validacion.py.

Las filas se emparejan por post_uri (no por posición), así que da igual si alguien ordenó o filtró
la planilla en Excel.

Uso:
    python3 validacion/unir_clasificaciones.py
    python3 validacion/calcular_estadisticas_validacion.py validacion/validacion_muestra_80_clasificada.csv
"""

import csv
import sys
from pathlib import Path

from openpyxl import load_workbook

DIR = Path(__file__).resolve().parent
BASE = DIR / "privado" / "validacion_muestra_80.csv"  # privado/: textos y URIs, no se versiona
PLANILLA_A = DIR / "privado" / "planilla_evaluador_A.xlsx"
PLANILLA_B = DIR / "privado" / "planilla_evaluador_B.xlsx"
SALIDA = DIR / "privado" / "validacion_muestra_80_clasificada.csv"


def leer_planilla(ruta):
    """Devuelve {post_uri: {columna: valor}} usando la hoja 'Clasificar'."""
    ws = load_workbook(ruta, data_only=True)["Clasificar"]
    filas = list(ws.iter_rows(values_only=True))
    encabezado = [str(c).strip() if c is not None else "" for c in filas[0]]
    out = {}
    for f in filas[1:]:
        reg = {encabezado[i]: ("" if v is None else str(v).strip()) for i, v in enumerate(f) if i < len(encabezado)}
        uri = reg.get("post_uri", "")
        if uri:
            out[uri] = reg
    return out


def main():
    with open(BASE, encoding="utf-8", newline="") as f:
        lector = csv.DictReader(f)
        columnas = lector.fieldnames
        base = list(lector)
    uris = {r["post_uri"] for r in base}

    a = leer_planilla(PLANILLA_A)
    b = leer_planilla(PLANILLA_B)

    problemas = []
    for nombre, planilla in (("A", a), ("B", b)):
        raras = [u for u in planilla if u not in uris]
        if raras:
            problemas.append(f"planilla {nombre}: {len(raras)} post_uri que no están en la muestra base")
    if problemas:
        print("ERROR:\n  " + "\n  ".join(problemas))
        return 1

    for r in base:
        ra = a.get(r["post_uri"], {})
        rb = b.get(r["post_uri"], {})
        for col in ("clasificacion", "pais_correcto", "motivo_si_no_relevante", "notas"):
            r[col] = ra.get(col, "")
        r["evaluador"] = ra.get("evaluador", "") if ra.get("clasificacion") else ""
        for col in ("clasificacion_b", "pais_correcto_b"):
            r[col] = rb.get(col, "")
        r["evaluador_b"] = rb.get("evaluador", "") if rb.get("clasificacion_b") else ""

    with open(SALIDA, "w", encoding="utf-8-sig", newline="") as f:  # utf-8-sig: Excel lo abre bien
        w = csv.DictWriter(f, fieldnames=columnas)
        w.writeheader()
        w.writerows(base)

    hechos_a = sum(1 for r in base if r["clasificacion"])
    hechos_b = sum(1 for r in base if r["clasificacion_b"])
    ambos = sum(1 for r in base if r["clasificacion"] and r["clasificacion_b"])
    print(f"Evaluador A: {hechos_a}/{len(base)} clasificadas | Evaluador B: {hechos_b} | en común: {ambos}")
    print(f"Escrito: {SALIDA}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
