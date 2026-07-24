"""AnalisisEquidad.py - Fase 5: bateria estadistica de equidad de los sorteos.

Metodologia: el premio MAYOR de cada sorteo es un numero extraido directamente
de las tombolas, libre de la estructura del plan de premios (aproximaciones y
terminaciones que contaminan la cuadricula). Sobre esa serie se aplica la
bateria de tests, condicionando a la emision inferida de cada sorteo (el
espacio real de billetes no es 00000-99999).

Los p-values se corrigen por comparaciones multiples (Benjamini-Hochberg).

Salida: Resultados\Equidad_20260720.json y reporte por consola.
Python 3.7 stdlib.
"""
import csv
import json
import math
import os

RAIZ = r"D:\PRC Loteria Nacional"
FICHERO = os.path.join(RAIZ, "Resultados", "ExtraccionV2.csv")
RELLENOS = os.path.join(RAIZ, "Resultados", "Conciliacion_Rellenos_20260720.csv")
SALIDA = os.path.join(RAIZ, "Resultados", "Equidad_20260720.json")

ALFA = 0.05


# ---------- utilidades estadisticas (Numerical Recipes) ----------
def gammln(x):
    cof = [76.18009172947146, -86.50532032941677, 24.01409824083091,
           -1.231739572450155, 0.1208650973866179e-2, -0.5395239384953e-5]
    y = x
    tmp = x + 5.5
    tmp -= (x + 0.5) * math.log(tmp)
    ser = 1.000000000190015
    for c in cof:
        y += 1.0
        ser += c / y
    return -tmp + math.log(2.5066282746310005 * ser / x)


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
    """P(X >= chi2) para chi-cuadrado con df grados de libertad."""
    a, x = df / 2.0, chi2 / 2.0
    if x <= 0:
        return 1.0
    if x < a + 1.0:
        return 1.0 - gser(a, x)
    return gcf(a, x)


def ks_pvalue(d, n):
    """P-value asintotico de Kolmogorov-Smirnov."""
    lam = (math.sqrt(n) + 0.12 + 0.11 / math.sqrt(n)) * d
    s = 0.0
    for k in range(1, 101):
        term = 2.0 * (-1) ** (k - 1) * math.exp(-2.0 * k * k * lam * lam)
        s += term
        if abs(term) < 1e-12:
            break
    return max(0.0, min(1.0, s))


def normal_pvalue_2colas(z):
    return math.erfc(abs(z) / math.sqrt(2.0))


def poisson_pvalue_2colas(obs, mu):
    """P-value bilateral aproximado para conteo observado vs Poisson(mu)."""
    def cdf(k):
        s = 0.0
        for i in range(0, k + 1):
            s += math.exp(-mu + i * math.log(mu) - gammln(i + 1))
        return s
    if obs <= mu:
        p = cdf(obs)
    else:
        p = 1.0 - cdf(obs - 1)
    return min(1.0, 2.0 * p)


# ---------- carga de datos ----------
NOTAS = os.path.join(RAIZ, "Resultados", "NotasMayor.csv")

# El mayor se identifica en dos vias:
#  A) NOTA al pie ("TERMINADOS EN 0595 GANAN"): ultimos 4 digitos del mayor,
#     canal de texto plano independiente del emparejado. Sirve para todos los
#     tests de digitos.
#  B) Numero completo: la fila del sorteo cuyo numero termina en la nota y
#     tiene el mayor monto entre las candidatas. Sirve para KS, rachas,
#     autocorrelacion y colisiones.
# (El max-monto a secas resulto contaminado: en la era moderna el monto del
#  mayor es arte grafico y el maximo textual es el SEGUNDO premio.)
UMBRAL_MAYOR = 500000.0


VIEJOS = os.path.join(RAIZ, "Resultados", "MayoresHtmlViejo.csv")
VIEJOS_EXCLUIR = {1224, 1232}    # senales en conflicto: fuera de la bateria


