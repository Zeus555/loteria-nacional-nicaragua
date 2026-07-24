# Propuesta de Modernización — PRC Lotería Nacional

**Fecha:** 2026-07-19 · **Autor:** Claude Code (auditoría + propuesta) · **Estado:** borrador para aprobación

---

## 1. Diagnóstico (hallazgos verificados hoy)

| # | Hallazgo | Evidencia | Gravedad |
|---|----------|-----------|----------|
| 1 | **Ingesta rota desde 2026-07-16**: el sitio quitó `alt=""` de las `<img>` y el regex de `GetSorteos.awk` lo exigía → CSV con 0 filas, el .bat reporta "Fin" como si nada | CSVs de 0 bytes desde el 16-jul (y el 13-jul); HTML de hoy descarga bien (189 KB) | CRÍTICA — el sorteo 2288 (ya publicado) no se está capturando |
| 2 | **Emparejamiento corrido en 1**: el `.Info` del sorteo N enlaza el PDF del sorteo N-1. Verificado: `Lista-2286.pdf` contiene "SORTEO ORDINARIO Nº 2286" pero está referenciado por `2287.Info` | `.Info` de 2283–2287 todos corridos; causa: la lógica de acumulación de campos en `GetSorteos.awk` empareja el enlace PDF del bloque anterior con el número del bloque siguiente | CRÍTICA — PDFs recientes en `Datos\` pueden estar guardados con número de sorteo equivocado |
| 3 | **73 PDFs y 73 JPGs en 0 bytes** (descargas fallidas desde el sorteo ~2185, jamás reintentadas: el script solo comprueba `if not exist`) | Escaneo de `Datos\` e `Imagenes\`; el sitio SÍ los sirve hoy (probado: HTTP 200, 459 KB) | ALTA — recuperable |
| 4 | **179 sorteos sin PDF** en el rango 1356–2287 (bloque viejo ~1365–1400 de la era HTML + salteados recientes). Cobertura real con PDF válido: ~680 sorteos | Conteo de `Datos\`; `Documentación\Sorteos Viejos en HTML.txt` documenta la era pre-PDF | MEDIA |
| 5 | **Capa de estadísticas congelada desde 2017**: `GeneraEstadisticas.bat` apunta a rutas de Google Drive que ya no existen; ~7 años de sorteos sin procesar | Análisis previo (sesión de hoy) | MEDIA |
| 6 | **Sin base de datos**: todo vive en ficheros planos dispersos (Info, CSV, TXT de 11 MB) | — | La modernización lo resuelve |

**Estado del clúster rqlite (verificado hoy desde la laptop):** 9/9 nodos alcanzables, líder `node5` (sentinel010, 192.168.1.190:4001), API v10, base de datos vacía — lista para recibir el esquema.

---

## 2. Principios de la arquitectura propuesta

1. **El archivo binario es sagrado.** PDFs e imágenes nunca se sobrescriben ni borran (append-only). Cada fichero queda registrado con SHA-256 en la BD y un job de integridad lo verifica periódicamente. Espejo automático a una segunda ubicación (robocopy sin purga).
2. **Los BLOBs NO van a rqlite.** Raft replicaría ~450 MB a 9 teléfonos con almacenamiento limitado. A rqlite van metadatos, premios, calidad, catálogo y predicciones (~30–60 MB de SQLite: cómodo para el clúster).
3. **La verdad del número de sorteo se lee DENTRO del PDF**, nunca del nombre del fichero ni del HTML (lección del hallazgo #2).
4. **Toda la BD es re-derivable desde el archivo.** Si el clúster se pierde, se reconstruye desde los ficheros de D:.
5. **Ninguna etapa falla en silencio.** Extraer 0 filas = alerta, no "Fin" exitoso.
6. **Los AWK no se tiran**: quedan como segundo método de extracción para validación cruzada (la filosofía dual Vj/Nv que ya tenías, formalizada).

```
loterianacional.com.ni
        │  (sync diario: catálogo + PDF + JPG)
        ▼
