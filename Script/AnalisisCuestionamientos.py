"""AnalisisCuestionamientos.py - Los tres cuestionamientos publicos contra la
Loteria Nacional, evaluados contra los datos de 24 anios:

C1. "Efecto acumulacion": el mismo numero gana varios premios en el MISMO
    sorteo (la tombola no es excluyente). Se cuenta cuantas veces ocurre y
    cuantas PREDICE el azar: con k extracciones independientes sobre una
    emision E, los pares repetidos esperados son C(k,2)/E (Poisson).
C2. Premios "no vendidos": censo de los marcadores que la propia Loteria
    publica (VENDIDO POR / NO VENDIDO / POR ACUMULACION) en los PDFs y en
    las paginas HTML de 2002-05 -> tasa de mayores no vendidos por era.
    Bajo un sorteo justo esa tasa estima la fraccion NO vendida de la
    emision, que es tambien la fraccion esperada RETENIDA de cualquier
    premio secundario sorteado independientemente.
C3. Terminaciones: sequias maximas por digito (contra Monte Carlo), la
    misma terminacion en sorteos consecutivos (1, 2 y 4 digitos) y el
    sesgo de calibracion (chi2 del ultimo digito y ultimos dos).

Salida: Resultados/CuestionamientosReporte.json + Resultados/VendidoMayor.csv
"""
import csv
import json
import math
import os
import random
import re
import subprocess
import sys
from collections import Counter, defaultdict

RAIZ = r"D:\PRC Loteria Nacional"
PDFTOTEXT = r"C:\Program Files\Git\mingw64\bin\pdftotext.exe"
SAL = os.path.join(RAIZ, "Resultados", "CuestionamientosReporte.json")
VENDIDO_CSV = os.path.join(RAIZ, "Resultados", "VendidoMayor.csv")
NOTAS = os.path.join(RAIZ, "Resultados", "NotasMayor.csv")
MAYORES_VIEJOS = os.path.join(RAIZ, "Resultados", "MayoresHtmlViejo.csv")
HTML_DIR = os.path.join(RAIZ, "Datos", "HtmlViejo")

sys.path.insert(0, os.path.join(RAIZ, "Script"))
from AnalisisRepetidos import carga, gammln, poisson_sf  # noqa: E402

VIEJOS_EXCLUIR = {1224, 1232}    # paginas con dos sorteos mezclados
UMBRAL = 30000.0
UMBRAL_VIEJO = 10000.0
ORDEN = {"MAYOR", "SEGUNDO", "TERCER", "CUARTO", "QUINTO", "SEXTO", "Destacado"}


# ---------- helpers estadisticos (mismos de AnalisisEquidad) ----------

def gser(a, x):
    ap = a
    summ = 1.0 / a
    delta = summ
    for _ in range(500):
        ap += 1.0
        delta *= x / ap
        summ += delta
        if abs(delta) < abs(summ) * 1e-14:
            break
    return summ * math.exp(-x + a * math.log(x) - gammln(a))


def gcf(a, x):
    b = x + 1.0 - a
    c = 1e300
    d = 1.0 / b
    h = d
    for i in range(1, 500):
        an = -i * (i - a)
        b += 2.0
        d = an * d + b
        if abs(d) < 1e-300:
            d = 1e-300
        c = b + an / c
        if abs(c) < 1e-300:
            c = 1e-300
        d = 1.0 / d
        delta = d * c
        h *= delta
        if abs(delta - 1.0) < 1e-14:
            break
    return math.exp(-x + a * math.log(x) - gammln(a)) * h


def chi2_pvalue(chi2, df):
    a, x = df / 2.0, chi2 / 2.0
    if x <= 0:
        return 1.0
    if x < a + 1.0:
        return 1.0 - gser(a, x)
    return gcf(a, x)


# ---------- C1: mismo numero, varios premios, MISMO sorteo ----------