def carga_notas():
    """sorteo -> ultimos 4 digitos del mayor (NOTA del PDF o header HTML viejo)."""
    notas = {}
    if os.path.exists(VIEJOS):
        with open(VIEJOS, encoding='ascii', errors='replace') as fh:
            for f in csv.reader(fh, delimiter='|'):
                if (len(f) >= 2 and f[0].isdigit() and len(f[1]) == 5
                        and int(f[0]) not in VIEJOS_EXCLUIR):
                    notas[int(f[0])] = f[1][1:]
    if os.path.exists(NOTAS):
        with open(NOTAS, encoding='ascii', errors='replace') as fh:
            for f in csv.reader(fh, delimiter='|'):
                if len(f) >= 2 and f[0].isdigit() and len(f[1]) == 4 and f[1].isdigit():
                    notas[int(f[0])] = f[1]
    return notas


def carga_mayores_viejos():
    """(sorteo, numero_completo) y emision de la era HTML 2002-2005."""
    mayores, emision = [], {}
    if os.path.exists(VIEJOS):
        with open(VIEJOS, encoding='ascii', errors='replace') as fh:
            for f in csv.reader(fh, delimiter='|'):
                if (len(f) >= 4 and f[0].isdigit() and len(f[1]) == 5
                        and int(f[0]) not in VIEJOS_EXCLUIR):
                    mayores.append((int(f[0]), f[1]))
                    emision[int(f[0])] = int(f[3])
    return mayores, emision


def carga_mayores_completos(notas):
    """(sorteo, numero_completo) donde la nota identifica sin ambiguedad."""
    candidatos = {}
    max_num = {}
    with open(FICHERO, encoding='ascii', errors='replace') as fh:
        for f in csv.reader(fh, delimiter='|'):
            if not f or not f[0].isdigit():
                continue
            s = int(f[0])
            num = f[2]
            if not (num.isdigit() and len(num) == 5):
                continue
            if s not in max_num or int(num) > max_num[s]:
                max_num[s] = int(num)
            if s in notas and num.endswith(notas[s]):
                monto = float(f[3]) if f[3] else 0.0
                if s not in candidatos or monto > candidatos[s][0]:
                    candidatos[s] = (monto, num)
    emision = {}
    for s in max_num:
        emision[s] = int(math.ceil((max_num[s] + 1) / 1000.0) * 1000)
    mayores = [(s, candidatos[s][1]) for s in sorted(candidatos)]
    return mayores, emision


def carga_mayores():
    """Devuelve (mayores ordenados por sorteo, emision por sorteo, excluidos)."""
    max_num = {}
    filas = {}          # sorteo -> (monto, numero)
    with open(FICHERO, encoding='ascii', errors='replace') as fh:
        for f in csv.reader(fh, delimiter='|'):
            if not f or not f[0].isdigit():
                continue
            s = int(f[0])
            num = f[2]
            if num.isdigit() and len(num) == 5:
                if s not in max_num or int(num) > max_num[s]:
                    max_num[s] = int(num)
            monto = float(f[3]) if f[3] else 0.0
            if s not in filas or monto > filas[s][0]:
                filas[s] = (monto, num)
    # Rellenos de conciliacion (montos graficos: ahi suele estar el MAYOR).
    if os.path.exists(RELLENOS):
        with open(RELLENOS, encoding='ascii', errors='replace') as fh:
            for f in csv.reader(fh, delimiter='|'):
                if len(f) >= 4 and f[0].isdigit():
                    s = int(f[0])
                    monto = float(f[2])
                    if s in filas and monto > filas[s][0]:
                        filas[s] = (monto, f[1])
    mayores = []
    emision = {}
    excluidos = 0
    for s in sorted(filas):
        # Emision inferida: el numero mas alto premiado, redondeado al millar.
        emision[s] = int(math.ceil((max_num[s] + 1) / 1000.0) * 1000)
        if filas[s][0] >= UMBRAL_MAYOR:
            mayores.append((s, filas[s][1]))
        else:
            excluidos += 1
    return mayores, emision, excluidos