┌──────────────────┐     espejo      ┌─────────────┐
│ Archivo en D:\   │ ──────────────► │ 2ª ubicación │
│ Datos/ Imagenes/ │                 └─────────────┘
└──────┬───────────┘
       │  extracción dual (pdfplumber + AWK legacy)
       ▼
┌──────────────────────────────────────────────┐
│ rqlite (9 nodos)                             │
│ sorteo · premio · archivo · calidad_sorteo   │
│ catalogo_web · prediccion · corrida          │
└──────┬───────────────────────┬───────────────┘
       │                       │
       ▼                       ▼
 Análisis de equidad     Chatbot WhatsApp (sentinel005)
 + sistema predictivo    "¿qué salió en el 2287?" — ya funciona
 + reportes HTML         con las tools esquema_bd/consultar_bd
```

---

## 3. Esquema de base de datos (rqlite / SQLite)

```sql
-- Catálogo maestro de sorteos (la fila existe aunque falten ficheros)
CREATE TABLE sorteo (
  num_sorteo   INTEGER PRIMARY KEY,
  tipo         TEXT,              -- ordinario | extraordinario
  fecha        TEXT,              -- ISO-8601, extraída del PDF
  nombre       TEXT,              -- p.ej. "Homenaje al Comandante Julio Buitrago"
  url_pdf      TEXT, url_img TEXT,
  fuente       TEXT,              -- pdf | html-viejo | manual
  creado_en    TEXT DEFAULT (datetime('now'))
);

-- Cada premio extraído de la lista oficial
CREATE TABLE premio (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  num_sorteo   INTEGER NOT NULL REFERENCES sorteo(num_sorteo),
  tipo_premio  TEXT NOT NULL,     -- MAYOR..SEXTO, aproximación, terminación...
  numero       TEXT NOT NULL,     -- billete (5 dígitos, como texto: conserva ceros)
  serie        TEXT,              -- 7 dígitos si aplica
  monto        REAL,
  metodo       TEXT NOT NULL,     -- pdfplumber | awk-table | awk-raw | manual
  confianza    REAL
);
CREATE INDEX idx_premio_sorteo ON premio(num_sorteo);
CREATE INDEX idx_premio_numero ON premio(numero);

