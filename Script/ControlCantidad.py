"""ControlCantidad.py - Control de calidad: cantidad de numeros publicados.

Regla de negocio: cada lista oficial publica una cantidad fija de numeros
(definida por el plan de premios). Esa cantidad puede cambiar entre epocas,
pero dentro de una epoca debe ser constante: un sorteo con muchos menos
numeros que sus vecinos delata extraccion incompleta (o pagina faltante), y
uno con muchos mas delata duplicados o ruido.

Metodo: cantidad esperada por sorteo = mediana movil (ventana de 51 sorteos
vecinos). Se marca desviacion si |real - esperada| > TOLERANCIA.

Uso:
  python ControlCantidad.py             # reporte
  python ControlCantidad.py --actualiza # ademas escribe premios_esperados en
                                        # Resultados/CantidadEsperada.csv (para BD)

Salida: Resultados/CantidadReporte.json
"""
import csv
import json
import os
import sys
from collections import defaultdict, Counter

RAIZ = r"D:\PRC Loteria Nacional"
EXTRACCION = os.path.join(RAIZ, "Resultados", "ExtraccionV2.csv")
SAL_REP = os.path.join(RAIZ, "Resultados", "CantidadReporte.json")
SAL_ESP = os.path.join(RAIZ, "Resultados", "CantidadEsperada.csv")

VENTANA = 25          # vecinos a cada lado para la mediana movil
TOLERANCIA = 15       # desviacion admisible en numeros

# La cantidad esperada depende del TIPO de sorteo (planes de premios
# distintos): ordinarios ~658, extraordinarios ~458 en la era moderna
# (los extraordinarios tempranos, hasta ~1571, tambien publicaban ~658).
# Por eso la mediana movil se calcula DENTRO de cada tipo.


def carga():
    total = defaultdict(int)
    distintos = defaultdict(set)
    with open(EXTRACCION, encoding="ascii", errors="replace") as fh:
        for f in csv.reader(fh, delimiter="|"):
            if not f or not f[0].isdigit() or len(f) < 3:
                continue
            s = int(f[0])
            total[s] += 1
            distintos[s].add(f[2])
    tipos = {}
    verifs = sorted(f for f in os.listdir(os.path.join(RAIZ, "Resultados"))
                    if f.startswith("VerificacionPDFs_") and f.endswith(".csv"))
    if verifs:
        with open(os.path.join(RAIZ, "Resultados", verifs[-1]),
                  encoding="utf-8-sig") as fh:
            for fila in csv.DictReader(fh):
                if fila["archivo"].isdigit():
                    tipos[int(fila["archivo"])] = fila["tipo"] or "?"
    return total, {s: len(v) for s, v in distintos.items()}, tipos


def mediana(vals):
    v = sorted(vals)
    n = len(v)
    return v[n // 2] if n % 2 else (v[n // 2 - 1] + v[n // 2]) / 2.0


def main():
    actualiza = "--actualiza" in sys.argv
    total, distintos, tipos = carga()
    sorteos = sorted(total)
    n = len(sorteos)

    conteos = [total[s] for s in sorteos]
    print("Sorteos evaluados: %d (%d-%d)" % (n, sorteos[0], sorteos[-1]))
    print("Cantidad de numeros publicados: min %d, mediana %d, max %d"
          % (min(conteos), mediana(conteos), max(conteos)))
    top = Counter(conteos).most_common(6)
    print("Cantidades mas frecuentes: %s"
          % ", ".join("%d numeros (%d sorteos)" % (c, k) for c, k in top))

    # Mediana movil DENTRO de cada tipo de sorteo => esperada de la epoca.
    esperados = {}
    por_tipo = defaultdict(list)
    for s in sorteos:
        por_tipo[tipos.get(s, "?")].append(s)
    # Los de tipo desconocido se evaluan junto al tipo cuya banda les quede
    # mas cerca (ordinario por defecto).
    for s in por_tipo.pop("?", []):
        destino = min(("ORDINARIO", "EXTRAORDINARIO"),
                      key=lambda t: abs(total[s] - mediana([total[x] for x in por_tipo[t]])) if por_tipo.get(t) else 1e9)
        por_tipo[destino].append(s)
    for t in por_tipo:
        por_tipo[t].sort()
        lista = por_tipo[t]
        for i, s in enumerate(lista):
            ini = max(0, i - VENTANA)
            fin = min(len(lista), i + VENTANA + 1)
            esperados[s] = mediana([total[x] for x in lista[ini:fin]])

    print()
    print("Cantidad esperada por tipo y epoca (cambios de la mediana movil):")
    for t in sorted(por_tipo):
        ult = None
        for s in por_tipo[t]:
            e = round(esperados[s])
            if ult is None or abs(e - ult) > TOLERANCIA:
                print("  %-15s desde el sorteo %d: ~%d numeros" % (t, s, e))
                ult = e

    # Desviaciones.
    desv = []
    for s in sorteos:
        dif = total[s] - esperados[s]
        if abs(dif) > TOLERANCIA:
            dup = total[s] - distintos[s]
            causa = []
            if dif < 0:
                causa.append("faltan numeros (extraccion incompleta o pagina perdida)")
            else:
                if dup > TOLERANCIA:
                    causa.append("%d duplicados" % dup)
                causa.append("numeros de mas (ruido u hoja doble)")
            desv.append({"sorteo": s, "tipo": tipos.get(s, "?"),
                         "publicados": total[s],
                         "distintos": distintos[s],
                         "esperados": round(esperados[s]),
                         "desviacion": round(dif),
                         "causa_probable": "; ".join(causa)})

    desv.sort(key=lambda d: -abs(d["desviacion"]))
    print()
    print("Sorteos fuera de tolerancia (+-%d): %d de %d (%.1f%%)"
          % (TOLERANCIA, len(desv), n, 100.0 * len(desv) / n))
    for d in desv[:20]:
        print("  sorteo %d (%s): %d publicados (esperados ~%d, %+d) - %s"
              % (d["sorteo"], d["tipo"], d["publicados"], d["esperados"],
                 d["desviacion"], d["causa_probable"]))

    # Duplicados globales (mismo numero repetido dentro de un sorteo).
    con_dup = [(s, total[s] - distintos[s]) for s in sorteos
               if total[s] - distintos[s] > 0]
    print()
    print("Sorteos con numeros repetidos dentro de la lista: %d "
          "(total de repeticiones: %d)"
          % (len(con_dup), sum(d for _, d in con_dup)))

    with open(SAL_REP, "w", encoding="ascii") as fh:
        json.dump({
            "sorteos": n,
            "min": min(conteos), "mediana": mediana(conteos), "max": max(conteos),
            "cantidades_frecuentes": top,
            "tolerancia": TOLERANCIA,
            "fuera_de_tolerancia": desv,
            "sorteos_con_duplicados": len(con_dup),
        }, fh, indent=1)
    print()
    print("Reporte:", SAL_REP)

    if actualiza:
        with open(SAL_ESP, "w", newline="", encoding="ascii") as fh:
            w = csv.writer(fh, delimiter="|")
            w.writerow(["sorteo", "publicados", "distintos", "esperados"])
            for s in sorteos:
                w.writerow([s, total[s], distintos[s], round(esperados[s])])
        print("Esperados:", SAL_ESP)


if __name__ == "__main__":
    main()
