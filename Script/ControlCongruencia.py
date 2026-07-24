"""ControlCongruencia.py - Control de calidad: jerarquia de premios coherente.

Regla de negocio: en cada sorteo MAYOR > SEGUNDO > TERCER >= CUARTO >= QUINTO
>= SEXTO (los montos de un premio superior nunca pueden ser menores que los del
inferior; puede haber varios ganadores del mismo nivel con igual monto).

Diagnostico de causas conocidas:
  - El banner del pote ("PREMIO MAYOR ... MILLONES") etiqueta como MAYOR al
    numero de cuadricula mas cercano -> MAYOR con monto de C$1,000-3,000.
  - Una etiqueta de caja puede caer sobre un numero de cuadricula vecino.
El arbitro imparcial del MAYOR es el canal NOTA (ultimos 4 digitos del mayor).

Uso:
  python ControlCongruencia.py            # reporte de violaciones
  python ControlCongruencia.py --corrige  # ademas emite Resultados/CongruenciaCorrecciones.csv

La correccion la aplica el paso correspondiente de TareaDiaria/PowerShell.
Python 3.7 stdlib.
"""
import csv
import json
import os
import sys
from collections import defaultdict

RAIZ = r"D:\PRC Loteria Nacional"
EXTRACCION = os.path.join(RAIZ, "Resultados", "ExtraccionV2.csv")
RELLENOS = os.path.join(RAIZ, "Resultados", "Conciliacion_Rellenos_20260720.csv")
NOTAS = os.path.join(RAIZ, "Resultados", "NotasMayor.csv")
CONTRASTE = os.path.join(RAIZ, "Resultados", "EstadisticasLoteria2.txt")
SAL_CORR = os.path.join(RAIZ, "Resultados", "CongruenciaCorrecciones.csv")
SAL_REP = os.path.join(RAIZ, "Resultados", "CongruenciaReporte.json")

ORDEN = ["MAYOR", "SEGUNDO", "TERCER", "CUARTO", "QUINTO", "SEXTO"]
# Un monto etiquetado como premio destacado que no supere este umbral es en
# realidad un numero de cuadricula mal etiquetado (contaminacion del banner).
UMBRAL_DESTACADO = 30000.0


def carga():
    filas = defaultdict(list)           # sorteo -> [ [tipo, numero, monto], ... ]
    with open(EXTRACCION, encoding="ascii", errors="replace") as fh:
        for f in csv.reader(fh, delimiter="|"):
            if not f or not f[0].isdigit() or len(f) < 5:
                continue
            monto = float(f[3]) if f[3] else None
            filas[int(f[0])].append([f[1], f[2], monto])
    # Refleja las conciliaciones aplicadas en la BD (monto+tipo de awk-raw).
    if os.path.exists(RELLENOS):
        with open(RELLENOS, encoding="ascii", errors="replace") as fh:
            for f in csv.reader(fh, delimiter="|"):
                if len(f) < 4 or not f[0].isdigit():
                    continue
                s = int(f[0])
                for fila in filas.get(s, []):
                    if fila[1] == f[1] and fila[2] is None:
                        fila[2] = float(f[2])
                        fila[0] = f[3]
                        break
    notas = {}
    if os.path.exists(NOTAS):
        with open(NOTAS, encoding="ascii", errors="replace") as fh:
            for f in csv.reader(fh, delimiter="|"):
                if len(f) >= 2 and f[0].isdigit() and len(f[1]) == 4 and f[1].isdigit():
                    notas[int(f[0])] = f[1]
    # Metodo de contraste (awk 2017): sorteo|numero -> monto maximo visto.
    contraste = {}
    if os.path.exists(CONTRASTE):
        with open(CONTRASTE, encoding="ascii", errors="replace") as fh:
            for f in csv.reader(fh, delimiter="|"):
                if len(f) >= 4 and f[0].strip().isdigit():
                    clave = (int(f[0]), f[2].strip())
                    try:
                        m = float(f[3])
                    except ValueError:
                        continue
                    if clave not in contraste or m > contraste[clave]:
                        contraste[clave] = m
    return filas, notas, contraste


