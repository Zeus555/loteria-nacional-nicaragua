"""ExtraePremiosV2.py - Fase 3: extraccion de premios por coordenadas.

Convierte cada PDF con 'pdftohtml' (xpdf) a divs posicionados y empareja cada
billete de 5 digitos con el monto mas cercano en su misma fila. Sin dependencias
externas (Python 3.7 stdlib).

Uso:
  python ExtraePremiosV2.py                  # procesa todos los PDF con texto
  python ExtraePremiosV2.py 2286 1660        # solo esos sorteos (modo prueba)
  python ExtraePremiosV2.py --nuevos         # incremental: sorteos con PDF que
                                             # aun no estan en ExtraccionV2.csv
                                             # (anexa filas, no regenera)

Salida: Resultados\ExtraccionV2.csv  (sorteo|tipo|numero|monto|confianza)
        Resultados\ExtraccionV2_stats.csv (metricas por sorteo)
"""
import csv
import os
import re
import shutil
import subprocess
import sys
import tempfile

PDFTOHTML = r"D:\Herramientas\xpdfbin\bin64\pdftohtml.exe"
RAIZ = r"D:\PRC Loteria Nacional"
DATOS = os.path.join(RAIZ, "Datos")
RESULTADOS = os.path.join(RAIZ, "Resultados")

DIV_RE = re.compile(
    r'<div class="txt" style="position:absolute; left:(\d+)px; top:(\d+)px;">(.*?)</div>')
SPAN_RE = re.compile(
    r'<span[^>]*font-size:(\d+)px;vertical-align:([a-z-]+)[^>]*>(.*?)</span>')
TAG_RE = re.compile(r'<[^>]+>')
ENT_RE = re.compile(r'&#\d+;|&[a-zA-Z]+;')

NUMERO_RE = re.compile(r'^\d{5}$')
MONTO_RE = re.compile(r'^\d[\d,]*\.\d{2}$')
# Montos de premios destacados: "C$400,000.00", "C$4,000,000" o "5,000,000".
GRANDE_RE = re.compile(r'^(?:C\$\s?)?\d{1,3}(?:,\d{3})+(?:\.\d{2})?$')
TIER_RE = re.compile(
    r'(?:PREMIO\s+)?(MAYOR|SEGUNDO|TERCER|CUARTO|QUINTO|SEXTO)(?:\s+PREMIO)?', re.I)

# Tolerancias en pixeles (pdftohtml a 150 dpi).
DY_FILA = 5          # misma fila si |dy| <= 5
DX_MAX = 110         # separacion maxima numero->monto
RADIO_TIER = 70      # radio para asociar UN numero a una caja de premio destacado
ANCHO_CHAR = 0.55    # ancho estimado de un caracter como fraccion del font-size


def limpia(texto):
    texto = TAG_RE.sub(' ', texto)
    texto = ENT_RE.sub(' ', texto)
    return ' '.join(texto.split())


def parsea_pagina(ruta):
    """Devuelve lista de tokens (x, y, tam_fuente, texto).

    Los divs pueden fusionar varios valores ("3000.00 08605"); se separan en
    tokens y a cada uno se le estima su x segun el ancho de los caracteres
    previos. Precision suficiente para el emparejamiento por columnas.
    """
    with open(ruta, encoding='utf-8', errors='replace') as fh:
        contenido = fh.read()
    tokens = []
    for m in DIV_RE.finditer(contenido):
        x, y = int(m.group(1)), int(m.group(2))
        # 1) Fusiona spans consecutivos partidos por kerning: mismo tamano y
        #    ambos en baseline se pegan SIN espacio ("1"+"000.00" -> "1000.00").
        #    Tamanos distintos o superindice se separan (numero gigante + serie).
        segmentos = []      # (tam, texto)
        fin_con_espacio = True   # el espacio se detecta sobre el texto CRUDO
        for tam_txt, valign, crudo in SPAN_RE.findall(m.group(3)):
            tam = int(tam_txt)
            texto = limpia(crudo)
            crudo_plano = ENT_RE.sub(' ', TAG_RE.sub(' ', crudo))
            if not texto:
                fin_con_espacio = True
                continue
            if (segmentos and segmentos[-1][0] == tam and valign == 'baseline'
                    and not fin_con_espacio
                    and not crudo_plano.startswith(' ')):
                segmentos[-1] = (tam, segmentos[-1][1] + texto)
            else:
                segmentos.append((tam, texto))
            fin_con_espacio = crudo_plano.endswith(' ')
        # 2) Cada token hereda el tamano de fuente de SU segmento.
        offset = 0.0
        for tam, texto in segmentos:
            for tok in texto.split(' '):
                if tok:
                    tokens.append((int(x + offset), y, tam, tok))
                offset += (len(tok) + 1) * tam * ANCHO_CHAR
    return tokens


