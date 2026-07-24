# CargaRqlite.ps1 - Fase 1: carga el archivo historico de la Loteria Nacional al cluster rqlite.
# Uso:  powershell -File CargaRqlite.ps1 -Etapas esquema,archivos,sorteos,premios,extras,verifica
# Idempotente: usa INSERT OR REPLACE / DELETE previo por metodo. ASCII puro a proposito (PS 5.1).

param(
  [string[]]$Etapas = @("verifica"),
  [string]$DirRaiz = "D:\PRC Loteria Nacional",
  [string[]]$Semillas = @("192.168.1.190","192.168.1.124","192.168.1.69","192.168.1.252"),
  [int]$TamLote = 1000
)

$ErrorActionPreference = "Stop"
$script:FilasTotales = 0

# Con -File los parametros llegan como un solo string: "esquema,verifica".
$Etapas = @($Etapas | ForEach-Object { $_ -split "," } | Where-Object { $_ })

# ---------- descubrir lider ----------
function Get-RqliteUrl {
  foreach ($ip in $Semillas) {
    try {
      $st = Invoke-RestMethod "http://${ip}:4001/status" -TimeoutSec 6
      $raft = $st.store.leader.addr           # ej: 192.168.1.124:4002
      $lider = ($raft -split ":")[0]
      Write-Host "Lider rqlite: $lider (via semilla $ip)"
      return "http://${lider}:4001"
    } catch { continue }
  }
  throw "Ningun nodo semilla de rqlite responde."
}

