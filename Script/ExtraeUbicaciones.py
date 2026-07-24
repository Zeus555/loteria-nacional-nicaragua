"""ExtraeUbicaciones.py - Donde cayo cada premio destacado.

Fuentes:
  - PDFs modernos (2006-2026): cada caja de premio destacado trae la ciudad
    del concesionario que lo vendio. Se reutiliza el parseo por coordenadas
    de ExtraePremiosV2 (pdftohtml posicionado): ciudad = token(es) que
    coinciden con un municipio conocido, asociada a la caja (numero con
    fuente >= 20px) mas cercana (asignacion global por distancia).
  - HTML viejo (2002-05): patron textual "<TIER> <numero> <monto> VENDIDO
    POR EL CONCESIONARIO <cod> <nombre> <CIUDAD>".

Guardas: se ignoran lineas con "NICARAGUA" (membrete) y municipios de
nombre ambiguo (Catarina, Rosita...) solo se aceptan en lineas cortas
(la ciudad va sola en su linea dentro de la caja).

Salida: Resultados/UbicacionesPremios.csv
        sorteo|fuente|numero|tier|monto|ciudad|departamento|vendido
"""
import csv
import os
import re
import shutil
import subprocess
import sys
import tempfile
from collections import defaultdict

RAIZ = r"D:\PRC Loteria Nacional"
SAL = os.path.join(RAIZ, "Resultados", "UbicacionesPremios.csv")
HTML_DIR = os.path.join(RAIZ, "Datos", "HtmlViejo")

sys.path.insert(0, os.path.join(RAIZ, "Script"))
from ExtraePremiosV2 import PDFTOHTML, parsea_pagina  # noqa: E402

RADIO_CAJA = 400          # distancia Manhattan maxima ciudad -> caja

