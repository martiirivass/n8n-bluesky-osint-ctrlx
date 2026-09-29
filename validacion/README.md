# Validación manual de relevancia temática

Metodología: sección 5.6 de la tesis.

- Muestra: 80 publicaciones, muestreo aleatorio simple, semilla fija (2026), sobre el corte final de 3.908 publicaciones (database/export_posts_latam.json, hash SHA-256: 73c35ee1454eaa63528350061186fdecf849812fcfb7842c048e9a0e8d373c00).
- Evaluador A (Enzo Dengra): clasificó las 80 publicaciones completas.
- Evaluador B (Martiniano Rivas): clasificó una submuestra de 40 en común, de forma independiente, para calcular acuerdo entre evaluadores.
- Resultados: 89,5% de relevancia combinada (IC 95% [80,6%, 94,6%]), 85,5% de precisión geográfica, κ=0,356 (relevancia) y κ=0,758 (país). Detalle completo en sección 5.6 y recomendación 8.16 de la tesis.

## Datos públicos y privados

La muestra con textos, URIs de los posts (contienen el DID del autor) y handles, y las planillas de
los evaluadores, están en `validacion/privado/`, que **no se versiona**. En el repositorio queda
`validacion_muestra_80_seudonimizada.csv`: el identificador de cada post es un HMAC con clave
privada y no incluye texto ni autor. Alcanza para recalcular todas las estadísticas.

## Reproducir

```
python validacion/calcular_estadisticas_validacion.py            # desde el CSV público
```

Cadena completa (requiere el export y la carpeta privado/):

```
python validacion/sortear_muestra_validacion.py     # -> privado/validacion_muestra_80.csv (reproduce byte a byte con el export 73c35ee1…)
python validacion/preparar_planillas.py             # -> planillas para los evaluadores
python validacion/unir_clasificaciones.py           # planillas A y B -> privado/validacion_muestra_80_clasificada.csv
python validacion/seudonimizar_validacion.py        # -> validacion_muestra_80_seudonimizada.csv (versionado)
```

## Estado de la verificación (2026-09-29)

- 89,5 % [80,6 %; 94,6 %]: se reproduce.
- 85,5 % de precisión geográfica = 65/76 (las 9 filas `no_se` cuentan como no correctas). El script
  informa además 65/67 = 97,0 % excluyéndolas. Declarar el denominador en la tesis.
- κ = 0,356 y κ = 0,758: **no se reproducen**, la planilla B que estaba versionada no tiene
  clasificaciones. Falta incorporar la planilla B completa.
