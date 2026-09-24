"""
Estadísticas de la validación manual de relevancia (muestra de 80 publicaciones).

Convención de columnas del CSV (las genera sortear_muestra_validacion.py):

  Evaluador A (clasifica las 80):
    clasificacion            relevante | parcial | no_relevante | no_clasificable
    motivo_si_no_relevante   texto libre (seguridad_publica, homonimo_geografico,
                             ruido_linguistico, spam_bot, otro...)
    pais_correcto            si | no | no_se
                             ¿el post trata del país con el que se lo buscó (o de
                             organizaciones/personas de ese país)? Es independiente de la
                             relevancia temática: una filtración de datos en Canadá
                             etiquetada "mexico" es relevante en lo temático y NO en lo geográfico.
  Evaluador B (clasifica solo un subconjunto en común, para el acuerdo entre evaluadores):
    clasificacion_b, pais_correcto_b

Reglas:
  - Las filas sin texto (posts que eran solo un link/imagen) se marcan "no_clasificable" y quedan
    FUERA de todos los denominadores; se informa cuántas son.
  - Cualquier valor fuera de los permitidos se informa y esa fila se excluye del cálculo
    (para que un error de tipeo no pase desapercibido).

Uso:
    python3 validacion/calcular_estadisticas_validacion.py [ruta_al_csv]
"""

import csv
import math
import sys
from collections import Counter
from pathlib import Path

CLASES = ("relevante", "parcial", "no_relevante", "no_clasificable")
GEO = ("si", "no", "no_se")


def wilson_ci(k, n, z=1.96):
    """Intervalo de confianza de Wilson para una proporción (mejor que el normal con n chico)."""
    if n == 0:
        return (float("nan"), float("nan"))
    phat = k / n
    denom = 1 + z**2 / n
    centre = phat + z**2 / (2 * n)
    adj = z * math.sqrt((phat * (1 - phat) + z**2 / (4 * n)) / n)
    return (max(0.0, (centre - adj) / denom), min(1.0, (centre + adj) / denom))


def cohen_kappa(a, b):
    """Kappa de Cohen entre dos listas de etiquetas del mismo largo."""
    n = len(a)
    if n == 0:
        return float("nan")
    po = sum(1 for x, y in zip(a, b) if x == y) / n
    cats = set(a) | set(b)
    pe = sum((a.count(c) / n) * (b.count(c) / n) for c in cats)
    if pe == 1:
        return 1.0
    return (po - pe) / (1 - pe)


def interpretar_kappa(k):
    """Escala de Landis y Koch (1977). Es una convención, no una prueba estadística."""
    if math.isnan(k):
        return "sin datos"
    if k < 0:
        return "peor que el azar"
    for tope, nombre in ((0.20, "leve"), (0.40, "regular"), (0.60, "moderado"), (0.80, "sustancial")):
        if k <= tope:
            return nombre
    return "casi perfecto"


def fmt(k, n):
    if n == 0:
        return "sin datos"
    lo, hi = wilson_ci(k, n)
    return f"{k}/{n} = {k / n * 100:.1f}%  IC 95% [{lo * 100:.1f}%, {hi * 100:.1f}%]"


def limpiar(v):
    return (v or "").strip().lower()