# municipio (normalizado, sin acentos) -> departamento
MUNICIPIOS = {
    # Managua
    "MANAGUA": "Managua", "TIPITAPA": "Managua", "CIUDAD SANDINO": "Managua",
    "MATEARE": "Managua", "SAN RAFAEL DEL SUR": "Managua",
    "TICUANTEPE": "Managua", "VILLA EL CARMEN": "Managua",
    "SAN FRANCISCO LIBRE": "Managua", "EL CRUCERO": "Managua",
    # Leon
    "LEON": "Leon", "NAGAROTE": "Leon", "LA PAZ CENTRO": "Leon",
    "TELICA": "Leon", "MALPAISILLO": "Leon", "LARREYNAGA": "Leon",
    "EL SAUCE": "Leon", "ACHUAPA": "Leon", "QUEZALGUAQUE": "Leon",
    "EL JICARAL": "Leon", "SANTA ROSA DEL PENON": "Leon",
    # Chinandega
    "CHINANDEGA": "Chinandega", "CORINTO": "Chinandega",
    "EL VIEJO": "Chinandega", "CHICHIGALPA": "Chinandega",
    "POSOLTEGA": "Chinandega", "EL REALEJO": "Chinandega",
    "PUERTO MORAZAN": "Chinandega", "SOMOTILLO": "Chinandega",
    "VILLANUEVA": "Chinandega", "CINCO PINOS": "Chinandega",
    # Masaya
    "MASAYA": "Masaya", "MASATEPE": "Masaya", "NINDIRI": "Masaya",
    "CATARINA": "Masaya", "NIQUINOHOMO": "Masaya", "NANDASMO": "Masaya",
    "SAN JUAN DE ORIENTE": "Masaya", "TISMA": "Masaya",
    "LA CONCEPCION": "Masaya", "LA CONCHA": "Masaya",
    # Granada
    "GRANADA": "Granada", "NANDAIME": "Granada", "DIRIOMO": "Granada",
    "DIRIA": "Granada",
    # Carazo
    "JINOTEPE": "Carazo", "DIRIAMBA": "Carazo", "SAN MARCOS": "Carazo",
    "DOLORES": "Carazo", "EL ROSARIO": "Carazo", "SANTA TERESA": "Carazo",
    "LA PAZ DE CARAZO": "Carazo", "LA CONQUISTA": "Carazo",
    # Rivas
    "RIVAS": "Rivas", "SAN JORGE": "Rivas", "SAN JUAN DEL SUR": "Rivas",
    "TOLA": "Rivas", "BELEN": "Rivas", "POTOSI": "Rivas",
    "BUENOS AIRES": "Rivas", "CARDENAS": "Rivas", "MOYOGALPA": "Rivas",
    "ALTAGRACIA": "Rivas",
    # Esteli
    "ESTELI": "Esteli", "CONDEGA": "Esteli", "LA TRINIDAD": "Esteli",
    "PUEBLO NUEVO": "Esteli", "SAN JUAN DE LIMAY": "Esteli",
    "SAN NICOLAS": "Esteli",
    # Madriz
    "SOMOTO": "Madriz", "PALACAGUINA": "Madriz", "TELPANECA": "Madriz",
    "SAN JUAN DE RIO COCO": "Madriz", "TOTOGALPA": "Madriz",
    "YALAGUINA": "Madriz", "SAN LUCAS": "Madriz", "LAS SABANAS": "Madriz",
    # Nueva Segovia
    "OCOTAL": "Nueva Segovia", "JALAPA": "Nueva Segovia",
    "QUILALI": "Nueva Segovia", "EL JICARO": "Nueva Segovia",
    "CIUDAD ANTIGUA": "Nueva Segovia", "DIPILTO": "Nueva Segovia",
    "MACUELIZO": "Nueva Segovia", "MOZONTE": "Nueva Segovia",
    "MURRA": "Nueva Segovia", "SAN FERNANDO": "Nueva Segovia",
    # Jinotega
    "JINOTEGA": "Jinotega", "SAN RAFAEL DEL NORTE": "Jinotega",
    "LA CONCORDIA": "Jinotega", "YALI": "Jinotega",
    "SAN SEBASTIAN DE YALI": "Jinotega", "PANTASMA": "Jinotega",
    "WIWILI": "Jinotega", "EL CUA": "Jinotega", "BOCAY": "Jinotega",
    # Matagalpa
    "MATAGALPA": "Matagalpa", "SEBACO": "Matagalpa",
    "CIUDAD DARIO": "Matagalpa", "DARIO": "Matagalpa",
    "RIO BLANCO": "Matagalpa", "MATIGUAS": "Matagalpa",
    "MUY MUY": "Matagalpa", "SAN ISIDRO": "Matagalpa",
    "ESQUIPULAS": "Matagalpa", "SAN DIONISIO": "Matagalpa",
    "TERRABONA": "Matagalpa", "LA DALIA": "Matagalpa",
    "RANCHO GRANDE": "Matagalpa", "SAN RAMON": "Matagalpa",
    "WASLALA": "Matagalpa",
    # Boaco
    "BOACO": "Boaco", "CAMOAPA": "Boaco", "SAN LORENZO": "Boaco",
    "TEUSTEPE": "Boaco", "SANTA LUCIA": "Boaco",
    "SAN JOSE DE LOS REMATES": "Boaco",
    # Chontales
    "JUIGALPA": "Chontales", "SANTO TOMAS": "Chontales",
    "ACOYAPA": "Chontales", "VILLA SANDINO": "Chontales",
    "COMALAPA": "Chontales", "SAN PEDRO DE LOVAGO": "Chontales",
    "LA LIBERTAD": "Chontales", "SANTO DOMINGO": "Chontales",
    "EL CORAL": "Chontales",
    # Rio San Juan
    "SAN CARLOS": "Rio San Juan", "SAN MIGUELITO": "Rio San Juan",
    "MORRITO": "Rio San Juan", "EL ALMENDRO": "Rio San Juan",
    "EL CASTILLO": "Rio San Juan",
    # RACCS
    "BLUEFIELDS": "RACCS", "NUEVA GUINEA": "RACCS", "EL RAMA": "RACCS",
    "MUELLE DE LOS BUEYES": "RACCS", "KUKRA HILL": "RACCS",
    "LAGUNA DE PERLAS": "RACCS", "CORN ISLAND": "RACCS",
    "EL AYOTE": "RACCS", "EL TORTUGUERO": "RACCS",
    # RACCN
    "PUERTO CABEZAS": "RACCN", "BILWI": "RACCN", "SIUNA": "RACCN",
    "ROSITA": "RACCN", "BONANZA": "RACCN", "WASPAM": "RACCN",
    "MULUKUKU": "RACCN", "PRINZAPOLKA": "RACCN",
}
# nombres que tambien son nombres de pila / apellidos: solo se aceptan
# si la ciudad va (casi) sola en su linea
AMBIGUOS = {"CATARINA", "ROSITA", "DOLORES", "BELEN", "POTOSI", "DARIO",
            "ALTAGRACIA", "LEON", "SAN FERNANDO", "SAN RAMON", "SAN MARCOS",
            "SAN LORENZO", "SANTA LUCIA", "SAN NICOLAS", "SANTA TERESA"}
