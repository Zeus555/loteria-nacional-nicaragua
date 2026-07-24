"""CosechaHtmlViejo.py - Recupera de Wayback los sorteos 1138-1259 (2002-2005)
publicados como HTML en el sitio viejo, los archiva y extrae sus premios.

  1. CDX enumera las capturas de /sorteos/NNNN.htm (status 200).
  2. Descarga la mejor captura de cada sorteo a Datos/HtmlViejo/NNNN.html
     (archivo sagrado: solo-anadir).
  3. Parsea: fecha, premios etiquetados (PRIMER..5to) y cuadricula completa
     por adyacencia numero->monto en el flujo de texto.

Salida: Resultados/ExtraccionHtmlViejo.csv (sorteo|tipo|numero|monto|confianza)
        Resultados/SorteosHtmlViejo.csv   (sorteo|fecha_txt|url_wayback)
"""
import csv
import json
import os
import re
import time
import urllib.request
from collections import defaultdict

RAIZ = r"D:\PRC Loteria Nacional"
CARPETA = os.path.join(RAIZ, "Datos", "HtmlViejo")
SAL_PREMIOS = os.path.join(RAIZ, "Resultados", "ExtraccionHtmlViejo.csv")
SAL_SORTEOS = os.path.join(RAIZ, "Resultados", "SorteosHtmlViejo.csv")

CDX = ("http://web.archive.org/cdx/search/cdx?url=loterianacional.com.ni%2Fsorteos%2F*"
       "&output=json&fl=original,timestamp,statuscode&limit=3000")

NUMERO_RE = re.compile(r"^\d{5}$")
MONTO_RE = re.compile(r"^\d{1,3}(?:,\d{3})*(?:[.,]\d{2})?$|^\d+\.\d{2}$")
TIERS = [
    (re.compile(r"PRIMER\s+PREMIO", re.I), "MAYOR"),
    (re.compile(r"2do\.?\s*Premio", re.I), "SEGUNDO"),
    (re.compile(r"3er\.?\s*Premio", re.I), "TERCER"),
    (re.compile(r"4to\.?\s*Premio", re.I), "CUARTO"),
    (re.compile(r"5to\.?\s*Premio", re.I), "QUINTO"),
    (re.compile(r"6to\.?\s*Premio", re.I), "SEXTO"),
]
FECHA_RE = re.compile(r"Correspondiente\s+al\s+(.+?\d{4})", re.I)
SORTEO_RE = re.compile(r"SORTEO\s+No\.?\s*(\d{3,4})", re.I)


def descarga(url, intentos=3):
    for i in range(intentos):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=60) as r:
                return r.read()
        except Exception:
            time.sleep(3 * (i + 1))
    return None


def normaliza_monto(tok):
    t = tok.replace(",", "")
    # Erratas de la epoca: "40,000,00" -> el ultimo bloque son centavos.
    if re.match(r"^\d{1,3}(?:,\d{3})*,\d{2}$", tok):
        t = tok[: tok.rfind(",")].replace(",", "") + "." + tok[tok.rfind(",") + 1:]
    if "." not in t:
        t += ".00"
    try:
        v = float(t)
    except ValueError:
        return None
    return t if 100 <= v <= 50000000 else None


def parsea(html, num_esperado, wpremios, wsorteos, url):
    texto = re.sub(r"<script.*?</script>", " ", html, flags=re.S | re.I)
    texto = re.sub(r"<[^>]+>", " ", texto)
    texto = texto.replace("&nbsp;", " ")

    m = SORTEO_RE.search(texto)
    interno = int(m.group(1)) if m else None
    if interno is not None and interno != num_esperado:
        # El markup de la epoca a veces parte el numero ("117 5"): se acepta
        # si lo leido es prefijo del esperado.
        if not str(num_esperado).startswith(str(interno)):
            return "desajuste(%s)" % interno
    mf = FECHA_RE.search(texto)
    fecha = " ".join(mf.group(1).split()) if mf else ""
    wsorteos.writerow([num_esperado, fecha, url])

    # Marca las etiquetas de premio en el texto para asignar el numero que sigue.
    for rx, nombre in TIERS:
        texto = rx.sub(" __TIER_%s__ " % nombre, texto)

    tokens = texto.split()
    pares = 0
    tier = None
    i = 0
    while i < len(tokens):
        tok = tokens[i]
        if tok.startswith("__TIER_"):
            tier = tok[7:-2]
            i += 1
            continue
        if NUMERO_RE.match(tok):
            monto = None
            if i + 1 < len(tokens) and MONTO_RE.match(tokens[i + 1]):
                monto = normaliza_monto(tokens[i + 1])
            tipo = tier or "Ordinario"
            tier = None
            if monto is not None:
                wpremios.writerow([num_esperado, tipo, tok, monto, 75])
                pares += 1
                i += 2
                continue
            wpremios.writerow([num_esperado, tipo, tok, "", 0])
        i += 1
    return "ok(%d)" % pares


def main():
    os.makedirs(CARPETA, exist_ok=True)
    datos = json.loads(descarga(CDX).decode("utf-8"))
    mejor = {}
    for orig, ts, status in datos[1:]:
        m = re.search(r"/sorteos/(\d{3,4})\.htm", orig)
        if not m or status != "200":
            continue
        n = int(m.group(1))
        if n not in mejor or ts > mejor[n][1]:
            mejor[n] = (orig, ts)
    print("Sorteos HTML viejos disponibles: %d" % len(mejor))

    with open(SAL_PREMIOS, "w", newline="", encoding="ascii", errors="replace") as fp, \
            open(SAL_SORTEOS, "w", newline="", encoding="ascii", errors="replace") as fs:
        wp = csv.writer(fp, delimiter="|")
        wp.writerow(["sorteo", "tipo", "numero", "monto", "confianza"])
        ws = csv.writer(fs, delimiter="|")
        ws.writerow(["sorteo", "fecha_txt", "url_wayback"])
        for k, n in enumerate(sorted(mejor), 1):
            orig, ts = mejor[n]
            destino = os.path.join(CARPETA, "%d.html" % n)
            url = "https://web.archive.org/web/%sif_/%s" % (ts, orig)
            if os.path.exists(destino) and os.path.getsize(destino) > 5000:
                cuerpo = open(destino, "rb").read()
            else:
                cuerpo = descarga(url)
                if not cuerpo:
                    print("  %d: DESCARGA FALLIDA" % n)
                    continue
                with open(destino, "wb") as fh:
                    fh.write(cuerpo)
                time.sleep(0.7)
            res = parsea(cuerpo.decode("utf-8", errors="replace"), n, wp, ws, url)
            print("  %d/%d sorteo %d: %s" % (k, len(mejor), n, res), flush=True)
    print("Listo:", SAL_PREMIOS)


if __name__ == "__main__":
    main()
