"""ExtraePremiosRaw.py - Extractor de respaldo sobre pdftotext -table.

Para los sorteos donde pdftohtml pierde contenido (extraordinarios grandes de
~906 numeros y la era 1438-1529): pdftotext -table (xpdf 4) reconstruye las
filas visuales de la lista y cada billete queda adyacente a su monto en la
misma linea. Se emparejan pares "NNNNN monto" por adyacencia.
(El modo -raw no sirve en los PDFs modernos: agrupa todos los numeros primero
y todos los montos despues.)

Uso:
  python ExtraePremiosRaw.py 2286              # prueba sobre sorteos concretos
  python ExtraePremiosRaw.py --perdidas        # todos los del censo con
                                               # perdida > 30 (CantidadCrudoVsExtraido.csv)
  ... --aplica                                 # ademas reemplaza esas filas en
                                               # ExtraccionV2.csv (respaldo .bak)

Salida: Resultados/ExtraccionRaw.csv (sorteo|tipo|numero|monto|confianza)
"""
import csv
import os
import re
import shutil
import subprocess
import sys
import tempfile

PDFTOTEXT = r"C:\Program Files\Git\mingw64\bin\pdftotext.exe"
RAIZ = r"D:\PRC Loteria Nacional"
DATOS = os.path.join(RAIZ, "Datos")
RESULTADOS = os.path.join(RAIZ, "Resultados")
CENSO = os.path.join(RESULTADOS, "CantidadCrudoVsExtraido.csv")
MAESTRO = os.path.join(RESULTADOS, "ExtraccionV2.csv")
SALIDA = os.path.join(RESULTADOS, "ExtraccionRaw.csv")

NUMERO_RE = re.compile(r"^\d{5}$")
MONTO_RE = re.compile(r"^(?:C\$)?\d[\d,]*\.\d{2}$")
GRANDE_RE = re.compile(r"^(?:C\$)?\d{1,3}(?:,\d{3})+(?:\.\d{2})?$")
TIER_RE = re.compile(r"^(MAYOR|SEGUNDO|TERCER|CUARTO|QUINTO|SEXTO)$", re.I)
UMBRAL_PERDIDA = 30


def texto_pdf(num_sorteo, modo):
    ruta = os.path.join(DATOS, "%d.pdf" % num_sorteo)
    tmp = tempfile.mktemp(suffix=".txt")
    try:
        r = subprocess.run([PDFTOTEXT, modo, ruta, tmp],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                           timeout=120)
        if r.returncode != 0 or not os.path.exists(tmp):
            return []
        with open(tmp, encoding="utf-8", errors="replace") as fh:
            return fh.read().splitlines()
    finally:
        if os.path.exists(tmp):
            os.remove(tmp)


def normaliza_monto(tok):
    m = tok.replace("C$", "").replace(",", "")
    if "." not in m:
        m += ".00"
    try:
        return m if float(m) >= 100 else None
    except ValueError:
        return None


def extrae_tabla(num_sorteo):
    """Pares por adyacencia en las filas visuales de pdftotext -table."""
    pares = []
    sueltos = []
    for linea in texto_pdf(num_sorteo, "-table"):
        if "NOTA:" in linea or "TERMINADOS EN" in linea:
            continue
        tokens = linea.split()
        for i, tok in enumerate(tokens):
            if not NUMERO_RE.match(tok):
                continue
            monto = None
            if i + 1 < len(tokens) and (MONTO_RE.match(tokens[i + 1])
                                        or GRANDE_RE.match(tokens[i + 1])):
                monto = normaliza_monto(tokens[i + 1])
            if monto is not None:
                pares.append((tok, monto))
            else:
                sueltos.append(tok)
    return pares, sueltos


def extrae_zip(num_sorteo):
    """Pares por cola FIFO sobre pdftotext -raw: el flujo alterna bloques de
    numeros y bloques de montos espejados en el mismo orden."""
    pares = []
    cola = []
    for linea in texto_pdf(num_sorteo, "-raw"):
        if "NOTA:" in linea or "TERMINADOS EN" in linea:
            continue
        for tok in linea.split():
            if NUMERO_RE.match(tok):
                cola.append(tok)
            elif MONTO_RE.match(tok) or GRANDE_RE.match(tok):
                monto = normaliza_monto(tok)
                if monto is not None and cola:
                    pares.append((cola.pop(0), monto))
    return pares, cola


def extrae_sorteo(num_sorteo, escritor):
    """Elige el modo que mas pares logra (tabla para la era 1438-1529,
    zip para los extraordinarios grandes cuya tabla pierde media pagina)."""
    pt, st = extrae_tabla(num_sorteo)
    pz, sz = extrae_zip(num_sorteo)
    if len(pz) > len(pt):
        pares, sueltos, modo = pz, sz, "zip"
    else:
        pares, sueltos, modo = pt, st, "tabla"
    for numero, monto in pares:
        escritor.writerow([num_sorteo, "Ordinario", numero, monto, 80])
    for numero in sueltos:
        escritor.writerow([num_sorteo, "Ordinario", numero, "", 0])
    return len(pares), len(sueltos), modo


def main():
    args = [a for a in sys.argv[1:]]
    aplica = "--aplica" in args
    if "--perdidas" in args:
        objetivo = []
        with open(CENSO, encoding="ascii") as fh:
            for f in csv.reader(fh, delimiter="|"):
                if f and f[0].isdigit() and int(f[3]) > UMBRAL_PERDIDA:
                    objetivo.append(int(f[0]))
        objetivo.sort()
    else:
        objetivo = sorted(int(a) for a in args if a.isdigit())
    print("Sorteos a re-extraer en modo raw: %d" % len(objetivo))

    with open(SALIDA, "w", newline="", encoding="ascii") as fh:
        w = csv.writer(fh, delimiter="|")
        w.writerow(["sorteo", "tipo", "numero", "monto", "confianza"])
        for s in objetivo:
            p, su, modo = extrae_sorteo(s, w)
            print("  sorteo %d: %d pares, %d sueltos [%s]" % (s, p, su, modo))

    if aplica and objetivo:
        # Reemplaza en el CSV maestro las filas de esos sorteos.
        respaldo = MAESTRO + ".bak"
        shutil.copyfile(MAESTRO, respaldo)
        objetivo_txt = set(str(s) for s in objetivo)
        tmp = MAESTRO + ".tmp"
        with open(MAESTRO, encoding="ascii", errors="replace") as fi, \
                open(tmp, "w", newline="", encoding="ascii") as fo:
            for lin in fi:
                clave = lin.split("|", 1)[0]
                if clave not in objetivo_txt:
                    fo.write(lin)
            with open(SALIDA, encoding="ascii") as fr:
                next(fr)
                for lin in fr:
                    fo.write(lin)
        os.replace(tmp, MAESTRO)
        print("Aplicado a %s (respaldo en %s)" % (MAESTRO, respaldo))


if __name__ == "__main__":
    main()