MAX_PALABRAS = max(len(k.split()) for k in MUNICIPIOS)

ACENTOS = str.maketrans("ÁÉÍÓÚÜÑáéíóúüñ", "AEIOUUNaeiouun")


def normaliza(t):
    return t.translate(ACENTOS).upper().strip(" .,;:-")


def lineas_de_tokens(tokens):
    """Agrupa tokens en lineas (mismo y +-3px) ordenadas por x."""
    filas = defaultdict(list)
    for x, y, tam, texto in tokens:
        filas[round(y / 4.0)].append((x, y, tam, texto))
    out = []
    for clave in sorted(filas):
        out.append(sorted(filas[clave]))
    return out


def candidatos_ciudad(tokens):
    """Devuelve [(x, y, ciudad)] de municipios hallados en las lineas."""
    res = []
    for linea in lineas_de_tokens(tokens):
        palabras = [normaliza(t[3]) for t in linea]
        if "NICARAGUA" in palabras:          # membrete institucional
            continue
        for i in range(len(palabras)):
            for largo in range(min(MAX_PALABRAS, len(palabras) - i), 0, -1):
                cand = " ".join(palabras[i:i + largo])
                if cand in MUNICIPIOS:
                    res.append((linea[i][0], linea[i][1], cand))
                    break
    return res


def marcas_no_vendido(tokens):
    """Posiciones de 'NO FUE VENDIDO' (junto o partido)."""
    res = []
    for linea in lineas_de_tokens(tokens):
        palabras = [normaliza(t[3]) for t in linea]
        junto = "".join(palabras)
        if "NOFUEVENDIDO" in junto or "NOVENDIDO" in junto:
            res.append((linea[0][0], linea[0][1]))
    return res


def procesa_pdf(s, ruta, escritor):
    tmp = tempfile.mkdtemp(prefix="lnu_")
    filas = 0
    try:
        r = subprocess.run([PDFTOHTML, "-q", ruta, os.path.join(tmp, "h")],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                           timeout=120)
        if r.returncode != 0:
            return 0
        paginas = sorted(f for f in os.listdir(os.path.join(tmp, "h"))
                         if re.match(r"page\d+\.html$", f))
        for pagina in paginas:
            tokens = parsea_pagina(os.path.join(tmp, "h", pagina))
            cajas = [(x, y, texto) for x, y, tam, texto in tokens
                     if tam >= 20 and re.match(r"^\d{5}$", texto)]
            if not cajas:
                continue
            ciudades = candidatos_ciudad(tokens)
            no_vend = marcas_no_vendido(tokens)

            # regla direccional: la ciudad va DEBAJO de su numero, alineada
            # en x (|dx|<=90, 30<=dy<=320). Entre candidatas se prefiere la
            # no-ambigua mas cercana; entre ambiguas (posibles apellidos en
            # el bloque del concesionario) la MAS BAJA, que es la ciudad.
            usadas = set()
            for bx, by, numero in sorted(cajas, key=lambda c: c[1]):
                cands = []
                for ci, (cx, cy, ciudad) in enumerate(ciudades):
                    if ci in usadas:
                        continue
                    dy = cy - by
                    if abs(cx - bx) <= 45 and 30 <= dy <= 320:
                        cands.append((ciudad in AMBIGUOS, dy, ci, ciudad))
                if not cands:
                    continue
                limpias = [c for c in cands if not c[0]]
                if limpias:
                    _, dy, ci, ciudad = min(limpias, key=lambda c: c[1])
                else:
                    _, dy, ci, ciudad = max(cands, key=lambda c: c[1])
                usadas.add(ci)
                vendido = 1
                for nx, ny in no_vend:
                    if abs(nx - bx) <= 150 and 0 <= ny - by <= 320:
                        vendido = 0
                        break
                escritor.writerow([s, "pdf", numero, "", "",
                                   ciudad, MUNICIPIOS[ciudad], vendido])
                filas += 1
        return filas
    except subprocess.TimeoutExpired:
        return 0
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