def analiza(filas, notas, contraste, corrige):
    viol = defaultdict(list)            # tipo_violacion -> [sorteo, ...]
    correcciones = []                   # (sorteo, numero, tipo_actual, tipo_nuevo, causa)
    sorteos_rotos_despues = []

    for s in sorted(filas):
        rows = filas[s]
        term4 = notas.get(s)

        # --- Correccion 1: etiquetas MAYOR que no casan con la NOTA ---
        for r in rows:
            if r[0] == "MAYOR" and term4 and not r[1].endswith(term4):
                viol["mayor_contra_nota"].append(s)
                if r[2] is not None and r[2] <= UMBRAL_DESTACADO:
                    correcciones.append((s, r[1], "MAYOR", "Ordinario",
                                         "banner: monto de cuadricula"))
                else:
                    # Etiqueta MAYOR demostrablemente falsa (la nota manda),
                    # pero el nivel real se desconoce: etiqueta neutral y a
                    # la cola de revision.
                    correcciones.append((s, r[1], "MAYOR", "Destacado",
                                         "REVISAR: mayor falso, nivel real por determinar"))

        # --- Correccion 2: el numero de la NOTA debe ser el MAYOR ---
        # Ojo: otros billetes comparten los 4 digitos finales (ganadores por
        # terminacion, montos pequenos). El mayor real es el candidato con
        # monto destacado, o sin monto (cuando el monto es arte grafico).
        if term4:
            cands = [r for r in rows if r[1].endswith(term4)
                     and (r[2] is None or r[2] > UMBRAL_DESTACADO)]
            con_monto = [r for r in cands if r[2] is not None]
            elegido = None
            if len(con_monto) == 1:
                elegido = con_monto[0]
            elif not con_monto and len(cands) == 1:
                elegido = cands[0]
            if elegido is not None and elegido[0] != "MAYOR":
                correcciones.append((s, elegido[1], elegido[0], "MAYOR",
                                     "casa con la nota (monto destacado o grafico)"))

        # --- Correccion 3: etiquetas de caja sobre montos de cuadricula ---
        for r in rows:
            if (r[0] in ORDEN[1:] and r[2] is not None
                    and r[2] <= UMBRAL_DESTACADO):
                viol["caja_sobre_cuadricula"].append(s)
                correcciones.append((s, r[1], r[0], "Ordinario",
                                     "etiqueta de caja con monto de cuadricula"))

    # --- Aplica C1-C3 en memoria ---
    mapa_corr = {(s, n, ta): tn for s, n, ta, tn, _ in correcciones}
    for s in filas:
        for r in filas[s]:
            nuevo = mapa_corr.get((s, r[1], r[0]))
            if nuevo:
                r[0] = nuevo

    # --- Correccion 4: etiquetas de caja PERMUTADAS ---
    # Los montos vienen del emparejado (validado 98.9%); las etiquetas, de la
    # cercania a la caja (fragil). Si el conjunto de premios destacados de un
    # sorteo tiene las etiquetas desordenadas respecto a sus montos, se
    # reordenan las mismas etiquetas por monto descendente.
    for s in sorted(filas):
        destacados = [r for r in filas[s]
                      if r[0] in ORDEN and r[2] is not None
                      and r[2] > UMBRAL_DESTACADO]
        if len(destacados) < 2:
            continue
        etiquetas = sorted((r[0] for r in destacados), key=ORDEN.index)
        por_monto = sorted(destacados, key=lambda r: -r[2])
        cambiado = False
        for r, et in zip(por_monto, etiquetas):
            if r[0] != et:
                correcciones.append((s, r[1], r[0], et,
                                     "reorden por monto (etiquetas permutadas)"))
                viol["etiquetas_permutadas"].append(s)
                r[0] = et
                cambiado = True

    # --- Correccion 5: MAYOR con monto de cuadricula (emparejado mal en
    #     layouts viejos). El contraste awk tiene el monto real; sin
    #     contraste, el monto se anula (mejor NULL honesto que un valor
    #     incongruente) ---
    for s in sorted(filas):
        inferior_max = max((r[2] for r in filas[s]
                            if r[0] in ORDEN[1:] and r[2] is not None),
                           default=None)
        if inferior_max is None:
            continue
        for r in filas[s]:
            if r[0] != "MAYOR" or r[2] is None or r[2] >= inferior_max:
                continue
            viol["mayor_monto_incongruente"].append(s)
            awk = contraste.get((s, r[1]))
            if awk is not None and awk > inferior_max:
                correcciones.append((s, r[1], "monto:%.2f" % r[2],
                                     "monto:%.2f" % awk,
                                     "monto del contraste awk (jerarquia)"))
                r[2] = awk
            else:
                correcciones.append((s, r[1], "monto:%.2f" % r[2], "monto:NULL",
                                     "monto incongruente sin contraste"))
                r[2] = None

    # --- Evaluacion final de jerarquia: todo monto del nivel superior debe
    #     ser >= que todo monto del nivel inferior ---
    for s in sorted(filas):
        tiers = {}
        for tipo, numero, monto in filas[s]:
            if tipo in ORDEN and monto is not None:
                tiers.setdefault(tipo, []).append(monto)
        presentes = [t for t in ORDEN if t in tiers]
        roto = False
        for a, b in zip(presentes, presentes[1:]):
            if max(tiers[b]) > min(tiers[a]):
                roto = True
                viol["jerarquia_rota"].append(
                    "%d: %s C$%.0f > %s C$%.0f"
                    % (s, b, max(tiers[b]), a, min(tiers[a])))
        if roto:
            sorteos_rotos_despues.append(s)

    return viol, correcciones, sorteos_rotos_despues