def procesa_sorteo(num_sorteo, ruta_pdf, escritor):
    """Extrae pares numero-monto de un PDF. Devuelve dict de metricas."""
    tmp = tempfile.mkdtemp(prefix='lnx_')
    met = {'sorteo': num_sorteo, 'directos': 0, 'emparejados': 0,
           'sueltos': 0, 'tiers': 0, 'error': ''}
    try:
        r = subprocess.run([PDFTOHTML, '-q', ruta_pdf, os.path.join(tmp, 'h')],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                           timeout=120)
        paginas = sorted(f for f in os.listdir(os.path.join(tmp, 'h'))
                         if re.match(r'page\d+\.html$', f)) if r.returncode == 0 else []
        if not paginas:
            met['error'] = 'pdftohtml_fallo'
            return met
        for pagina in paginas:
            tokens = parsea_pagina(os.path.join(tmp, 'h', pagina))
            numeros, montos, grandes, tiers = [], [], [], []
            for tok in tokens:
                x, y, tam, texto = tok
                if NUMERO_RE.match(texto):
                    numeros.append(tok)
                elif MONTO_RE.match(texto):
                    # Los divs decorativos ("29 MIL") sueltan fragmentos tipo
                    # "0.00"; ningun premio real baja de C$100.
                    if float(texto.replace(',', '')) < 100:
                        continue
                    montos.append(tok)
                    # Un monto con coma de miles tambien puede ser el premio
                    # de una caja destacada ("C$ 7,500,000.00").
                    if ',' in texto:
                        grandes.append(tok)
                elif GRANDE_RE.match(texto):
                    grandes.append(tok)
                else:
                    mt = TIER_RE.match(texto)
                    if mt and texto.upper() == mt.group(1).upper():
                        tiers.append((x, y, mt.group(1).upper()))

            # Cada etiqueta de premio destacado marca solo a SU numero mas cercano.
            marca_tier = {}
            for tx, ty, tnombre in tiers:
                mejor_i, mejor_d = None, None
                for i, (nx, ny, ntam, ntexto) in enumerate(numeros):
                    d = abs(tx - nx) + abs(ty - ny)
                    if d <= 2 * RADIO_TIER and (mejor_d is None or d < mejor_d):
                        mejor_i, mejor_d = i, d
                if mejor_i is not None and mejor_i not in marca_tier:
                    marca_tier[mejor_i] = tnombre

            # Regla por tamano de fuente: los numeros de cuadricula (fuente
            # pequena) solo emparejan montos de su fila; los numeros grandes
            # (cajas de premios destacados) solo emparejan montos "grandes".
            # La asignacion caja<->monto es global por distancia para evitar
            # corrimientos en cadena cuando las cajas estan pegadas.
            usados = set()
            grandes_idx = [i for i, n in enumerate(numeros) if n[2] >= 20]
            asignado_num, asignado_monto = {}, set()
            pares = []
            for i in grandes_idx:
                nx, ny = numeros[i][0], numeros[i][1]
                for k, (gx, gy, gtam, gtexto) in enumerate(grandes):
                    d = abs(gx - nx) + abs(gy - ny)
                    if d <= 320:
                        pares.append((d, i, k))
            for d, i, k in sorted(pares):
                if i in asignado_num or k in asignado_monto:
                    continue
                asignado_num[i] = k
                asignado_monto.add(k)

            for i, (nx, ny, ntam, ntexto) in enumerate(numeros):
                tipo = marca_tier.get(i, 'Ordinario')

                if ntam >= 20:
                    if i in asignado_num:
                        gtxt = grandes[asignado_num[i]][3]
                        gtxt = gtxt.replace('C$', '').replace(' ', '').replace(',', '')
                        if '.' not in gtxt:
                            gtxt += '.00'
                        escritor.writerow([num_sorteo, tipo, ntexto, gtxt, 70])
                        met['emparejados'] += 1
                        met['tiers'] += 1
                    else:
                        escritor.writerow([num_sorteo, tipo, ntexto, '', 0])
                        met['sueltos'] += 1
                    continue

                mejor, mejor_dx = None, None
                for j, (mx, my, mtam, mtexto) in enumerate(montos):
                    if j in usados or abs(my - ny) > DY_FILA:
                        continue
                    dx = mx - nx
                    if dx <= 0 or dx > DX_MAX:
                        continue
                    if mejor is None or dx < mejor_dx:
                        mejor, mejor_dx = j, dx
                if mejor is not None:
                    usados.add(mejor)
                    monto = montos[mejor][3].replace(',', '')
                    conf = 95 if mejor_dx <= 70 else 85
                    escritor.writerow([num_sorteo, tipo, ntexto, monto, conf])
                    met['emparejados'] += 1
                    if tipo != 'Ordinario':
                        met['tiers'] += 1
                else:
                    escritor.writerow([num_sorteo, tipo, ntexto, '', 0])
                    met['sueltos'] += 1
        return met
    except subprocess.TimeoutExpired:
        met['error'] = 'timeout'
        return met
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def main():
    args = sys.argv[1:]
    incremental = '--nuevos' in args
    solo = set(a for a in args if a != '--nuevos')
    sufijo = '_prueba' if solo else ''
    # Omitimos los escaneados sin texto segun la verificacion mas reciente.
    sin_texto = set()
    verifs = sorted(f for f in os.listdir(RESULTADOS)
                    if re.match(r'VerificacionPDFs_\d+\.csv$', f))
    if verifs:
        with open(os.path.join(RESULTADOS, verifs[-1]), encoding='utf-8-sig') as fh:
            for fila in csv.DictReader(fh):
                if fila['estado'] == 'sin_texto':
                    sin_texto.add(fila['archivo'])

    # Modo incremental: solo sorteos nunca PROCESADOS. Se usa el fichero de
    # stats (registra cada sorteo procesado aunque diera 0 premios) para no
    # re-procesar a diario los escaneados que no producen filas.
    ya_extraidos = set()
    ruta_maestro = os.path.join(RESULTADOS, 'ExtraccionV2.csv')
    ruta_procesados = os.path.join(RESULTADOS, 'ExtraccionV2_stats.csv')
    if incremental:
        for ruta_previa in (ruta_procesados, ruta_maestro):
            if os.path.exists(ruta_previa):
                with open(ruta_previa, encoding='ascii', errors='replace') as fh:
                    for fila in csv.reader(fh, delimiter='|'):
                        if fila and fila[0].isdigit():
                            ya_extraidos.add(fila[0])

    pdfs = []
    for nombre in os.listdir(DATOS):
        base, ext = os.path.splitext(nombre)
        if ext.lower() != '.pdf' or not base.isdigit():
            continue
        if solo and base not in solo:
            continue
        if base in sin_texto or base in ya_extraidos:
            continue
        ruta = os.path.join(DATOS, nombre)
        if os.path.getsize(ruta) > 0:
            pdfs.append((int(base), ruta))
    pdfs.sort()

    if incremental:
        print('NUEVOS: %s' % ','.join(str(n) for n, _ in pdfs))
        if not pdfs:
            return

    ruta_csv = ruta_maestro if not solo else os.path.join(
        RESULTADOS, 'ExtraccionV2%s.csv' % sufijo)
    ruta_stats = os.path.join(RESULTADOS, 'ExtraccionV2_stats%s.csv' % sufijo)
    modo_csv = 'a' if incremental else 'w'
    modo_stats = 'a' if incremental else 'w'
    with open(ruta_csv, modo_csv, newline='', encoding='ascii', errors='replace') as fcsv, \
            open(ruta_stats, modo_stats, newline='', encoding='ascii') as fst:
        escritor = csv.writer(fcsv, delimiter='|')
        stats = csv.writer(fst, delimiter='|')
        if not incremental:
            escritor.writerow(['sorteo', 'tipo', 'numero', 'monto', 'confianza'])
            stats.writerow(['sorteo', 'directos', 'emparejados', 'sueltos', 'tiers', 'error'])
        for i, (num, ruta) in enumerate(pdfs, 1):
            met = procesa_sorteo(num, ruta, escritor)
            stats.writerow([met['sorteo'], met['directos'], met['emparejados'],
                            met['sueltos'], met['tiers'], met['error']])
            if i % 25 == 0 or i == len(pdfs):
                print('... %d/%d (sorteo %d)' % (i, len(pdfs), num), flush=True)
    print('Listo: %s' % ruta_csv)


if __name__ == '__main__':
    main()