def cuestion_1(filas):
    global_obs = global_exp = 0.0
    por_era = {"viejo": [0, 0.0, 0], "moderno": [0, 0.0, 0]}
    anomalos = []
    casos_dest = []
    concentracion = []
    mayor_extra = []
    exp_mayor_extra = 0.0
    for s in sorted(filas):
        if s in VIEJOS_EXCLUIR:
            continue
        # doble listado del mismo premio etiquetado (banner + cuadricula
        # con tipo/monto identicos) NO es un segundo premio: se deduplica.
        vistos = set()
        rows = []
        for tipo, numero, monto in filas[s]:
            if tipo in ORDEN:
                clave = (tipo, numero, monto)
                if clave in vistos:
                    continue
                vistos.add(clave)
            rows.append((tipo, numero, monto))
        k = len(rows)
        maxn = max(int(r[1]) for r in rows)
        emision = int(math.ceil((maxn + 1) / 1000.0) * 1000)
        cnt = Counter(r[1] for r in rows)
        obs = sum(n * (n - 1) // 2 for n in cnt.values())
        exp = k * (k - 1) / 2.0 / emision
        # capa de texto duplicada u otra falla de extraccion: obs >> exp
        if obs > max(15, 4 * exp):
            anomalos.append({"sorteo": s, "obs": obs, "exp": round(exp, 1)})
            continue
        era = "viejo" if s < 1356 else "moderno"
        por_era[era][0] += obs
        por_era[era][1] += exp
        por_era[era][2] += 1
        global_obs += obs
        global_exp += exp

        # premios DESTACADOS repetidos en el mismo sorteo (el reclamo duro)
        umbral = UMBRAL_VIEJO if s < 1356 else UMBRAL
        dest = defaultdict(list)
        for tipo, numero, monto in rows:
            if (tipo in ORDEN) or (monto is not None and monto >= umbral):
                dest[numero].append((tipo, monto))
        for numero, premios in dest.items():
            if len(premios) > 1:
                casos_dest.append({
                    "sorteo": s, "numero": numero,
                    "premios": [{"tipo": t, "monto": m} for t, m in premios]})
        # concentracion de plata: total ganado por numeros repetidos
        for numero, n in cnt.items():
            if n > 1:
                total = sum(m for t, x, m in rows
                            if x == numero and m is not None)
                concentracion.append((total, s, numero, n))
        # el numero del MAYOR ademas premiado en la cuadricula
        mayores_s = {x for t, x, m in rows if t == "MAYOR"}
        for numero in mayores_s:
            extras = [(t, m) for t, x, m in rows
                      if x == numero and t not in ORDEN]
            if extras:
                mayor_extra.append({"sorteo": s, "numero": numero,
                                    "extras": extras})
        if mayores_s:
            exp_mayor_extra += float(k - 1) / emision

    concentracion.sort(reverse=True)
    p_global = poisson_sf(int(round(global_obs)), global_exp)
    p_moderno = poisson_sf(por_era["moderno"][0], por_era["moderno"][1])
    p_mayor_extra = poisson_sf(len(mayor_extra), exp_mayor_extra)
    # destacados esperados
    exp_dest = 0.0
    for s in sorted(filas):
        if s in VIEJOS_EXCLUIR or any(a["sorteo"] == s for a in anomalos):
            continue
        rows = filas[s]
        maxn = max(int(r[1]) for r in rows)
        emision = int(math.ceil((maxn + 1) / 1000.0) * 1000)
        umbral = UMBRAL_VIEJO if s < 1356 else UMBRAL
        f = len({r[1] for r in rows
                 if (r[0] in ORDEN) or (r[2] is not None and r[2] >= umbral)})
        exp_dest += f * (f - 1) / 2.0 / emision
    p_dest = poisson_sf(len(casos_dest), exp_dest)

    print("C1. Mismo numero premiado 2+ veces en el MISMO sorteo")
    print("  pares repetidos: observados %d | esperados por azar %.1f | p=%.3f"
          % (global_obs, global_exp, p_global))
    for era, (o, e, n) in por_era.items():
        print("    era %s (%d sorteos): obs %d vs esp %.1f" % (era, n, o, e))
    print("  era moderna sola: p=%.3f" % p_moderno)
    print("  entre premios DESTACADOS (deduplicado): obs %d vs esp %.2f | p=%.3f"
          % (len(casos_dest), exp_dest, p_dest))
    print("  el MAYOR ademas premiado en cuadricula: obs %d vs esp %.1f | p=%.3f"
          % (len(mayor_extra), exp_mayor_extra, p_mayor_extra))
    for c in mayor_extra:
        print("    sorteo %d: %s + %s" % (c["sorteo"], c["numero"], c["extras"]))
    print("  sorteos con extraccion anomala excluidos: %d" % len(anomalos))
    return {
        "pares_obs": int(global_obs), "pares_esp": round(global_exp, 1),
        "p_value": round(p_global, 4),
        "por_era": {k: {"obs": v[0], "esp": round(v[1], 1), "sorteos": v[2]}
                    for k, v in por_era.items()},
        "p_moderno": round(p_moderno, 4),
        "destacados_obs": len(casos_dest), "destacados_esp": round(exp_dest, 2),
        "destacados_p": round(p_dest, 4), "casos_destacados": casos_dest,
        "mayor_extra_obs": len(mayor_extra),
        "mayor_extra_esp": round(exp_mayor_extra, 1),
        "mayor_extra_p": round(p_mayor_extra, 4),
        "casos_mayor_extra": mayor_extra,
        "top_concentracion": [
            {"sorteo": s, "numero": nu, "veces": n, "total": t}
            for t, s, nu, n in concentracion[:10]],
        "anomalos_excluidos": anomalos,
    }


# ---------- C2: censo VENDIDO / NO VENDIDO / ACUMULACION ----------

RE_NO = re.compile(r"NO\s*(?:FUE\s*)?VENDIDO", re.I)
RE_SI = re.compile(r"VENDIDO\s*POR", re.I)
RE_ACUM = re.compile(r"POR\s*ACUMULACION", re.I)
RE_ACUM_REF = re.compile(
    r"POR\s*ACUMULACION\s*EL\s*SORTEO\s*(?:N[oO]?\.?\s*)?(\d{4})", re.I)


def clasifica_acum(t, s):
    """1 = banner valido (refiere al sorteo s+1), -1 = banner ranio
    (plantilla vieja, refiere a otro sorteo), 0 = sin banner."""
    if not RE_ACUM.search(t):
        return 0
    refs = [int(m) for m in RE_ACUM_REF.findall(t)]
    if (s + 1) in refs:
        return 1
    return -1 if refs else 1     # sin numero legible: se acepta


def texto_pdf(ruta):
    try:
        r = subprocess.run([PDFTOTEXT, "-raw", ruta, "-"],
                           stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                           timeout=90)
        return r.stdout.decode("utf-8", errors="replace")
    except Exception:
        return ""


def censo_vendido():
    cache = {}
    if os.path.exists(VENDIDO_CSV):
        with open(VENDIDO_CSV, encoding="ascii") as fh:
            for f in csv.reader(fh, delimiter="|"):
                if f and f[0].isdigit() and len(f) >= 4:
                    cache[int(f[0])] = (f[1], f[2], int(f[3]))
    nuevos = []

    # PDFs modernos
    pdfs = sorted(int(m.group(1)) for n in os.listdir(os.path.join(RAIZ, "Datos"))
                  for m in [re.match(r"^(\d{4})\.pdf$", n)] if m)
    for i, s in enumerate(pdfs, 1):
        if s in cache:
            continue
        t = texto_pdf(os.path.join(RAIZ, "Datos", "%d.pdf" % s))
        if len(t.strip()) < 100:
            marca = "escaneado"
        elif RE_NO.search(t):
            marca = "no_vendido"
        elif RE_SI.search(t):
            marca = "vendido"
        else:
            marca = "sin_marcador"
        fila = (s, "pdf", marca, clasifica_acum(t, s))
        cache[s] = fila[1:]
        nuevos.append(fila)
        if i % 100 == 0:
            print("  ... censo PDF %d/%d" % (i, len(pdfs)), flush=True)

    # HTML viejo
    if os.path.isdir(HTML_DIR):
        for nombre in sorted(os.listdir(HTML_DIR)):
            m = re.match(r"^(\d{4})\.html$", nombre)
            if not m:
                continue
            s = int(m.group(1))
            if s in cache or s == 1145:      # 1145 contiene el 1144
                continue
            t = open(os.path.join(HTML_DIR, nombre), encoding="latin-1").read()
            t = re.sub(r"<[^>]+>", " ", t)
            if RE_NO.search(t):
                marca = "no_vendido"
            elif RE_SI.search(t):
                marca = "vendido"
            else:
                marca = "sin_marcador"
            fila = (s, "html", marca, clasifica_acum(t, s))
            cache[s] = fila[1:]
            nuevos.append(fila)

    if nuevos or not os.path.exists(VENDIDO_CSV):
        with open(VENDIDO_CSV, "w", newline="", encoding="ascii") as fh:
            w = csv.writer(fh, delimiter="|")
            w.writerow(["sorteo", "fuente", "marcador", "acumulacion"])
            for s in sorted(cache):
                w.writerow([s, cache[s][0], cache[s][1], cache[s][2]])

    eras = defaultdict(Counter)
    no_vendidos = []
    acumulados = []
    banners_ranios = 0
    for s, (fuente, marca, acum) in sorted(cache.items()):
        era = "2002-05" if s < 1356 else ("2006-12" if s < 1800 else "2013-26")
        eras[era][marca] += 1
        if marca == "no_vendido":
            no_vendidos.append(s)
        if acum == 1:
            acumulados.append(s)
        elif acum == -1:
            banners_ranios += 1

    print()
    print("C2. Censo de marcadores VENDIDO / NO VENDIDO / ACUMULACION")
    resumen = {}
    for era in sorted(eras):
        c = eras[era]
        con = c["vendido"] + c["no_vendido"]
        tasa = (100.0 * c["no_vendido"] / con) if con else None
        print("  era %s: vendido %d | NO vendido %d | sin marcador %d | "
              "escaneado %d | tasa no-vendido %s"
              % (era, c["vendido"], c["no_vendido"], c["sin_marcador"],
                 c["escaneado"], ("%.1f%%" % tasa) if tasa is not None else "n/d"))
        resumen[era] = {"vendido": c["vendido"], "no_vendido": c["no_vendido"],
                        "sin_marcador": c["sin_marcador"],
                        "escaneado": c["escaneado"],
                        "tasa_no_vendido": round(tasa, 2) if tasa is not None else None}
    print("  mayores NO vendidos (%d): %s" % (len(no_vendidos), no_vendidos))
    print("  banners POR ACUMULACION validos (refieren al sorteo siguiente): "
          "%d | ranios de plantilla: %d" % (len(acumulados), banners_ranios))
    print("  sorteos con banner valido: %s" % acumulados)
    return {"por_era": resumen, "no_vendidos": no_vendidos,
            "con_banner_acumulacion": acumulados,
            "banners_ranios": banners_ranios}


# ---------- C3: terminaciones - sequias, rachas y calibracion ----------

def carga_mayores():
    term = {}
    with open(NOTAS, encoding="ascii") as fh:
        for f in csv.reader(fh, delimiter="|"):
            if f and f[0].isdigit():
                term[int(f[0])] = f[1].zfill(4)
    with open(MAYORES_VIEJOS, encoding="ascii") as fh:
        for f in csv.reader(fh, delimiter="|"):
            if f and f[0].isdigit() and int(f[0]) not in VIEJOS_EXCLUIR:
                term.setdefault(int(f[0]), f[1][-4:].zfill(4))
    return term


def cuestion_3():
    term = carga_mayores()
    sorteos = sorted(term)
    seq1 = [int(term[s][-1]) for s in sorteos]
    seq2 = [term[s][-2:] for s in sorteos]
    n = len(sorteos)

    # calibracion: chi2 ultimo digito y ultimos dos
    c1 = Counter(seq1)
    chi_1 = sum((c1.get(d, 0) - n / 10.0) ** 2 / (n / 10.0) for d in range(10))
    p1 = chi2_pvalue(chi_1, 9)
    c2 = Counter(seq2)
    chi_2 = sum((c2.get("%02d" % d, 0) - n / 100.0) ** 2 / (n / 100.0)
                for d in range(100))
    p2 = chi2_pvalue(chi_2, 99)

    # sequias: maxima racha de sorteos observados sin cada ultimo digito
    seq_max = {}
    for d in range(10):
        racha = mejor = 0
        for v in seq1:
            racha = 0 if v == d else racha + 1
            mejor = max(mejor, racha)
        seq_max[d] = mejor
    obs_max = max(seq_max.values())

    random.seed(20260722)
    sims = []
    for _ in range(3000):
        r = [random.randrange(10) for _ in range(n)]
        peor = 0
        rachas = [0] * 10
        for v in r:
            for d in range(10):
                rachas[d] = 0 if v == d else rachas[d] + 1
                if rachas[d] > peor:
                    peor = rachas[d]
        sims.append(peor)
    sims.sort()
    p_seq = sum(1 for x in sims if x >= obs_max) / float(len(sims))
    mediana_mc = sims[len(sims) // 2]
    p95_mc = sims[int(len(sims) * 0.95)]

    # repeticiones consecutivas (solo sorteos adyacentes de verdad)
    pares = [(i, i + 1) for i in range(n - 1)
             if sorteos[i + 1] - sorteos[i] <= 3]
    rep1 = sum(1 for i, j in pares if seq1[i] == seq1[j])
    rep2 = sum(1 for i, j in pares if seq2[i] == seq2[j])
    rep4 = sum(1 for i, j in pares if term[sorteos[i]] == term[sorteos[j]])
    npar = len(pares)
    frec = Counter(seq1)
    p_emp = sum((v / float(n)) ** 2 for v in frec.values())
    exp1_emp = npar * p_emp
    p_rep1 = poisson_sf(rep1, exp1_emp)
    p_rep2 = poisson_sf(rep2, npar / 100.0)
    p_rep4 = poisson_sf(rep4, npar / 10000.0)

    print()
    print("C3. Terminaciones del premio mayor (%d sorteos)" % n)
    print("  calibracion: ultimo digito chi2=%.1f p=%.4f | "
          "ultimos DOS chi2=%.1f p=%.4f" % (chi_1, p1, chi_2, p2))
    print("  frecuencias ultimo digito: %s"
          % {d: c1.get(d, 0) for d in range(10)})
    print("  sequia maxima observada: %d sorteos sin el digito %s "
          "(azar: mediana %d, p95 %d, p=%.3f)"
          % (obs_max, max(seq_max, key=seq_max.get), mediana_mc, p95_mc, p_seq))
    print("  sequias por digito: %s" % seq_max)
    print("  consecutivos (%d pares adyacentes): mismo ultimo digito %d "
          "(esp %.1f, p=%.3f) | mismos DOS %d (esp %.1f, p=%.3f) | "
          "terminacion COMPLETA %d (esp %.2f, p=%.4f)"
          % (npar, rep1, exp1_emp, p_rep1, rep2, npar / 100.0, p_rep2,
             rep4, npar / 10000.0, p_rep4))
    return {
        "sorteos": n,
        "chi2_ultimo": round(chi_1, 1), "p_ultimo": round(p1, 5),
        "chi2_ultimos2": round(chi_2, 1), "p_ultimos2": round(p2, 5),
        "frecuencias_ultimo": {str(d): c1.get(d, 0) for d in range(10)},
        "sequia_max": obs_max, "sequia_digito": max(seq_max, key=seq_max.get),
        "sequias": {str(d): seq_max[d] for d in range(10)},
        "sequia_mc_mediana": mediana_mc, "sequia_mc_p95": p95_mc,
        "sequia_p": round(p_seq, 4),
        "pares_adyacentes": npar,
        "rep_ultimo": rep1, "rep_ultimo_esp": round(exp1_emp, 1),
        "rep_ultimo_p": round(p_rep1, 4),
        "rep_dos": rep2, "rep_dos_esp": round(npar / 100.0, 1),
        "rep_dos_p": round(p_rep2, 4),
        "rep_completa": rep4, "rep_completa_esp": round(npar / 10000.0, 3),
        "rep_completa_p": round(p_rep4, 4),
    }


def main():
    filas = carga()
    r1 = cuestion_1(filas)
    r2 = censo_vendido()
    r3 = cuestion_3()
    with open(SAL, "w", encoding="ascii") as fh:
        json.dump({"c1_mismo_sorteo": r1, "c2_no_vendidos": r2,
                   "c3_terminaciones": r3}, fh, indent=1)
    print()
    print("Reporte:", SAL)


if __name__ == "__main__":
    main()