def main():
    corrige = "--corrige" in sys.argv
    filas, notas, contraste = carga()
    viol, correcciones, rotos = analiza(filas, notas, contraste, corrige)

    print("Sorteos analizados: %d (con nota del mayor: %d)" % (len(filas), len(notas)))
    print()
    print("Violaciones detectadas:")
    print("  MAYOR que no casa con la NOTA: %d filas en %d sorteos"
          % (len(viol["mayor_contra_nota"]), len(set(viol["mayor_contra_nota"]))))
    print("  etiqueta de caja sobre monto de cuadricula: %d filas en %d sorteos"
          % (len(viol["caja_sobre_cuadricula"]), len(set(viol["caja_sobre_cuadricula"]))))
    print("  etiquetas de caja permutadas: %d filas en %d sorteos"
          % (len(viol["etiquetas_permutadas"]), len(set(viol["etiquetas_permutadas"]))))
    print("  MAYOR con monto incongruente: %d sorteos"
          % len(set(viol["mayor_monto_incongruente"])))
    auto = [c for c in correcciones if not c[4].startswith("REVISAR")]
    rev = [c for c in correcciones if c[4].startswith("REVISAR")]
    print()
    print("Correcciones automaticas (con evidencia): %d" % len(auto))
    print("Casos para revision manual: %d" % len(rev))
    for c in rev[:10]:
        print("   REVISAR sorteo %d numero %s (%s): %s" % (c[0], c[1], c[2], c[4]))
    print()
    print("Jerarquia rota DESPUES de correcciones: %d sorteos" % len(rotos))
    for v in viol["jerarquia_rota"][:12]:
        print("   " + v)

    with open(SAL_REP, "w", encoding="ascii") as fh:
        json.dump({
            "sorteos": len(filas),
            "mayor_contra_nota": len(set(viol["mayor_contra_nota"])),
            "caja_sobre_cuadricula": len(set(viol["caja_sobre_cuadricula"])),
            "correcciones_auto": len(auto),
            "revision_manual": [list(c) for c in rev],
            "jerarquia_rota_despues": viol["jerarquia_rota"],
        }, fh, indent=1)
    print()
    print("Reporte:", SAL_REP)

    if corrige:
        # Se emiten TODAS las correcciones (las de revision tambien se aplican
        # como 'Destacado'; su nivel real queda anotado en el reporte JSON).
        with open(SAL_CORR, "w", newline="", encoding="ascii") as fh:
            w = csv.writer(fh, delimiter="|")
            w.writerow(["sorteo", "numero", "actual", "nuevo", "causa"])
            for c in correcciones:
                w.writerow(c)
        print("Correcciones:", SAL_CORR)


if __name__ == "__main__":
    main()
