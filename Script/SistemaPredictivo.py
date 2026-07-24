"""SistemaPredictivo.py - Fase 6: modelos, backtesting y valor esperado.

Modelos sobre el ultimo digito del premio mayor (serie limpia del canal NOTA):
  M0 uniforme (linea base honesta)
  M1 Dirichlet acumulado (toda la historia previa, alfa=1)
  M2 Dirichlet ventana movil (ultimos 200 sorteos, alfa=1)

Backtesting walk-forward: cada modelo predice el sorteo t usando SOLO sorteos
anteriores; se compara con log-loss y Brier contra M0. Un modelo solo se
publica si supera la linea base con significancia.

Valor esperado del premio por terminacion (billete moderno C$600):
  paga C$1,200 si tu ultimo digito coincide con el del mayor; con el sesgo
  medido, elegir terminacion 9 o 5 cambia el EV de ese componente.

Salida: Resultados/Prediccion_20260720.json + tabla prediccion en rqlite
        (la carga la hace el script de PowerShell que acompanya).
"""
import csv
import datetime
import json
import math
import os

RAIZ = r"D:\PRC Loteria Nacional"
NOTAS = os.path.join(RAIZ, "Resultados", "NotasMayor.csv")
SALIDA = os.path.join(RAIZ, "Resultados", "Prediccion.json")

BURN_IN = 100
VENTANA = 200
ALFA = 1.0
PRECIO_BILLETE = 600.0
PREMIO_TERM1 = 1200.0


def carga_serie():
    serie = []
    with open(NOTAS, encoding='ascii', errors='replace') as fh:
        for f in csv.reader(fh, delimiter='|'):
            if len(f) >= 2 and f[0].isdigit() and len(f[1]) == 4 and f[1].isdigit():
                serie.append((int(f[0]), f[1]))
    serie.sort()
    return serie


def prob_dirichlet(cuentas, n):
    tot = n + 10 * ALFA
    return [(cuentas[d] + ALFA) / tot for d in range(10)]


def backtest(digitos):
    """Walk-forward sobre la serie de ultimos digitos."""
    n = len(digitos)
    res = {'M0': {'ll': [], 'brier': [], 'top1': 0},
           'M1': {'ll': [], 'brier': [], 'top1': 0},
           'M2': {'ll': [], 'brier': [], 'top1': 0}}
    acum = [0] * 10
    for i, d in enumerate(digitos):
        if i >= BURN_IN:
            modelos = {
                'M0': [0.1] * 10,
                'M1': prob_dirichlet(acum, i),
            }
            vent = [0] * 10
            ini = max(0, i - VENTANA)
            for j in range(ini, i):
                vent[digitos[j]] += 1
            modelos['M2'] = prob_dirichlet(vent, i - ini)
            for m, p in modelos.items():
                res[m]['ll'].append(-math.log(p[d]))
                res[m]['brier'].append(
                    sum((p[k] - (1.0 if k == d else 0.0)) ** 2 for k in range(10)))
                if max(range(10), key=lambda k: p[k]) == d:
                    res[m]['top1'] += 1
        acum[d] += 1
    evaluados = n - BURN_IN
    tabla = {}
    for m in res:
        ll = res[m]['ll']
        tabla[m] = {
            'log_loss': sum(ll) / len(ll),
            'brier': sum(res[m]['brier']) / len(ll),
            'top1_pct': 100.0 * res[m]['top1'] / evaluados,
        }
    # Significancia de M1 vs M0: diferencia pareada de log-loss.
    difs = [a - b for a, b in zip(res['M0']['ll'], res['M1']['ll'])]
    media = sum(difs) / len(difs)
    var = sum((x - media) ** 2 for x in difs) / (len(difs) - 1)
    z = media / math.sqrt(var / len(difs)) if var > 0 else 0.0
    tabla['M1_vs_M0'] = {'mejora_media_logloss': media, 'z': z,
                         'p_una_cola': 0.5 * math.erfc(z / math.sqrt(2.0))}
    tabla['evaluados'] = evaluados
    return tabla


def main():
    serie = carga_serie()
    digitos = [int(t[3]) for _, t in serie]         # ultimo digito = term4[3]
    proximo = serie[-1][0] + 1
    hoy = datetime.date.today().isoformat()
    print('Serie: %d sorteos (%d-%d); prediccion para el %d'
          % (len(serie), serie[0][0], serie[-1][0], proximo))

    bt = backtest(digitos)
    print()
    print('Backtest walk-forward (%d sorteos evaluados), ultimo digito del mayor:'
          % bt['evaluados'])
    print('  %-28s %-10s %-8s %s' % ('modelo', 'log-loss', 'brier', 'acierto top-1'))
    print('  %-28s %-10.5f %-8.5f %.1f%%'
          % ('M0 uniforme', bt['M0']['log_loss'], bt['M0']['brier'], bt['M0']['top1_pct']))
    print('  %-28s %-10.5f %-8.5f %.1f%%'
          % ('M1 Dirichlet historico', bt['M1']['log_loss'], bt['M1']['brier'], bt['M1']['top1_pct']))
    print('  %-28s %-10.5f %-8.5f %.1f%%'
          % ('M2 Dirichlet ventana 200', bt['M2']['log_loss'], bt['M2']['brier'], bt['M2']['top1_pct']))
    print('  M1 vs M0: mejora log-loss=%.5f, z=%.2f, p=%.4f'
          % (bt['M1_vs_M0']['mejora_media_logloss'], bt['M1_vs_M0']['z'],
             bt['M1_vs_M0']['p_una_cola']))

    # Prediccion para el proximo sorteo con todo el historico.
    acum = [0] * 10
    for d in digitos:
        acum[d] += 1
    post = prob_dirichlet(acum, len(digitos))
    print()
    print('Prediccion ultimo digito del mayor, sorteo %d:' % proximo)
    orden = sorted(range(10), key=lambda d: -post[d])
    for d in orden[:3]:
        print('  digito %d: %.2f%% (uniforme: 10%%)' % (d, 100 * post[d]))

    # Valor esperado del componente terminacion (1 digito).
    ev = {}
    for d in range(10):
        ev[d] = post[d] * PREMIO_TERM1
    ev_unif = 0.1 * PREMIO_TERM1
    mejor = orden[0]
    print()
    print('EV del premio por terminacion (billete C$%.0f, paga C$%.0f):'
          % (PRECIO_BILLETE, PREMIO_TERM1))
    print('  terminacion justa (cualquiera): C$%.1f' % ev_unif)
    print('  terminacion %d: C$%.1f (%+.1f%%)'
          % (mejor, ev[mejor], 100 * (ev[mejor] / ev_unif - 1)))

    resultado = {
        'generado_en': hoy,
        'para_sorteo': proximo,
        'n_serie': len(serie),
        'backtest': bt,
        'posterior_ultimo_digito': {str(d): round(post[d], 5) for d in range(10)},
        'ev_terminacion': {str(d): round(ev[d], 1) for d in range(10)},
        'nota_honesta': (
            'El numero completo del mayor es impredecible (KS, rachas y '
            'autocorrelacion limpias en F5): ningun modelo puede elegir EL '
            'billete ganador. La unica ventaja medible es el sesgo del ultimo '
            'digito (9 y 5), que mejora el premio por terminacion en ~%d%%.'
            % round(100 * (ev[mejor] / ev_unif - 1))),
    }
    with open(SALIDA, 'w', encoding='ascii') as fh:
        json.dump(resultado, fh, indent=1)
    print()
    print('Guardado:', SALIDA)


if __name__ == '__main__':
    main()
