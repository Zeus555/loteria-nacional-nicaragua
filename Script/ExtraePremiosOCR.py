"""ExtraePremiosOCR.py - Fase 4: extraccion OCR de los PDFs escaneados.

Para los sorteos cuyo PDF no tiene capa de texto: renderiza con pdftopng a
300 dpi, aplica Tesseract en modo TSV (cada palabra con sus coordenadas) y
reutiliza el mismo emparejamiento por filas/cajas del extractor v2.

Uso:
  python ExtraePremiosOCR.py 1913 1950      # sorteos concretos
  python ExtraePremiosOCR.py --pendientes   # todos los validos sin extraer

Salida: Resultados\ExtraccionOCR.csv (sorteo|tipo|numero|monto|confianza)
"""
import csv
import os
import re
import shutil
import subprocess
import sys
import tempfile

PDFTOPNG = r"D:\Herramientas\xpdfbin\bin64\pdftopng.exe"
TESSERACT = r"C:\Program Files\Tesseract-OCR\tesseract.exe"
RAIZ = r"D:\PRC Loteria Nacional"
DATOS = os.path.join(RAIZ, "Datos")
RESULTADOS = os.path.join(RAIZ, "Resultados")

NUMERO_RE = re.compile(r'^\d{5}$')
MONTO_RE = re.compile(r'^\d[\d,\.]*\.\d{2}$')
GRANDE_RE = re.compile(r'^(?:C\$\s?)?\d{1,3}(?:[,\.]\d{3})+(?:\.\d{2})?$')
TIER_RE = re.compile(r'^(MAYOR|SEGUNDO|TERCER|CUARTO|QUINTO|SEXTO)$', re.I)

# Tolerancias a 300 dpi (el doble que la v2 a 150 dpi).
DY_FILA = 12
DX_MAX = 240
ALTO_GRANDE = 46      # alto de palabra que delata numero de caja destacada
CONF_MIN = 40         # confianza minima de tesseract para usar una palabra


def ocr_pagina(png):
    """Devuelve lista de palabras (x, y, alto, conf, texto) via TSV."""
    r = subprocess.run([TESSERACT, png, 'stdout', '--psm', '6', 'tsv'],
                       stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                       timeout=300)
    palabras = []
    for lin in r.stdout.decode('utf-8', errors='replace').splitlines():
        c = lin.split('\t')
        if len(c) < 12 or c[0] == 'level' or c[0] != '5':
            continue
        try:
            x, y, alto, conf = int(c[6]), int(c[7]), int(c[9]), float(c[10])
        except ValueError:
            continue
        texto = c[11].strip()
        if not texto or conf < CONF_MIN:
            continue
        palabras.append((x, y, alto, conf, texto))
    return palabras


