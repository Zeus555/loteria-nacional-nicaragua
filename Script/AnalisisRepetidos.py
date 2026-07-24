"""AnalisisRepetidos.py - El reclamo historico: el mismo numero gana premios
destacados en sorteos cercanos ("gana el mayor hoy y el segundo el siguiente").

Metodo:
  1. Censo de premios DESTACADOS por sorteo (MAYOR..SEXTO o monto >= 30,000),
     con las correcciones de congruencia aplicadas.
  2. Busca numeros que ganaron destacado en 2+ sorteos con separacion <= G.
  3. Calcula cuantas coincidencias esperaria un sorteo JUSTO: para cada par de
     sorteos (a, b) con separacion g, P = F_a * F_b / E_b (F = destacados del
     sorteo, E = emision inferida). El total esperado se compara con lo
     observado via Poisson.
  4. Ademas evalua el caso emblema: numero del PREMIO MAYOR que reaparece como
     destacado en los siguientes sorteos.

Salida: Resultados/RepetidosReporte.json + consola.
"""
import csv
import json
import math
import os
from collections import defaultdict

RAIZ = r"D:\PRC Loteria Nacional"
EXTRACCION = os.path.join(RAIZ, "Resultados", "ExtraccionV2.csv")
CORRECCIONES = os.path.join(RAIZ, "Resultados", "CongruenciaCorrecciones.csv")
SAL = os.path.join(RAIZ, "Resultados", "RepetidosReporte.json")

ORDEN = {"MAYOR", "SEGUNDO", "TERCER", "CUARTO", "QUINTO", "SEXTO", "Destacado"}
UMBRAL = 30000.0
GAPS = (1, 2, 5, 10)      # separaciones a evaluar (en numeros de sorteo)


def gammln(x):
    cof = [76.18009172947146, -86.50532032941677, 24.01409824083091,
           -1.231739572450155, 0.1208650973866179e-2, -0.5395239384953e-5]
    y = x
    tmp = x + 5.5 - (x + 0.5) * math.log(x + 5.5)
    ser = 1.000000000190015
    for c in cof:
        y += 1.0
        ser += c / y
    return -tmp + math.log(2.5066282746310005 * ser / x)


def poisson_sf(obs, mu):
    """P(X >= obs) con X ~ Poisson(mu)."""
    if obs <= 0:
        return 1.0
    acum = 0.0
    for k in range(0, obs):
        acum += math.exp(-mu + k * math.log(mu) - gammln(k + 1))
    return max(0.0, 1.0 - acum)


HTML_VIEJO = os.path.join(RAIZ, "Resultados", "ExtraccionHtmlViejo.csv")
UMBRAL_VIEJO = 10000.0    # el plan 2002-05 es mas chico: destacado desde C$10K


def carga():
    filas = defaultdict(list)
    for ruta in (EXTRACCION, HTML_VIEJO):
        if not os.path.exists(ruta):
            continue
        with open(ruta, encoding="ascii", errors="replace") as fh:
            for f in csv.reader(fh, delimiter="|"):
                if f and f[0].isdigit() and len(f) >= 5:
                    monto = float(f[3]) if f[3] else None
                    filas[int(f[0])].append([f[1], f[2], monto])
    # Aplica correcciones de congruencia (tipo y monto).
    if os.path.exists(CORRECCIONES):
        cor_tipo = {}
        cor_monto = {}
        with open(CORRECCIONES, encoding="ascii") as fh:
            for c in csv.DictReader(fh, delimiter="|"):
                s = int(c["sorteo"])
                if c["actual"].startswith("monto:"):
                    v = c["nuevo"][6:]
                    cor_monto[(s, c["numero"], float(c["actual"][6:]))] = (
                        None if v == "NULL" else float(v))
                else:
                    cor_tipo[(s, c["numero"], c["actual"])] = c["nuevo"]
        for s, rows in filas.items():
            for r in rows:
                nt = cor_tipo.get((s, r[1], r[0]))
                if nt:
                    r[0] = nt
                if r[2] is not None:
                    nm = cor_monto.get((s, r[1], r[2]), "sin")
                    if nm != "sin":
                        r[2] = nm
    return filas