# ---------- era HTML 2002-05 ----------

TIER_VIEJO = re.compile(
    r"(PRIMER\s+PREMIO|2do\.?\s*PREMIO|3er\.?\s*PREMIO|4to\.?\s*PREMIO|"
    r"5to\.?\s*PREMIO|SEGUNDO\s+PREMIO|TERCER\s+PREMIO)", re.I)
BLOQUE_VIEJO = re.compile(
    r"(\d{5})\s+([\d,]+\.\d{2})\s+(NO\s+)?VENDIDO\s+POR\s+EL\s+CONCESIONARIO"
    r"\s+(.{0,120}?)(?=(?:PRIMER|2do|3er|4to|5to|SEGUNDO|TERCER)|$)", re.I)


def procesa_html(s, ruta, escritor):
    t = open(ruta, encoding="latin-1").read()
    t = re.sub(r"<[^>]+>", " ", t)
    t = re.sub(r"&nbsp;?", " ", t)
    t = " ".join(t.split())
    filas = 0
    partes = TIER_VIEJO.split(t)
    for i in range(1, len(partes) - 1, 2):
        tier = re.sub(r"\W+", " ", partes[i]).strip().upper()
        m = BLOQUE_VIEJO.search(partes[i + 1])
        if not m:
            continue
        numero, monto, no_v, cola = m.groups()
        ciudad = None
        cola_n = normaliza(cola)
        for muni in MUNICIPIOS:
            if re.search(r"\b" + re.escape(muni) + r"\b", cola_n):
                if ciudad is None or len(muni) > len(ciudad):
                    ciudad = muni
        if not ciudad:
            continue
        escritor.writerow([s, "html", numero, tier,
                           monto.replace(",", ""), ciudad,
                           MUNICIPIOS[ciudad], 0 if no_v else 1])
        filas += 1
    return filas


def main():
    hechos = set()
    if os.path.exists(SAL):
        with open(SAL, encoding="ascii") as fh:
            for f in csv.reader(fh, delimiter="|"):
                if f and f[0].isdigit():
                    hechos.add(int(f[0]))
    modo = "a" if hechos else "w"
    with open(SAL, modo, newline="", encoding="ascii") as fh:
        escritor = csv.writer(fh, delimiter="|")
        if modo == "w":
            escritor.writerow(["sorteo", "fuente", "numero", "tier", "monto",
                               "ciudad", "departamento", "vendido"])
        pdfs = sorted(int(m.group(1))
                      for n in os.listdir(os.path.join(RAIZ, "Datos"))
                      for m in [re.match(r"^(\d{4})\.pdf$", n)] if m)
        total = 0
        for i, s in enumerate(pdfs, 1):
            if s in hechos:
                continue
            total += procesa_pdf(s, os.path.join(RAIZ, "Datos", "%d.pdf" % s),
                                 escritor)
            if i % 50 == 0:
                fh.flush()
                print("... %d/%d PDFs (%d ubicaciones)"
                      % (i, len(pdfs), total), flush=True)
        for nombre in sorted(os.listdir(HTML_DIR)):
            m = re.match(r"^(\d{4})\.html$", nombre)
            if not m or int(m.group(1)) in hechos or nombre == "1145.html":
                continue
            total += procesa_html(int(m.group(1)),
                                  os.path.join(HTML_DIR, nombre), escritor)
    print("Ubicaciones extraidas en esta corrida: %d -> %s" % (total, SAL))


if __name__ == "__main__":
    main()