# ---------- ejecutar lote de sentencias ----------
function Invoke-Rq([string[]]$Sentencias, [switch]$Transaccion) {
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.Append("[")
  for ($i = 0; $i -lt $Sentencias.Count; $i++) {
    if ($i) { [void]$sb.Append(",") }
    $e = $Sentencias[$i].Replace("\", "\\").Replace('"', '\"').Replace("`r", "").Replace("`n", "\n")
    [void]$sb.Append('"').Append($e).Append('"')
  }
  [void]$sb.Append("]")
  $q = if ($Transaccion) { "?transaction" } else { "" }
  $r = Invoke-RestMethod -Method Post -Uri "$script:RqUrl/db/execute$q" -Body $sb.ToString() -ContentType "application/json; charset=utf-8" -TimeoutSec 300
  foreach ($res in $r.results) {
    if ($res.error) { throw "rqlite: $($res.error)" }
  }
  return $r
}

function Invoke-RqQuery([string]$Sql, [string]$Nivel = "weak") {
  $r = Invoke-RestMethod -Method Get -Uri "$script:RqUrl/db/query?level=$Nivel&q=$([uri]::EscapeDataString($Sql))" -TimeoutSec 60
  if ($r.results[0].error) { throw "rqlite: $($r.results[0].error)" }
  return $r.results[0]
}

function Esc([string]$t) { if ($null -eq $t) { return "NULL" }; "'" + $t.Replace("'", "''") + "'" }

# ---------- utilidades de datos ----------
$MesES = @{ enero=1; febrero=2; marzo=3; abril=4; mayo=5; junio=6; julio=7; agosto=8; septiembre=9; octubre=10; noviembre=11; diciembre=12 }
function FechaIso([string]$txt) {
  if ($txt -match '(\d{1,2}) de ([A-Za-z]+) (\d{4})') {
    $m = $MesES[$Matches[2].ToLower()]
    if ($m) { return ("{0}-{1:d2}-{2:d2}" -f $Matches[3], $m, [int]$Matches[1]) }
  }
  return $null
}

# Cosecha URLs de PDF/imagen y fechas de todos los CSV historicos y ficheros .Info.
function Get-Cosecha {
  $c = @{ pdf = @{}; img = @{}; fecha = @{} }
  $fuentes = @(Get-ChildItem "$DirRaiz\Temporal\*_Sorteos.csv" -ErrorAction SilentlyContinue) + @(Get-ChildItem "$DirRaiz\Datos\*.Info" -ErrorAction SilentlyContinue)
  foreach ($f in $fuentes) {
    foreach ($lin in (Get-Content $f.FullName -ErrorAction SilentlyContinue)) {
      foreach ($m in [regex]::Matches($lin, 'https://www\.loterianacional\.com\.ni/wp-content/uploads/\d{4}/\d{2}/Lista-(\d{4})\.pdf')) {
        $c.pdf[[int]$m.Groups[1].Value] = $m.Value
      }
      foreach ($m in [regex]::Matches($lin, 'https://www\.loterianacional\.com\.ni/wp-content/uploads/\d{4}/\d{2}/(\d{4})[^@"\s]*\.jpg')) {
        $c.img[[int]$m.Groups[1].Value] = $m.Value
      }
      if ($lin -match '^(\d{4})@[^@]*@(\d{1,2} de [A-Za-z]+ \d{4})@') {
        $c.fecha[[int]$Matches[1]] = $Matches[2]
      }
    }
  }
  return $c
}

# ---------- etapas ----------
function Etapa-Esquema {
  Write-Host "== Esquema =="
  $sql = (Get-Content "$DirRaiz\Script\EsquemaRqlite.sql" | Where-Object { $_ -notmatch '^\s*--' }) -join "`n"
  $stmts = ($sql -split ";") | ForEach-Object { $_.Trim() } | Where-Object { $_ -and $_.Length -gt 5 }
  Invoke-Rq $stmts | Out-Null
  Write-Host "   $($stmts.Count) sentencias DDL aplicadas."
}

function Get-CsvVerificacion {
  $c = Get-ChildItem "$DirRaiz\Resultados\VerificacionPDFs_*.csv" -ErrorAction SilentlyContinue | Sort-Object Name | Select-Object -Last 1
  if ($c) { return $c.FullName }
  return $null
}

function Etapa-Archivos {
  Write-Host "== Archivos (SHA-256 + verificacion) =="
  $verif = @{}
  $csv = Get-CsvVerificacion
  if ($csv) { Write-Host "   usando $csv"; Import-Csv $csv | ForEach-Object { $verif[$_.archivo] = $_ } }
  $hoy = (Get-Date).ToString("s")
  $lote = New-Object System.Collections.Generic.List[string]
  $grupos = @(
    @{ dir = "Datos";    filtro = "*.pdf";  tipo = "pdf"  },
    @{ dir = "Datos";    filtro = "*.Info"; tipo = "info" },
    @{ dir = "Imagenes"; filtro = "*.jpg";  tipo = "jpg"  }
  )
  $n = 0
  foreach ($g in $grupos) {
    foreach ($f in (Get-ChildItem "$DirRaiz\$($g.dir)\$($g.filtro)" -ErrorAction SilentlyContinue)) {
      $num = "NULL"; if ($f.BaseName -match '^\d+$') { $num = [int]$f.BaseName }
      $sha = "NULL"; if ($f.Length -gt 0) { $sha = Esc (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash }
      $interno = "NULL"; $estado = "ok"
      if ($f.Length -eq 0) { $estado = "corrupto" }
      elseif ($g.tipo -eq "pdf" -and $verif.ContainsKey($f.BaseName)) {
        $v = $verif[$f.BaseName]
        if ($v.interno) { $interno = [int]$v.interno }
        $estado = switch ($v.estado) { "ok" { "ok" } "DESAJUSTE" { "desajuste" } "sin_texto" { "sin_texto" } "sin_encabezado" { "sin_encabezado" } default { "ok" } }
      }
      $ruta = "$($g.dir)\$($f.Name)"
      $lote.Add("INSERT OR REPLACE INTO archivo (ruta,num_sorteo,tipo,sha256,bytes,num_interno_pdf,descargado_en,verificado_en,estado) VALUES ($(Esc $ruta),$num,$(Esc $g.tipo),$sha,$($f.Length),$interno,$(Esc ($f.LastWriteTime.ToString('s'))),$(Esc $hoy),$(Esc $estado))")
      $n++
      if ($lote.Count -ge $TamLote) { Invoke-Rq $lote.ToArray() -Transaccion | Out-Null; $lote.Clear(); Write-Host "   ... $n ficheros" }
    }
  }
  if ($lote.Count) { Invoke-Rq $lote.ToArray() -Transaccion | Out-Null }
  $script:FilasTotales += $n
  Write-Host "   $n ficheros registrados."
}

function Etapa-Sorteos {
  Write-Host "== Sorteos (catalogo maestro 1356-2288) =="
  $c = Get-Cosecha
  $verif = @{}
  $csv = Get-CsvVerificacion
  if ($csv) { Import-Csv $csv | ForEach-Object { if ($_.tipo) { $verif[[int]$_.archivo] = $_.tipo.ToLower() } } }
  $pdfs = @{}
  Get-ChildItem "$DirRaiz\Datos\*.pdf" | ForEach-Object { if ($_.BaseName -match '^\d+$') { $pdfs[[int]$_.BaseName] = $_.Length } }
  $lote = New-Object System.Collections.Generic.List[string]
  $n = 0
  foreach ($s in 1356..2288) {
    $tipo = "NULL"; if ($verif.ContainsKey($s)) { $tipo = Esc $verif[$s] }
    $ftxt = $null; if ($c.fecha.ContainsKey($s)) { $ftxt = $c.fecha[$s] }
    $fiso = FechaIso $ftxt
    $upd = "NULL"; if ($c.pdf.ContainsKey($s)) { $upd = Esc $c.pdf[$s] }
    $uim = "NULL"; if ($c.img.ContainsKey($s)) { $uim = Esc $c.img[$s] }
    $fuente = "pendiente"
    if ($pdfs.ContainsKey($s) -and $pdfs[$s] -gt 0) { $fuente = "pdf" }
    $lote.Add("INSERT OR REPLACE INTO sorteo (num_sorteo,tipo,fecha,fecha_txt,url_pdf,url_img,fuente) VALUES ($s,$tipo,$(if($fiso){Esc $fiso}else{'NULL'}),$(if($ftxt){Esc $ftxt}else{'NULL'}),$upd,$uim,$(Esc $fuente))")
    $n++
    if ($lote.Count -ge $TamLote) { Invoke-Rq $lote.ToArray() -Transaccion | Out-Null; $lote.Clear() }
  }
  if ($lote.Count) { Invoke-Rq $lote.ToArray() -Transaccion | Out-Null }
  $script:FilasTotales += $n
  Write-Host "   $n sorteos en catalogo."
}

function Carga-Premios([string]$Fichero, [string]$Metodo, [bool]$TieneConfianza) {
  Write-Host "== Premios desde $(Split-Path $Fichero -Leaf) (metodo $Metodo) =="
  if (-not (Test-Path $Fichero)) { Write-Host "   no existe, se omite."; return }
  Invoke-Rq @("DELETE FROM premio WHERE metodo = $(Esc $Metodo)") | Out-Null
  $sb = New-Object System.Text.StringBuilder
  $enLote = 0; $n = 0; $t0 = Get-Date
  $lector = New-Object System.IO.StreamReader($Fichero)
  try {
    [void]$lector.ReadLine()   # cabecera
    while ($null -ne ($lin = $lector.ReadLine())) {
      $p = $lin.Split("|")
      if ($p.Count -lt 4) { continue }
      $sorteo = 0; if (-not [int]::TryParse($p[0], [ref]$sorteo)) { continue }
      $numero = $p[2].Trim()
      if ($numero -notmatch '^\d{1,7}$') { continue }
      $monto = 0.0; [void][double]::TryParse($p[3], [ref]$monto)
      $conf = "NULL"
      if ($TieneConfianza -and $p.Count -ge 6) { $c2 = 0.0; if ([double]::TryParse($p[5], [ref]$c2)) { $conf = $c2 } }
      $tp = $p[1].Trim().Replace("'", "''")
      if ($enLote -eq 0) {
        [void]$sb.Append("INSERT INTO premio (num_sorteo,tipo_premio,numero,monto,metodo,confianza) VALUES ")
      } else {
        [void]$sb.Append(",")
      }
      [void]$sb.Append("($sorteo,'$tp','$numero',$monto,'$Metodo',$conf)")
      $enLote++; $n++
      if ($enLote -ge $TamLote) {
        Invoke-Rq @($sb.ToString()) | Out-Null
        [void]$sb.Clear(); $enLote = 0
        if (($n % 20000) -eq 0) {
          $vel = [math]::Round($n / ((Get-Date) - $t0).TotalSeconds)
          Write-Host "   ... $n filas ($vel filas/s)"
        }
      }
    }
  } finally { $lector.Close() }
  if ($enLote) { Invoke-Rq @($sb.ToString()) | Out-Null }
  $script:FilasTotales += $n
  $seg = [math]::Round(((Get-Date) - $t0).TotalSeconds)
  Write-Host "   $n premios cargados en ${seg}s."
}

function Etapa-Premios {
  Carga-Premios "$DirRaiz\Resultados\EstadisticasLoteria2.txt" "awk-raw" $true
  Carga-Premios "$DirRaiz\Resultados\EstadisticasLoteria1.txt" "awk-table" $false
}

function Etapa-Premios2 {
  # Carga la extraccion v2 por coordenadas (Fase 3): sorteo|tipo|numero|monto|confianza.
  $fichero = "$DirRaiz\Resultados\ExtraccionV2.csv"
  Write-Host "== Premios v2 desde $(Split-Path $fichero -Leaf) (metodo py-coord) =="
  if (-not (Test-Path $fichero)) { Write-Host "   no existe, se omite."; return }
  Invoke-Rq @("DELETE FROM premio WHERE metodo = 'py-coord'") | Out-Null
  $sb = New-Object System.Text.StringBuilder
  $enLote = 0; $n = 0; $t0 = Get-Date
  $lector = New-Object System.IO.StreamReader($fichero)
  try {
    [void]$lector.ReadLine()   # cabecera
    while ($null -ne ($lin = $lector.ReadLine())) {
      $p = $lin.Split("|")
      if ($p.Count -lt 5) { continue }
      $sorteo = 0; if (-not [int]::TryParse($p[0], [ref]$sorteo)) { continue }
      $numero = $p[2].Trim()
      if ($numero -notmatch '^\d{5}$') { continue }
      $monto = "NULL"; $m2 = 0.0
      if ($p[3] -ne "" -and [double]::TryParse($p[3], [ref]$m2)) { $monto = $m2 }
      $conf = 0.0; [void][double]::TryParse($p[4], [ref]$conf)
      $tp = $p[1].Trim().Replace("'", "''")
      if ($enLote -eq 0) {
        [void]$sb.Append("INSERT INTO premio (num_sorteo,tipo_premio,numero,monto,metodo,confianza) VALUES ")
      } else {
        [void]$sb.Append(",")
      }
      [void]$sb.Append("($sorteo,'$tp','$numero',$monto,'py-coord',$conf)")
      $enLote++; $n++
      if ($enLote -ge $TamLote) {
        Invoke-Rq @($sb.ToString()) | Out-Null
        [void]$sb.Clear(); $enLote = 0
        if (($n % 40000) -eq 0) {
          $vel = [math]::Round($n / ((Get-Date) - $t0).TotalSeconds)
          Write-Host "   ... $n filas ($vel filas/s)"
        }
      }
    }
  } finally { $lector.Close() }
  if ($enLote) { Invoke-Rq @($sb.ToString()) | Out-Null }
  $script:FilasTotales += $n
  $seg = [math]::Round(((Get-Date) - $t0).TotalSeconds)
  Write-Host "   $n premios v2 cargados en ${seg}s."
}

function Etapa-Extras {
  Write-Host "== No encontrados (correcciones manuales) =="
  $f = "$DirRaiz\Datos\Listado No Encontrados.txt"
  if (Test-Path $f) {
    Invoke-Rq @("DELETE FROM no_encontrado WHERE origen = 'manual-2017'") | Out-Null
    $lote = New-Object System.Collections.Generic.List[string]
    $n = 0
    foreach ($lin in (Get-Content $f)) {
      $p = $lin.Split("|")
      if ($p.Count -lt 4 -or $p[0] -notmatch '^\d+$') { continue }
      $lote.Add("INSERT INTO no_encontrado (num_sorteo,numero,monto,tipo_premio,origen) VALUES ($([int]$p[0]),$(Esc $p[1]),$([double]$p[2]),$(Esc $p[3]),'manual-2017')")
      $n++
    }
    if ($lote.Count) { Invoke-Rq $lote.ToArray() -Transaccion | Out-Null }
    $script:FilasTotales += $n
    Write-Host "   $n correcciones."
  }

  Write-Host "== Catalogo web (snapshot mas reciente) =="
  $csv = Get-ChildItem "$DirRaiz\Temporal\*_Sorteos.csv" | Where-Object Length -gt 0 | Sort-Object Name | Select-Object -Last 1
  if ($csv) {
    $cap = $csv.BaseName.Substring(0, 8)
    $cap = "{0}-{1}-{2}" -f $cap.Substring(0,4), $cap.Substring(4,2), $cap.Substring(6,2)
    $lote = New-Object System.Collections.Generic.List[string]
    foreach ($lin in (Get-Content $csv.FullName)) {
      $p = $lin.Split("@")
      if ($p.Count -lt 4 -or $p[0] -notmatch '^\d+$') { continue }
      $upd = if ($p[1] -ne "-") { Esc $p[1] } else { "NULL" }
      $uim = if ($p[3] -ne "-") { Esc $p[3] } else { "NULL" }
      $ftx = if ($p[2] -ne "-") { Esc $p[2] } else { "NULL" }
      $lote.Add("INSERT OR REPLACE INTO catalogo_web (capturado_en,num_sorteo,url_pdf,url_img,fecha_txt) VALUES ($(Esc $cap),$([int]$p[0]),$upd,$uim,$ftx)")
    }
    if ($lote.Count) { Invoke-Rq $lote.ToArray() -Transaccion | Out-Null }
    $script:FilasTotales += $lote.Count
    Write-Host "   $($lote.Count) filas del snapshot $cap."
  }

  Write-Host "== Calidad inicial por sorteo =="
  $hoy = (Get-Date).ToString("s")
  Invoke-Rq @(
    "DELETE FROM calidad_sorteo",
    ("INSERT INTO calidad_sorteo (num_sorteo,tiene_pdf,tiene_img,tiene_info,nombre_coincide,premios_extraidos,evaluado_en) " +
     "SELECT s.num_sorteo, " +
     "MAX(CASE WHEN a.tipo='pdf'  AND a.estado <> 'corrupto' THEN 1 ELSE 0 END), " +
     "MAX(CASE WHEN a.tipo='jpg'  AND a.estado <> 'corrupto' THEN 1 ELSE 0 END), " +
     "MAX(CASE WHEN a.tipo='info' THEN 1 ELSE 0 END), " +
     "MAX(CASE WHEN a.tipo='pdf' AND a.num_interno_pdf IS NOT NULL THEN (a.num_interno_pdf = s.num_sorteo) END), " +
     "(SELECT COUNT(*) FROM premio p WHERE p.num_sorteo = s.num_sorteo AND p.metodo='awk-raw'), " +
     "$(Esc $hoy) " +
     "FROM sorteo s LEFT JOIN archivo a ON a.num_sorteo = s.num_sorteo GROUP BY s.num_sorteo")
  ) | Out-Null
  Write-Host "   calidad_sorteo poblada."
}

function Etapa-Verifica {
  Write-Host "== Verificacion =="
  foreach ($t in "sorteo","premio","archivo","calidad_sorteo","catalogo_web","no_encontrado","prediccion","corrida") {
    $r = Invoke-RqQuery "SELECT COUNT(*) FROM $t"
    Write-Host ("   {0,-16} {1,10:n0} filas" -f $t, $r.values[0][0])
  }
  $r = Invoke-RqQuery "SELECT metodo, COUNT(*), MIN(num_sorteo), MAX(num_sorteo) FROM premio GROUP BY metodo"
  foreach ($v in $r.values) { Write-Host "   premio[$($v[0])]: $($v[1]) filas, sorteos $($v[2])-$($v[3])" }
}

# ---------- principal ----------
$script:RqUrl = Get-RqliteUrl
$inicio = (Get-Date).ToString("s")
$okGlobal = 1
try {
  foreach ($e in $Etapas) {
    switch ($e.ToLower()) {
      "esquema"  { Etapa-Esquema }
      "archivos" { Etapa-Archivos }
      "sorteos"  { Etapa-Sorteos }
      "premios"  { Etapa-Premios }
      "premios2" { Etapa-Premios2 }
      "extras"   { Etapa-Extras }
      "verifica" { Etapa-Verifica }
      default    { Write-Host "Etapa desconocida: $e" }
    }
  }
} catch {
  $okGlobal = 0
  Write-Host "ERROR: $($_.Exception.Message)"
  throw
} finally {
  try {
    Invoke-Rq @("INSERT INTO corrida (inicio,fin,comando,filas_procesadas,ok,detalle) VALUES ($(Esc $inicio),$(Esc ((Get-Date).ToString('s'))),$(Esc ('CargaRqlite ' + ($Etapas -join ','))),$script:FilasTotales,$okGlobal,NULL)") | Out-Null
  } catch { }
}
Write-Host "Fin."