def main():
    filas = carga()
    sorteos = sorted(filas)

    emision = {}
    destacados = {}           # sorteo -> {numero: (tipo, monto)}
    for s in sorteos:
        maxn = max(int(r[1]) for r in filas[s])
        emision[s] = int(math.ceil((maxn + 1) / 1000.0) * 1000)
        umbral = UMBRAL_VIEJO if s < 1356 else UMBRAL
        d = {}
        for tipo, numero, monto in filas[s]:
            es_dest = (tipo in ORDEN) or (monto is not None and monto >= umbral)
            if es_dest and (monto is None or monto >= 1000):
                prev = d.get(numero)
                if prev is None or (monto or 0) > (prev[1] or 0):
                    d[numero] = (tipo, monto)
        destacados[s] = d

    nds = {s: len(destacados[s]) for s in sorteos}
    media_f = sum(nds.values()) / len(sorteos)
    print("Sorteos: %d | destacados por sorteo: media %.1f | emision media %d"
          % (len(sorteos), media_f, sum(emision.values()) // len(sorteos)))

    # --- Observados: mismo numero destacado en dos sorteos cercanos ---
    apariciones = defaultdict(list)   # numero -> [(sorteo, tipo, monto)]
    for s in sorteos:
        for numero, (tipo, monto) in destacados[s].items():
            apariciones[numero].append((s, tipo, monto))

    casos = []                        # (gap, numero, s1, t1, m1, s2, t2, m2)
    for numero, aps in apariciones.items():
        aps.sort()
        for i in range(len(aps)):
            for j in range(i + 1, len(aps)):
                gap = aps[j][0] - aps[i][0]
                if gap <= max(GAPS):
                    casos.append((gap, numero, aps[i], aps[j]))
    casos.sort()

    print()
    print("Casos observados (mismo numero, destacado 2 veces, separacion <= %d):" % max(GAPS))
    for gap, numero, a, b in casos:
        print("  gap %d: %s | sorteo %d %s C$%s -> sorteo %d %s C$%s"
              % (gap, numero, a[0], a[1], ("%.0f" % a[2]) if a[2] else "?",
                 b[0], b[1], ("%.0f" % b[2]) if b[2] else "?"))
    if not casos:
        print("  (ninguno)")

    # --- Esperados bajo azar, por banda de separacion ---
    idx = {s: i for i, s in enumerate(sorteos)}
    resultados = []
    for G in GAPS:
        esperado = 0.0
        pares = 0
        for i, a in enumerate(sorteos):
            for b in sorteos[i + 1:]:
                g = b - a
                if g > G:
                    break
                esperado += nds[a] * nds[b] / float(emision[b])
                pares += 1
        observado = sum(1 for gap, _, _, _ in casos if gap <= G)
        p = poisson_sf(observado, esperado)
        resultados.append({"gap_max": G, "pares_de_sorteos": pares,
                           "observado": observado,
                           "esperado": round(esperado, 2),
                           "p_value": round(p, 4)})

    print()
    print("Comparacion contra un sorteo justo (Poisson):")
    print("  %-12s %-10s %-10s %s" % ("separacion", "observado", "esperado", "p-value"))
    for r in resultados:
        marca = "  <-- SOSPECHOSO" if r["p_value"] < 0.01 else ""
        print("  <= %-9d %-10d %-10.2f %.4f%s"
              % (r["gap_max"], r["observado"], r["esperado"], r["p_value"], marca))

    # --- Caso emblema: el MAYOR reaparece como destacado en <= 5 sorteos ---
    emblema = [c for c in casos
               if c[0] <= 5 and (c[2][1] == "MAYOR" or c[3][1] == "MAYOR")]
    print()
    print("Caso emblema (involucra al PREMIO MAYOR, separacion <= 5): %d casos"
          % len(emblema))

    with open(SAL, "w", encoding="ascii") as fh:
        json.dump({
            "sorteos": len(sorteos),
            "destacados_media": round(media_f, 2),
            "bandas": resultados,
            "casos": [{"gap": g, "numero": n,
                       "primero": {"sorteo": a[0], "tipo": a[1], "monto": a[2]},
                       "segundo": {"sorteo": b[0], "tipo": b[1], "monto": b[2]}}
                      for g, n, a, b in casos],
            "emblema_con_mayor": len(emblema),
        }, fh, indent=1)
    print()
    print("Reporte:", SAL)


if __name__ == "__main__":
    main()