-- Manifiesto de integridad del archivo binario
CREATE TABLE archivo (
  ruta            TEXT PRIMARY KEY,   -- relativa a la raíz del proyecto
  num_sorteo      INTEGER,
  tipo            TEXT,               -- pdf | jpg | info | txt-extraido
  sha256          TEXT,
  bytes           INTEGER,
  num_interno_pdf INTEGER,            -- lo que dice el PDF por dentro (hallazgo #2)
  descargado_en   TEXT, verificado_en TEXT,
  estado          TEXT                -- ok | corrupto | renombrado | faltante
);

-- Scorecard de calidad por sorteo
CREATE TABLE calidad_sorteo (
  num_sorteo          INTEGER PRIMARY KEY,
  tiene_pdf           INTEGER, tiene_img INTEGER, tiene_info INTEGER,
  nombre_coincide     INTEGER,  -- nombre de fichero == nº interno del PDF
  premios_extraidos   INTEGER, premios_esperados INTEGER,
  acuerdo_metodos     REAL,     -- % de filas idénticas entre métodos de extracción
  score               REAL,     -- 0..100
  detalle             TEXT,     -- JSON con los checks fallidos
  evaluado_en         TEXT
);

-- Snapshot diario de lo que publica la web (para detectar faltantes/cambios)
CREATE TABLE catalogo_web (
  capturado_en TEXT, num_sorteo INTEGER, url_pdf TEXT, url_img TEXT, fecha_txt TEXT,
  PRIMARY KEY (capturado_en, num_sorteo)
);

-- Correcciones manuales (migra Datos\Listado No Encontrados.txt)
CREATE TABLE no_encontrado (
  num_sorteo INTEGER, numero TEXT, tipo_premio TEXT, monto REAL, origen TEXT
);

-- Predicciones versionadas del sistema predictivo
CREATE TABLE prediccion (
  generado_en   TEXT, para_sorteo INTEGER, modelo TEXT,
  ambito        TEXT,   -- digito-pos-1..5 | numero-completo | terminacion
  valor         TEXT, probabilidad REAL,
  PRIMARY KEY (generado_en, para_sorteo, modelo, ambito, valor)
);

-- Auditoría de ejecuciones del pipeline
CREATE TABLE corrida (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  inicio TEXT, fin TEXT, comando TEXT, filas_procesadas INTEGER,
  ok INTEGER, detalle TEXT
);
```

**Escrituras:** `POST /db/execute` en lotes transaccionales de 500–1000 filas (carga inicial ~300 k filas de premios en minutos). **Lecturas:** `level=none` para dashboards/chatbot, `level=weak` para jobs de integridad. Cliente: Python `requests` puro o `pyrqlite`.

---

## 4. Plan por fases

### Fase 0 — Reparación urgente de la ingesta (hoy mismo)
- Corregir `GetSorteos.awk`: parseo por bloque (no acumulación global) para eliminar el corrimiento, y regex de imagen sin exigir `alt=""`.
- `curl -f` + validar cabecera `%PDF-` y tamaño > umbral antes de dar por buena una descarga; reintentar los 0-bytes.
- El .bat falla ruidosamente si el CSV sale vacío.
- Capturar el sorteo 2288 perdido.
- *Nota:* esto repara el sistema viejo para no perder datos mientras se construye el nuevo; el reemplazo llega en F2.

### Fase 1 — Cimientos: esquema en rqlite + carga de metadatos
- Crear el esquema anterior en el clúster.
- Script Python `loteria.py` (CLI única con subcomandos) — primer subcomando `load-metadata`: recorre `Datos\`, `Imagenes\`, `.Info`, CSVs históricos de `Temporal\` y puebla `sorteo`, `archivo` (con SHA-256), `catalogo_web`, `no_encontrado`.
- Requiere instalar CPython 3.12+ en la laptop (hay carpeta `D:\Herramientas\Python` pero no está en PATH).

### Fase 2 — Saneamiento y completitud del archivo (tu requisito: no perder ni un PDF ni una imagen)
- `loteria.py verify`: lee el nº interno de cada PDF (`pdftotext` ya disponible vía Git; o pdfplumber) y lo compara con el nombre → tabla de mapeo real. Los mal nombrados se **copian** al nombre correcto y el original va a `Cuarentena\` (nunca se borra nada).
- `loteria.py redownload`: re-descarga los 73 PDFs y 73 JPGs corruptos (verificado que el sitio los sirve).
- `loteria.py gaps`: lista faltantes = catálogo ∪ rango − archivo válido. Recuperación en 3 frentes: (a) patrón de URL WordPress `uploads/AAAA/MM/Lista-NNNN.pdf` sondeando meses cercanos a la fecha estimada, (b) Wayback Machine, (c) era HTML vieja (`Sorteos Viejos en HTML.txt`).
- Espejo: robocopy programado de `Datos\` + `Imagenes\` a segunda ubicación (decidir destino).

### Fase 3 — Extracción de premios v2
- Parser Python (pdfplumber, modo tabla) + los dos AWK legacy adaptados como métodos de contraste.
- Carga a `premio` con `metodo` y `confianza`; discrepancias entre métodos → cola de revisión.
- Procesa los ~7 años pendientes (2019–2026) y reprocesa lo viejo para tener una sola base homogénea.

### Fase 4 — Calidad de datos (tu requisito)
- `loteria.py quality`: puebla `calidad_sorteo` con: completitud de ficheros, nombre vs nº interno, nº de premios extraídos vs plan de premios oficial, suma de montos, duplicados, dígitos malformados, % acuerdo entre métodos.
- Informe HTML con semáforo por sorteo + totales; los rojos alimentan la cola de reproceso.
- Sustituye y supera las hojas "Calidad de Datos.ods" de 2017.

### Fase 5 — Análisis de probabilidad y equidad (¿está arreglada?)
Batería estadística sobre todos los premios, global y por tipo de premio:
- **Chi-cuadrado de uniformidad** por posición de dígito (5 posiciones × 10 dígitos) y por prefijo/terminación.
- **Kolmogorov–Smirnov** del número completo contra U(00000–99999).
- **Test de rachas** (par/impar, alto/bajo) y **entropía** por posición.
- **Autocorrelación** entre sorteos consecutivos y **análisis de huecos** (¿cuánto tarda en repetirse un número vs lo esperado?).
- **Deriva temporal** (CUSUM / ventanas móviles): ¿cambió el comportamiento en algún período o cambio de tómbola?
- **Corrección por comparaciones múltiples** (Benjamini–Hochberg): con tantos tests, algunos p<0.05 aparecen por azar; sin esto el informe mentiría.
- Entregable: **Informe de Equidad** con veredicto honesto por tipo de premio: p-values, tamaños de efecto y qué significaría cada desviación.

### Fase 6 — Sistema predictivo (honesto)
- Modelos: posterior Dirichlet-multinomial por posición de dígito, cadenas de Markov de transición entre sorteos, gradient boosting sobre features (huecos, frecuencias, calendario), y opcionalmente una red pequeña (heredera de tu `Test Iniciadores.ipynb` de 2017).
- **Backtesting walk-forward** contra la línea base uniforme (log-loss / Brier): cada modelo debe demostrar su ventaja sobre el azar con datos que no vio.
- Salidas: tabla `prediccion` con probabilidades por dígito/número para el próximo sorteo + **análisis de valor esperado** por tipo de billete (qué fracción del precio se recupera en premios y qué tipos de premio la componen).
- **Compromiso de honestidad:** si la Fase 5 concluye que los sorteos son justos, ningún modelo puede superar al azar — y este sistema lo va a decir explícitamente con números, en vez de vender humo. Su valor entonces es cuantificar el EV real de cada billete y demostrar la equidad. Si detecta sesgos explotables, los cuantifica con su ganancia esperada.

### Fase 7 — Operación continua
- Tarea programada diaria única: `loteria.py daily` = sync → verify → extract → load → quality, todo registrado en `corrida`.
- Alertas cuando algo produce 0 filas o baja el score de calidad (log + opcionalmente mensaje por el chatbot de WhatsApp de sentinel005).
- Bonus sin esfuerzo: el chatbot ya consulta el clúster → "¿qué números ganaron el sorteo 2287?" funcionará por WhatsApp en cuanto existan las tablas.

---

## 5. Decisiones abiertas (recomendación marcada)

1. **¿Dónde corre el pipeline?** → **Laptop (recomendado)**: los ficheros viven en D: y el clúster es solo BD. Alternativa: un nodo Ubuntu (sentinel014/016), pero habría que mover/montar el archivo.
2. **¿Destino del espejo del archivo?** → segundo disco local, NAS o nube. Pendiente de qué tengas disponible.
3. **¿Lenguaje del pipeline nuevo?** → **Python (recomendado)** por pdfplumber/scipy/sklearn; los AWK quedan como contraste. Alternativa purista: seguir en AWK+curl, pero las fases 5–6 lo hacen inviable.
4. **Prioridad de fases** → propuesta: F0 ya, luego F1→F2→F3→F4 (la base analítica), y F5→F6 (el análisis) al final con datos limpios. F2 antes que F3 para no analizar PDFs mal etiquetados.

## 6. Estimación de esfuerzo

| Fase | Esfuerzo estimado |
|------|-------------------|
| F0 Reparación urgente | 1 sesión corta |
| F1 Esquema + carga metadatos | 1 sesión |
| F2 Saneamiento + faltantes | 1–2 sesiones (+ tiempo de descarga) |
| F3 Extracción v2 (histórico completo) | 2 sesiones |
| F4 Calidad | 1 sesión |
| F5 Equidad | 1–2 sesiones |
| F6 Predictivo + backtesting | 2–3 sesiones |
| F7 Operación | 1 sesión |
