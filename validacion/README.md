# Validación manual de relevancia temática

Metodología: sección 5.6 de la tesis.

- Muestra: 80 publicaciones, muestreo aleatorio simple, semilla fija (2026), sobre el corte final de 3.908 publicaciones (database/export_posts_latam.json, hash SHA-256: 73c35ee1454eaa63528350061186fdecf849812fcfb7842c048e9a0e8d373c00).
- Evaluador A (Enzo Dengra): clasificó las 80 publicaciones completas (planilla_evaluador_A.xlsx).
- Evaluador B (Martiniano Rivas): clasificó una submuestra de 40 en común, de forma independiente, para calcular acuerdo entre evaluadores (planilla_evaluador_B.xlsx).
- Resultados: 89,5% de relevancia combinada (IC 95% [80,6%, 94,6%]), 85,5% de precisión geográfica, κ=0,356 (relevancia) y κ=0,758 (país). Detalle completo en sección 5.6 y recomendación 8.16 de la tesis.

Para reproducir el sorteo: `python3 sortear_muestra_validacion.py`
