-- Esquema del proyecto PRC Loteria Nacional en el cluster rqlite.
-- Creado en Fase 1 (2026-07-19). Ver Docs\Propuesta Modernizacion 2026-07.md

CREATE TABLE IF NOT EXISTS sorteo (
  num_sorteo   INTEGER PRIMARY KEY,
  tipo         TEXT,
  fecha        TEXT,
  fecha_txt    TEXT,
  nombre       TEXT,
  url_pdf      TEXT,
  url_img      TEXT,
  fuente       TEXT,
  creado_en    TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS premio (
  id           INTEGER PRIMARY KEY,
  num_sorteo   INTEGER NOT NULL,
  tipo_premio  TEXT NOT NULL,
  numero       TEXT NOT NULL,
  serie        TEXT,
  monto        REAL,
  metodo       TEXT NOT NULL,
  confianza    REAL
);
CREATE INDEX IF NOT EXISTS idx_premio_sorteo ON premio(num_sorteo);
CREATE INDEX IF NOT EXISTS idx_premio_numero ON premio(numero);

CREATE TABLE IF NOT EXISTS archivo (
  ruta            TEXT PRIMARY KEY,
  num_sorteo      INTEGER,
  tipo            TEXT,
  sha256          TEXT,
  bytes           INTEGER,
  num_interno_pdf INTEGER,
  descargado_en   TEXT,
  verificado_en   TEXT,
  estado          TEXT
);
CREATE INDEX IF NOT EXISTS idx_archivo_sorteo ON archivo(num_sorteo);

CREATE TABLE IF NOT EXISTS calidad_sorteo (
  num_sorteo          INTEGER PRIMARY KEY,
  tiene_pdf           INTEGER,
  tiene_img           INTEGER,
  tiene_info          INTEGER,
  nombre_coincide     INTEGER,
  premios_extraidos   INTEGER,
  premios_esperados   INTEGER,
  acuerdo_metodos     REAL,
  score               REAL,
  detalle             TEXT,
  evaluado_en         TEXT
);

CREATE TABLE IF NOT EXISTS catalogo_web (
  capturado_en TEXT,
  num_sorteo   INTEGER,
  url_pdf      TEXT,
  url_img      TEXT,
  fecha_txt    TEXT,
  PRIMARY KEY (capturado_en, num_sorteo)
);

CREATE TABLE IF NOT EXISTS no_encontrado (
  num_sorteo  INTEGER,
  numero      TEXT,
  monto       REAL,
  tipo_premio TEXT,
  origen      TEXT
);

CREATE TABLE IF NOT EXISTS prediccion (
  generado_en   TEXT,
  para_sorteo   INTEGER,
  modelo        TEXT,
  ambito        TEXT,
  valor         TEXT,
  probabilidad  REAL,
  PRIMARY KEY (generado_en, para_sorteo, modelo, ambito, valor)
);

CREATE TABLE IF NOT EXISTS corrida (
  id                INTEGER PRIMARY KEY,
  inicio            TEXT,
  fin               TEXT,
  comando           TEXT,
  filas_procesadas  INTEGER,
  ok                INTEGER,
  detalle           TEXT
);