def procesa_sorteo(num_sorteo, ruta_pdf, escritor):
    tmp = tempfile.mkdtemp(prefix='lno_')
    met = {'sorteo': num_sorteo, 'emparejados': 0, 'sueltos': 0,
           'tiers': 0, 'error': ''}
    try:
        r = subprocess.run([PDFTOPNG, '-r', '300', ruta_pdf,
                            os.path.join(tmp, 'p')],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                           timeout=300)
        pngs = sorted(f for f in os.listdir(tmp) if f.endswith('.png'))
        if r.returncode != 0 or not pngs:
            met['error'] = 'pdftopng_fallo'
            return met
        for png in pngs:
            palabras = ocr_pagina(os.path.join(tmp, png))
            numeros, montos, grandes, tiers = [], [], [], []
            for pal in palabras:
                x, y, alto, conf, texto = pal
                if NUMERO_RE.match(texto):
                    numeros.append(pal)
                elif MONTO_RE.match(texto):
                    montos.append(pal)
                    if ',' in texto:
                        grandes.append(pal)
                elif GRANDE_RE.match(texto):
                    grandes.append(pal)
                elif TIER_RE.match(texto):
                    tiers.append((x, y, texto.upper()))

            marca_tier = {}
            for tx, ty, tnombre in tiers:
                mejor_i, mejor_d = None, None
                for i, n in enumerate(numeros):
                    d = abs(tx - n[0]) + abs(ty - n[1])
                    if d <= 300 and (mejor_d is None or d < mejor_d):
                        mejor_i, mejor_d = i, d
                if mejor_i is not None and mejor_i not in marca_tier:
                    marca_tier[mejor_i] = tnombre

            grandes_idx = [i for i, n in enumerate(numeros) if n[2] >= ALTO_GRANDE]
            pares = []
            for i in grandes_idx:
                nx, ny = numeros[i][0], numeros[i][1]
                for k, g in enumerate(grandes):
                    d = abs(g[0] - nx) + abs(g[1] - ny)
                    if d <= 700:
                        pares.append((d, i, k))
            asignado_num, asignado_monto = {}, set()
            for d, i, k in sorted(pares):
                if i in asignado_num or k in asignado_monto:
                    continue
                asignado_num[i] = k
                asignado_monto.add(k)

            usados = set()
            for i, (nx, ny, nalto, nconf, ntexto) in enumerate(numeros):
                tipo = marca_tier.get(i, 'Ordinario')

                if nalto >= ALTO_GRANDE:
                    if i in asignado_num:
                        g = grandes[asignado_num[i]]
                        gtxt = g[4].replace('C$', '').replace(' ', '')
                        gtxt = gtxt.replace(',', '').rstrip('.')
                        # OCR a veces lee separadores de miles como puntos.
                        partes = gtxt.split('.')
                        if len(partes) > 2 or (len(partes) == 2 and len(partes[1]) == 3):
                            gtxt = ''.join(partes)
                        if '.' not in gtxt:
                            gtxt += '.00'
                        conf = int(min(g[3], nconf, 60))
                        escritor.writerow([num_sorteo, tipo, ntexto, gtxt, conf])
                        met['emparejados'] += 1
                        met['tiers'] += 1
                    else:
                        escritor.writerow([num_sorteo, tipo, ntexto, '', 0])
                        met['sueltos'] += 1
                    continue

                mejor, mejor_dx = None, None
                for j, (mx, my, malto, mconf, mtexto) in enumerate(montos):
                    if j in usados or abs(my - ny) > DY_FILA:
                        continue
                    dx = mx - nx
                    if dx <= 0 or dx > DX_MAX:
                        continue
                    if mejor is None or dx < mejor_dx:
                        mejor, mejor_dx = j, dx
                if mejor is not None:
                    usados.add(mejor)
                    m = montos[mejor]
                    conf = int(min(m[3], nconf, 90))
                    escritor.writerow([num_sorteo, tipo, ntexto,
                                       m[4].replace(',', ''), conf])
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


def sorteos_pendientes():
    """PDFs validos cuyo sorteo no tiene premios en ExtraccionV2.csv."""
    cubiertos = set()
    v2 = os.path.join(RESULTADOS, 'ExtraccionV2.csv')
    if os.path.exists(v2):
        with open(v2, encoding='ascii', errors='replace') as fh:
            for fila in csv.reader(fh, delimiter='|'):
                if fila and fila[0].isdigit():
                    cubiertos.add(int(fila[0]))
    objetivo = []
    for nombre in os.listdir(DATOS):
        base, ext = os.path.splitext(nombre)
        if ext.lower() != '.pdf' or not base.isdigit():
            continue
        ruta = os.path.join(DATOS, nombre)
        if os.path.getsize(ruta) > 0 and int(base) not in cubiertos:
            objetivo.append(int(base))
    return sorted(objetivo)


def main():
    args = sys.argv[1:]
    if args and args[0] != '--pendientes':
        objetivo = sorted(int(a) for a in args)
    else:
        objetivo = sorteos_pendientes()
    print('Sorteos a procesar via OCR: %d -> %s' % (len(objetivo), objetivo))

    ruta_csv = os.path.join(RESULTADOS, 'ExtraccionOCR.csv')
    ruta_stats = os.path.join(RESULTADOS, 'ExtraccionOCR_stats.csv')
    with open(ruta_csv, 'w', newline='', encoding='ascii', errors='replace') as fcsv, \
            open(ruta_stats, 'w', newline='', encoding='ascii') as fst:
        escritor = csv.writer(fcsv, delimiter='|')
        escritor.writerow(['sorteo', 'tipo', 'numero', 'monto', 'confianza'])
        stats = csv.writer(fst, delimiter='|')
        stats.writerow(['sorteo', 'emparejados', 'sueltos', 'tiers', 'error'])
        for i, num in enumerate(objetivo, 1):
            ruta = os.path.join(DATOS, '%d.pdf' % num)
            met = procesa_sorteo(num, ruta, escritor)
            stats.writerow([met['sorteo'], met['emparejados'], met['sueltos'],
                            met['tiers'], met['error']])
            print('... %d/%d sorteo %d: %d pares, %d sueltos %s'
                  % (i, len(objetivo), num, met['emparejados'], met['sueltos'],
                     met['error']), flush=True)
    print('Listo: %s' % ruta_csv)


if __name__ == '__main__':
    main()
