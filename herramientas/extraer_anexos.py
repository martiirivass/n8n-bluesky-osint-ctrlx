"""
Genera los anexos de código de la tesis directamente desde los archivos versionados, para que
nunca documenten un estado del sistema distinto del que está en el repositorio.

  docs/anexos/anexo_B_codigo.md  -> por workflow: conexiones, nodos en orden de recorrido del grafo, y el
                                    código completo de cada nodo Code, consulta SQL y request HTTP.
  docs/anexos/anexo_C_ddl.sql    -> database/schema.sql (instalación desde cero) seguido de la
                                    migración 001 (bases existentes).

Cada anexo lleva el SHA-256 de los archivos de los que salió: si el texto de la tesis cita el
mismo hash, se puede verificar que el anexo corresponde al código evaluado.

Uso (desde la raíz del repo):
    python herramientas/extraer_anexos.py
"""

import hashlib
import json
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
N8N = RAIZ / "n8n"
SALIDA = RAIZ / "docs" / "anexos"
WORKFLOWS = [
    "Workflow 1_ Recolección de datos - Bluesky OSINT V2.json",
    "Workflow 2_ API para el dashboard - Bluesky OSINT V2.json",
    "Workflow 3_ Nueva búsqueda desde el dashboard - Bluesky OSINT.json",
]
DDL = [RAIZ / "database" / "schema.sql", RAIZ / "database" / "migraciones" / "001_capturas_ejecuciones_sesion_indices.sql"]


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def orden_de_ejecucion(wf):
    """Recorrido en anchura desde los nodos sin entrada (triggers y nodos sueltos). Con ramas (IF),
    es el orden del grafo, no necesariamente el orden temporal de una ejecución concreta."""
    nombres = [n["name"] for n in wf["nodes"]]
    salientes = {k: [c["node"] for salida in v["main"] for c in salida] for k, v in wf["connections"].items()}
    con_entrada = {d for ds in salientes.values() for d in ds}
    orden, cola = [], [n for n in nombres if n not in con_entrada]
    while cola:
        n = cola.pop(0)
        if n in orden:
            continue
        orden.append(n)
        cola.extend(salientes.get(n, []))
    return orden + [n for n in nombres if n not in orden]


def bloque(lenguaje, texto):
    return f"```{lenguaje}\n{texto.rstrip()}\n```\n"


def describir_nodo(n):
    p = n["parameters"]
    tipo = n["type"].replace("n8n-nodes-base.", "")
    partes = [f"#### {n['name']}\n", f"Tipo: `{tipo}` (v{n['typeVersion']})"]
    ajustes = [f"{k}={n[k]}" for k in ("executeOnce", "alwaysOutputData", "retryOnFail", "maxTries",
                                        "waitBetweenTries", "onError") if k in n]
    if ajustes:
        partes[-1] += " · " + ", ".join(ajustes)
    partes[-1] += "\n"
    if tipo == "code":
        partes.append(bloque("javascript", p["jsCode"]))
    elif tipo == "postgres":
        if p.get("operation") == "executeQuery":
            partes.append(bloque("sql", p["query"]))
            if p.get("options", {}).get("queryReplacement"):
                partes.append(f"Parámetros ($1, $2, …): `{p['options']['queryReplacement']}`\n")
        else:
            cols = p.get("columns", {}).get("value", {})
            partes.append(f"Operación `{p.get('operation')}` sobre `{p.get('table', {}).get('value')}`, "
                          f"coincidencia por `{', '.join(p.get('columns', {}).get('matchingColumns', []))}`.\n")
            partes.append(bloque("json", json.dumps(cols, ensure_ascii=False, indent=2)))
    elif tipo in ("httpRequest", "webhook", "respondToWebhook", "set", "if", "splitOut"):
        partes.append(bloque("json", json.dumps(p, ensure_ascii=False, indent=2)))
    return "\n".join(partes)


def anexo_b():
    lineas = ["# Anexo B — Código de los workflows de n8n\n",
              "Generado con `python herramientas/extraer_anexos.py` a partir de los archivos exportados "
              "de n8n. No editar a mano.\n",
              "| Archivo | SHA-256 |", "|---|---|"]
    lineas += [f"| `n8n/{w}` | `{sha256(N8N / w)}` |" for w in WORKFLOWS]
    lineas.append("")
    for w in WORKFLOWS:
        wf = json.loads((N8N / w).read_text(encoding="utf-8"))
        nodos = {n["name"]: n for n in wf["nodes"]}
        lineas.append(f"## {wf['name']}\n")
        lineas.append("### Conexiones\n")
        for origen, v in wf["connections"].items():
            for i, salida in enumerate(v["main"]):
                destinos = ", ".join(c["node"] for c in salida)
                etiqueta = f" (salida {i})" if len(v["main"]) > 1 else ""
                lineas.append(f"- {origen}{etiqueta} → {destinos}")
        lineas.append("\n### Nodos (en orden de recorrido del grafo, desde el disparador)\n")
        for nombre in orden_de_ejecucion(wf):
            lineas.append(describir_nodo(nodos[nombre]))
    return "\n".join(lineas)


def anexo_c():
    partes = ["-- Anexo C — DDL de la base de datos",
              "-- Generado con `python herramientas/extraer_anexos.py`. No editar a mano."]
    for f in DDL:
        partes.append(f"-- {f.relative_to(RAIZ).as_posix()}  SHA-256 {sha256(f)}")
    for f in DDL:
        partes.append(f"\n-- =====================================================================\n"
                      f"-- {f.relative_to(RAIZ).as_posix()}\n"
                      f"-- =====================================================================\n")
        partes.append(f.read_text(encoding="utf-8").rstrip())
    return "\n".join(partes) + "\n"


def main():
    SALIDA.mkdir(parents=True, exist_ok=True)
    (SALIDA / "anexo_B_codigo.md").write_text(anexo_b(), encoding="utf-8")
    (SALIDA / "anexo_C_ddl.sql").write_text(anexo_c(), encoding="utf-8")
    print(f"Escritos: {SALIDA / 'anexo_B_codigo.md'}\n          {SALIDA / 'anexo_C_ddl.sql'}")


if __name__ == "__main__":
    main()
