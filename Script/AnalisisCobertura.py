"""AnalisisCobertura.py - La estrategia de compra masiva (Selbee / MIT):
que fraccion de la emision habria que comprar para ganar mas de lo invertido.

Matematica: comprar TODA la emision cuesta E x precio y devuelve TODOS los
premios: la lista oficial + la masa de terminaciones. Las terminaciones pagan
2x/4x/8x/16x el precio (verificado en las notas) => masa fija ~22.5% de las
ventas. Entonces el retorno de cubrir todo es el payout ratio:
    R = premios_lista / (E x precio) + 0.225
- R > 1: cubrir el 100% GARANTIZA ganancia (R-1). Es el unico caso rentable.
- R < 1: ninguna cobertura parcial garantiza nada (el mayor puede caer fuera)
  y el retorno ESPERADO de cualquier fraccion es R x inversion (perdedor).
El precio del billete por sorteo se infiere de la nota: "EN d GANAN C$X" con
X = 2 x precio.

Salida: Resultados/CoberturaReporte.json
"""
import csv
import json
import math
import os
import re
import subprocess
import tempfile
import urllib.request
from collections import defaultdict

RAIZ = r"D:\PRC Loteria Nacional"
PDFTOTEXT = r"C:\Program Files\Git\mingw64\bin\pdftotext.exe"
SEMILLAS = ["192.168.1.190", "192.168.1.124", "192.168.1.69", "192.168.1.250"]
SAL = os.path.join(RAIZ, "Resultados", "CoberturaReporte.json")
PRECIOS = os.path.join(RAIZ, "Resultados", "PreciosBillete.csv")
MASA_TERMINACIONES = 0.225

NOTA_PRECIO = re.compile(r"EN\s+\d\s+GANAN\s+C?\$?\s*([\d,]+)", re.I)


def consulta(sql):
    for ip in SEMILLAS:
        try:
            with urllib.request.urlopen(
                    "http://%s:4001/status" % ip, timeout=5) as r:
                lider = json.load(r)["store"]["leader"]["addr"].split(":")[0]
            if not lider:
                continue
            u = ("http://%s:4001/db/query?level=none&q=%s"
                 % (lider, urllib.parse.quote(sql)))
            with urllib.request.urlopen(u, timeout=60) as r:
                j = json.load(r)
            return j["results"][0].get("values", [])
        except Exception:
            continue
    raise RuntimeError("cluster inaccesible")


def precios_por_sorteo(sorteos):
    """Precio del billete inferido de la nota (ultimo digito paga 2x precio)."""
    if os.path.exists(PRECIOS):
        precios = {}
        with open(PRECIOS, encoding="ascii") as fh:
            for f in csv.reader(fh, delimiter="|"):
                if f and f[0].isdigit():
                    precios[int(f[0])] = float(f[1])
        return precios
    precios = {}
    for i, s in enumerate(sorteos, 1):
        ruta = os.path.join(RAIZ, "Datos", "%d.pdf" % s)
        if not os.path.exists(ruta) or os.path.getsize(ruta) == 0:
            continue
        tmp = tempfile.mktemp(suffix=".txt")
        try:
            subprocess.run([PDFTOTEXT, "-raw", ruta, tmp],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                           timeout=60)
            texto = open(tmp, encoding="utf-8", errors="replace").read()
        except Exception:
            continue
        finally:
            if os.path.exists(tmp):
                os.remove(tmp)
        ms = NOTA_PRECIO.findall(texto)
        if ms:
            t1 = min(float(m.replace(",", "")) for m in ms)
            if 100 <= t1 <= 5000:
                precios[s] = t1 / 2.0
        if i % 150 == 0:
            print("... precios %d/%d" % (i, len(sorteos)), flush=True)
    with open(PRECIOS, "w", newline="", encoding="ascii") as fh:
        w = csv.writer(fh, delimiter="|")
        w.writerow(["sorteo", "precio"])
        for s in sorted(precios):
            w.writerow([s, "%.0f" % precios[s]])
    return precios


def main():
    filas = consulta(
        "SELECT num_sorteo, SUM(monto), COUNT(*), MAX(numero) FROM premio "
        "WHERE metodo IN ('py-coord','html-viejo') AND monto IS NOT NULL "
        "GROUP BY num_sorteo")
    print("Sorteos con premios en BD: %d" % len(filas))
    sorteos = sorted(int(f[0]) for f in filas)
    datos = {int(f[0]): (float(f[1]), int(f[2]), int(f[3])) for f in filas}

    precios = precios_por_sorteo(sorteos)
    print("Precios inferidos de la nota: %d sorteos" % len(precios))

    resultados = []
    for s in sorteos:
        suma, n, maxnum = datos[s]
        precio = precios.get(s)
        if not precio:
            continue
        emision = int(math.ceil((int(maxnum) + 1) / 1000.0) * 1000)
        costo = emision * precio
        r_lista = suma / costo
        r_total = r_lista + MASA_TERMINACIONES
        resultados.append({
            "sorteo": s, "emision": emision, "precio": precio,
            "premios_lista": round(suma),
            "costo_cubrir_todo": round(costo),
            "ratio_lista": round(r_lista, 4),
            "ratio_total": round(r_total, 4),
        })

    resultados.sort(key=lambda x: -x["ratio_total"])
    rt = [x["ratio_total"] for x in resultados]
    rt_ord = sorted(rt)
    n = len(rt)
    print()
    print("Payout ratio (retorno de cubrir el 100%% de la emision), %d sorteos:" % n)
    print("  minimo %.1f%% | mediana %.1f%% | maximo %.1f%%"
          % (rt_ord[0] * 100, rt_ord[n // 2] * 100, rt_ord[-1] * 100))
    print("  sorteos con ratio > 100%% (estrategia rentable): %d"
          % sum(1 for x in rt if x > 1.0))
    print("  sorteos con ratio > 80%%: %d" % sum(1 for x in rt if x > 0.8))
    print()
    print("Top 10 sorteos por retorno de cobertura total:")
    for x in resultados[:10]:
        print("  sorteo %d: ratio %.1f%% (lista %.1f%% + term. 22.5%%) | "
              "cubrir todo: C$%s -> premios C$%s"
              % (x["sorteo"], x["ratio_total"] * 100, x["ratio_lista"] * 100,
                 format(x["costo_cubrir_todo"], ","),
                 format(round(x["premios_lista"] + 0.225 * x["costo_cubrir_todo"]), ",")))

    with open(SAL, "w", encoding="ascii") as fh:
        json.dump({"sorteos": n,
                   "ratio_min": rt_ord[0], "ratio_mediana": rt_ord[n // 2],
                   "ratio_max": rt_ord[-1],
                   "rentables": sum(1 for x in rt if x > 1.0),
                   "top": resultados[:15],
                   "masa_terminaciones": MASA_TERMINACIONES}, fh, indent=1)
    print()
    print("Reporte:", SAL)


if __name__ == "__main__":
    main()