def main(path):
    with open(path, encoding="utf-8", newline="") as f:
        rows = list(csv.DictReader(f))
    if not rows:
        print("El CSV no tiene filas.")
        return 1

    print(f"Filas totales: {len(rows)}")

    # --- validación de los valores cargados ---
    invalidas = []
    sin_clasificar = 0
    for i, r in enumerate(rows, start=2):  # +2: línea 1 es el encabezado
        c = limpiar(r.get("clasificacion"))
        g = limpiar(r.get("pais_correcto"))
        if not c:
            sin_clasificar += 1
        elif c not in CLASES:
            invalidas.append((i, "clasificacion", r.get("clasificacion")))
        if g and g not in GEO:
            invalidas.append((i, "pais_correcto", r.get("pais_correcto")))
    if invalidas:
        print("\nVALORES NO RECONOCIDOS (se excluyen del cálculo; corregir en el CSV):")
        for linea, col, val in invalidas:
            print(f"  línea {linea}: {col} = {val!r}")
    if sin_clasificar:
        print(f"Filas sin clasificar todavía: {sin_clasificar}")

    malas = {ln for ln, _, _ in invalidas}
    clasificadas = [r for i, r in enumerate(rows, start=2)
                    if limpiar(r.get("clasificacion")) in CLASES and i not in malas]
    utiles = [r for r in clasificadas if limpiar(r["clasificacion"]) != "no_clasificable"]
    no_clasif = len(clasificadas) - len(utiles)
    vacios = sum(1 for r in rows if not (r.get("texto") or "").strip())
    print(f"Clasificadas: {len(clasificadas)} | marcadas no_clasificable: {no_clasif} "
          f"(filas sin texto en la muestra: {vacios}) | base de cálculo (n): {len(utiles)}")
    if not utiles:
        print("\nTodavía no hay filas clasificables: completar el CSV y volver a correr.")
        return 0

    n = len(utiles)
    conteo = Counter(limpiar(r["clasificacion"]) for r in utiles)
    print("Distribución:", {k: conteo.get(k, 0) for k in ("relevante", "parcial", "no_relevante")})

    rel = conteo.get("relevante", 0)
    par = conteo.get("parcial", 0)
    print("\n== Relevancia temática ==")
    print("Precisión estricta ('relevante'):          ", fmt(rel, n))
    print("Precisión amplia ('relevante' + 'parcial'):", fmt(rel + par, n))

    print("\nPor país (n chico -> IC ancho; declararlo en el texto):")
    for pais in sorted({r["pais"] for r in utiles}):
        sub = [r for r in utiles if r["pais"] == pais]
        k = sum(1 for r in sub if limpiar(r["clasificacion"]) == "relevante")
        print(f"  {pais:<10} {fmt(k, len(sub))}")

    motivos = Counter(
        (r.get("motivo_si_no_relevante") or "").strip()
        for r in utiles
        if limpiar(r["clasificacion"]) in ("no_relevante", "parcial") and (r.get("motivo_si_no_relevante") or "").strip()
    )
    if motivos:
        print("\nMotivos de no relevancia / parcial:")
        for m, c in motivos.most_common():
            print(f"  {m}: {c}")

    # --- relevancia geográfica ---
    con_geo = [r for r in utiles if limpiar(r.get("pais_correcto")) in ("si", "no")]
    print("\n== Relevancia geográfica (¿trata del país buscado?) ==")
    if con_geo:
        ok = sum(1 for r in con_geo if limpiar(r["pais_correcto"]) == "si")
        print("Sobre todas las filas con dato geográfico:", fmt(ok, len(con_geo)))
        tem = [r for r in con_geo if limpiar(r["clasificacion"]) in ("relevante", "parcial")]
        ok_t = sum(1 for r in tem if limpiar(r["pais_correcto"]) == "si")
        print("Sobre las temáticamente relevantes/parciales:", fmt(ok_t, len(tem)))
        ambas = sum(1 for r in con_geo if limpiar(r["clasificacion"]) == "relevante" and limpiar(r["pais_correcto"]) == "si")
        print("Relevante en LO TEMÁTICO Y en LO GEOGRÁFICO (criterio estricto para H2):", fmt(ambas, len(con_geo)))
        marcadas = [r for r in con_geo if (r.get("posible_falso_positivo_geografico") or "").strip() == "True"]
        if marcadas:
            ok_m = sum(1 for r in marcadas if limpiar(r["pais_correcto"]) == "si")
            print(f"Filas marcadas por el flag New Mexico ({len(marcadas)}): con país correcto = {ok_m} "
                  f"(el flag solo cubre ese caso; el resto de errores geográficos no lo dispara)")
    else:
        print("Todavía no se cargó pais_correcto en ninguna fila.")

    # --- acuerdo entre evaluadores ---
    dobles = [r for r in rows
              if limpiar(r.get("clasificacion")) in CLASES and limpiar(r.get("clasificacion_b")) in CLASES]
    print("\n== Acuerdo entre evaluadores ==")
    if dobles:
        a = [limpiar(r["clasificacion"]) for r in dobles]
        b = [limpiar(r["clasificacion_b"]) for r in dobles]
        acuerdo = sum(1 for x, y in zip(a, b) if x == y) / len(dobles)
        k = cohen_kappa(a, b)
        print(f"Clasificadas por ambos: {len(dobles)} | acuerdo simple: {acuerdo * 100:.1f}% | "
              f"kappa de Cohen: {k:.3f} ({interpretar_kappa(k)})")
        dg = [r for r in dobles if limpiar(r.get("pais_correcto")) in GEO and limpiar(r.get("pais_correcto_b")) in GEO]
        if dg:
            kg = cohen_kappa([limpiar(r["pais_correcto"]) for r in dg], [limpiar(r["pais_correcto_b"]) for r in dg])
            print(f"Kappa en relevancia geográfica (n={len(dg)}): {kg:.3f} ({interpretar_kappa(kg)})")
        if len(dobles) < 20:
            print("Aviso: con menos de ~20 filas en común el kappa es muy inestable.")
        difer = [(i, r) for i, r in enumerate(rows, start=2) if r in dobles
                 and limpiar(r["clasificacion"]) != limpiar(r["clasificacion_b"])]
        if difer:
            print("Desacuerdos para discutir (línea del CSV): " + ", ".join(str(i) for i, _ in difer))
    else:
        print("Ninguna fila tiene clasificacion_b: para calcular el kappa, el segundo evaluador debe "
              "clasificar un subconjunto en común (sugerido: 30-40 filas).")
    return 0


if __name__ == "__main__":
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    ruta = sys.argv[1] if len(sys.argv) > 1 else str(Path(__file__).resolve().parent / "validacion_muestra_80.csv")
    sys.exit(main(ruta))