# ---------- tests ----------
def test_chi2_digito(mayores, pos, nombre):
    cnt = [0] * 10
    for _, num in mayores:
        cnt[int(num[pos])] += 1
    n = len(mayores)
    esperado = n / 10.0
    chi2 = sum((c - esperado) ** 2 / esperado for c in cnt)
    return {'test': nombre, 'estadistico': round(chi2, 2), 'df': 9,
            'p': chi2_pvalue(chi2, 9), 'detalle': cnt}


def test_chi2_ultimos2(mayores):
    cnt = [0] * 100
    for _, num in mayores:
        cnt[int(num[3:])] += 1
    n = len(mayores)
    esperado = n / 100.0
    chi2 = sum((c - esperado) ** 2 / esperado for c in cnt)
    return {'test': 'chi2 ultimos dos digitos (00-99)', 'estadistico': round(chi2, 2),
            'df': 99, 'p': chi2_pvalue(chi2, 99)}


def test_ks_uniforme(mayores, emision):
    us = []
    for s, num in mayores:
        e = emision.get(s, 100000)
        v = int(num)
        if v < e:
            us.append(v / e)
    us.sort()
    n = len(us)
    d = 0.0
    for i, u in enumerate(us):
        d = max(d, abs((i + 1) / n - u), abs(u - i / n))
    return {'test': 'KS uniforme sobre numero/emision', 'estadistico': round(d, 4),
            'df': n, 'p': ks_pvalue(d, n)}


def test_rachas_paridad(mayores):
    seq = [int(num) % 2 for _, num in mayores]
    n1 = sum(seq)
    n0 = len(seq) - n1
    rachas = 1 + sum(1 for i in range(1, len(seq)) if seq[i] != seq[i - 1])
    mu = 1 + 2.0 * n0 * n1 / (n0 + n1)
    var = 2.0 * n0 * n1 * (2.0 * n0 * n1 - n0 - n1) / ((n0 + n1) ** 2 * (n0 + n1 - 1))
    z = (rachas - mu) / math.sqrt(var)
    return {'test': 'rachas par/impar (Wald-Wolfowitz)', 'estadistico': round(z, 3),
            'df': len(seq), 'p': normal_pvalue_2colas(z),
            'detalle': {'rachas': rachas, 'esperadas': round(mu, 1)}}


def test_autocorrelacion(mayores, emision):
    us = []
    for s, num in mayores:
        e = emision.get(s, 100000)
        us.append(min(int(num) / e, 1.0))
    n = len(us) - 1
    media = sum(us) / len(us)
    num_ = sum((us[i] - media) * (us[i + 1] - media) for i in range(n))
    den = sum((u - media) ** 2 for u in us)
    r = num_ / den if den else 0.0
    z = r * math.sqrt(n)
    return {'test': 'autocorrelacion lag-1 (mayor consecutivos)',
            'estadistico': round(r, 4), 'df': n, 'p': normal_pvalue_2colas(z)}


def test_colisiones(mayores, emision):
    vistos = {}
    colisiones = 0
    for s, num in mayores:
        if num in vistos:
            colisiones += 1
        vistos[num] = s
    n = len(mayores)
    e_media = sum(emision.values()) / len(emision)
    mu = n * (n - 1) / (2.0 * e_media)
    return {'test': 'repeticiones exactas del mayor (cumpleanos)',
            'estadistico': colisiones, 'df': n, 'p': poisson_pvalue_2colas(colisiones, mu),
            'detalle': {'esperadas': round(mu, 2)}}


def test_deriva_temporal(mayores):
    n = len(mayores)
    eras = 4
    tam = n // eras
    tabla = []
    for e in range(eras):
        cnt = [0] * 10
        bloque = mayores[e * tam:(e + 1) * tam if e < eras - 1 else n]
        for _, num in bloque:
            cnt[int(num[4])] += 1
        tabla.append(cnt)
    tot_col = [sum(tabla[e][d] for e in range(eras)) for d in range(10)]
    tot_fila = [sum(f) for f in tabla]
    total = sum(tot_fila)
    chi2 = 0.0
    for e in range(eras):
        for d in range(10):
            esp = tot_fila[e] * tot_col[d] / total
            if esp > 0:
                chi2 += (tabla[e][d] - esp) ** 2 / esp
    df = (eras - 1) * 9
    return {'test': 'homogeneidad temporal del ultimo digito (4 eras)',
            'estadistico': round(chi2, 2), 'df': df, 'p': chi2_pvalue(chi2, df)}


