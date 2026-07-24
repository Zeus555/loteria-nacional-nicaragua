"""ExtraeNotasMayor.py - Fase 5: extrae la terminacion del premio mayor desde
la NOTA al pie de cada lista ("LOS BILLETES TERMINADOS EN 0595 GANAN...").

Es un canal independiente del emparejado de premios: da los ultimos 4 digitos
del mayor en texto plano y sirve para la bateria de equidad y para validar la
identificacion del mayor.

Salida: Resultados/NotasMayor.csv (sorteo|term4)
"""
import csv
import os
import re
import subprocess
import sys
import tempfile

PDFTOTEXT = r"C:\Program Files\Git\mingw64\bin\pdftotext.exe"
RAIZ = r"D:\PRC Loteria Nacional"
DATOS = os.path.join(RAIZ, "Datos")
SALIDA = os.path.join(RAIZ, "Resultados", "NotasMayor.csv")

# "LOS BILLETES TERMINADOS EN 0595 GANAN" (a veces con espacios o puntuacion)
NOTA_RE = re.compile(r'TERMINADOS\s+EN\s+(\d{4})\s+GANAN', re.I)


def term4(ruta_pdf):
    tmp = tempfile.mktemp(suffix='.txt')
    try:
        r = subprocess.run([PDFTOTEXT, '-raw', ruta_pdf, tmp],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                           timeout=60)
        if r.returncode != 0 or not os.path.exists(tmp):
            return None
        with open(tmp, encoding='utf-8', errors='replace') as fh:
            texto = fh.read()
        m = NOTA_RE.search(texto)
        return m.group(1) if m else None
    except subprocess.TimeoutExpired:
        return None
    finally:
        if os.path.exists(tmp):
            os.remove(tmp)


def main():
    pdfs = []
    for nombre in os.listdir(DATOS):
        base, ext = os.path.splitext(nombre)
        if ext.lower() == '.pdf' and base.isdigit():
            ruta = os.path.join(DATOS, nombre)
            if os.path.getsize(ruta) > 0:
                pdfs.append((int(base), ruta))
    pdfs.sort()

    ok = 0
    with open(SALIDA, 'w', newline='', encoding='ascii') as fh:
        w = csv.writer(fh, delimiter='|')
        w.writerow(['sorteo', 'term4'])
        for i, (num, ruta) in enumerate(pdfs, 1):
            t = term4(ruta)
            if t:
                w.writerow([num, t])
                ok += 1
            if i % 100 == 0 or i == len(pdfs):
                print('... %d/%d (con nota: %d)' % (i, len(pdfs), ok), flush=True)
    print('Notas del mayor extraidas: %d de %d PDFs -> %s' % (ok, len(pdfs), SALIDA))


if __name__ == '__main__':
    main()