def benjamini_hochberg(resultados, alfa):
    orden = sorted(range(len(resultados)), key=lambda i: resultados[i]['p'])
    m = len(resultados)
    rechazadas = set()
    max_k = -1
    for rank, i in enumerate(orden, 1):
        if resultados[i]['p'] <= alfa * rank / m:
            max_k = rank
    for rank, i in enumerate(orden, 1):
        if rank <= max_k:
            rechazadas.add(i)
    for i, r in enumerate(resultados):
        r['significativo_fdr'] = i in rechazadas
    return resultados


def main():
    notas = carga_notas()
    if not notas:
        print('No hay NotasMayor.csv: ejecutar antes ExtraeNotasMayor.py')
        return
    # Via A: ultimos 4 digitos del mayor segun la NOTA (numero sintetico X+4).
    serie_nota = [(s, '0' + notas[s]) for s in sorted(notas)]
    # Via B: numero completo (nota del PDF + headers de la era HTML 2002-05).
    mayores, emision = carga_mayores_completos(notas)
    mv, ev = carga_mayores_viejos()
    mayores = sorted(mv + mayores)
    emision.update(ev)
    print('Via A (nota + header viejo): %d sorteos con terminacion del mayor' % len(serie_nota))
    print('Via B (numero completo): %d sorteos (%d de la era 2002-05)'
          % (len(mayores), len(mv)))

    # Subgrupo: el sesgo del ultimo digito ya existia en 2002-2005?
    viejos_digitos = [0] * 10
    for _, num in mv:
        viejos_digitos[int(num[4])] += 1
    print('Era 2002-05, ultimo digito del mayor:', viejos_digitos,
          '(9 y 5: %d de %d, esperado %.1f)'
          % (viejos_digitos[9] + viejos_digitos[5], len(mv), len(mv) / 5.0))
    print('Emision inferida: min %d, max %d, media %d'
          % (min(emision.values()), max(emision.values()),
             sum(emision.values()) // len(emision)))
    print()

    tests = [
        test_chi2_digito(serie_nota, 4, 'chi2 ultimo digito del mayor [nota]'),
        test_chi2_digito(serie_nota, 3, 'chi2 decenas del mayor [nota]'),
        test_chi2_digito(serie_nota, 2, 'chi2 centenas del mayor [nota]'),
        test_chi2_digito(serie_nota, 1, 'chi2 millares del mayor [nota]'),
        test_chi2_ultimos2(serie_nota),
        test_deriva_temporal(serie_nota),
        test_ks_uniforme(mayores, emision),
        test_rachas_paridad(mayores),
        test_autocorrelacion(mayores, emision),
        test_colisiones(mayores, emision),
    ]
    benjamini_hochberg(tests, ALFA)

    for t in tests:
        marca = 'SIGNIFICATIVO' if t['significativo_fdr'] else 'ok'
        print('%-48s stat=%-10s p=%.4f  [%s]'
              % (t['test'], t['estadistico'], t['p'], marca))

    veredicto = ('SIN EVIDENCIA de manipulacion: ningun test supera la '
                 'correccion FDR al %d%%.' % int(ALFA * 100))
    if any(t['significativo_fdr'] for t in tests):
        sig = [t['test'] for t in tests if t['significativo_fdr']]
        veredicto = ('ATENCION: %d test(s) significativos tras FDR: %s. '
                     'Requiere investigacion dirigida.' % (len(sig), ', '.join(sig)))
    print()
    print('VEREDICTO:', veredicto)

    with open(SALIDA, 'w', encoding='ascii') as fh:
        json.dump({'n_mayores': len(mayores),
                   'rango': [mayores[0][0], mayores[-1][0]],
                   'alfa': ALFA, 'tests': tests, 'veredicto': veredicto},
                  fh, indent=1)
    print('Guardado:', SALIDA)


if __name__ == '__main__':
    main()
