# TareaDiaria.ps1 - Fase 7: cadena diaria completa del proyecto Loteria Nacional.
#   1. Sincroniza con el sitio web (GetSorteos.bat)
#   2. Extrae premios de los PDF nuevos (ExtraePremiosV2.py --nuevos)
#   3. Carga los sorteos nuevos a rqlite + refresca metadatos
#   4. Recalcula calidad (premios_extraidos + score)
#   5. Regenera notas del mayor y la prediccion del proximo sorteo
#   6. Registra la corrida; si algo fallo, termina con error visible
# Autocontenido: no depende de otros .ps1. ASCII puro (PS 5.1).
#
# El paso "espejo a D:\Loteria Nacional" se retiro el 2026-07-26. Era un
# robocopy /E /XO de seis carpetas al mismo disco: verificado que las dos
# copias eran identicas (1529 ficheros, 0 unicos en el espejo), asi que
# duplicaba 647 MB sin proteger de una falla de la unidad.

$ErrorActionPreference = "Continue"
$DirRaiz = "D:\PRC Loteria Nacional"
$Python = "D:\Herramientas\Python\python.exe"
$Semillas = @("192.168.1.190", "192.168.1.124", "192.168.1.69", "192.168.1.252")

$marca = Get-Date -Format "yyyyMMdd_HHmmss"
$FchLog = "$DirRaiz\Log\${marca}_TareaDiaria.log"
$script:Errores = @()
$script:FilasNuevas = 0
$inicio = (Get-Date).ToString("s")

function Log([string]$msg) {
  $lin = "[$(Get-Date -Format 'yyyyMMdd HH:mm:ss')] $msg"
  Write-Host $lin
  Add-Content -Path $FchLog -Value $lin -Encoding ascii
}

function Falla([string]$paso, [string]$detalle) {
  $script:Errores += "${paso}: $detalle"
  Log "ERROR en ${paso}: $detalle"
}

# ---------- rqlite ----------
function Get-RqliteUrl {
  foreach ($ip in $Semillas) {
    try {
      $st = Invoke-RestMethod "http://${ip}:4001/status" -TimeoutSec 6
      $lider = ($st.store.leader.addr -split ":")[0]
      if ($lider) { return "http://${lider}:4001" }
    } catch { continue }
  }
  return $null
}

function Invoke-Rq([string[]]$Sentencias) {
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.Append("[")
  for ($i = 0; $i -lt $Sentencias.Count; $i++) {
    if ($i) { [void]$sb.Append(",") }
    $e = $Sentencias[$i].Replace("\", "\\").Replace('"', '\"').Replace("`r", "").Replace("`n", "\n")
    [void]$sb.Append('"').Append($e).Append('"')
  }
  [void]$sb.Append("]")
  # Con reintentos: el cluster de telefonos pierde el lider transitoriamente.
  for ($intento = 1; $intento -le 6; $intento++) {
    try {
      if (-not $script:RqUrl) { $script:RqUrl = Get-RqliteUrl }
      if (-not $script:RqUrl) { throw "sin lider" }
      $r = Invoke-RestMethod -Method Post -Uri "$script:RqUrl/db/execute?transaction" -Body $sb.ToString() -ContentType "application/json; charset=utf-8" -TimeoutSec 300
      foreach ($res in $r.results) { if ($res.error) { throw "rqlite: $($res.error)" } }
      return
    } catch {
      if ($_.Exception.Message -match 'rqlite:') { throw }
      $script:RqUrl = $null
      Start-Sleep -Seconds (3 * $intento)
    }
  }
  throw "rqlite: reintentos agotados (cluster sin lider estable)"
}

function Esc([string]$t) { "'" + $t.Replace("'", "''") + "'" }

# ==================== 1. SINCRONIZACION ====================
Log "== 1. Sincronizacion con el sitio web =="
& "$DirRaiz\Script\GetSorteos.bat" 2>&1 | ForEach-Object { Add-Content $FchLog "    $_" -Encoding ascii }
if ($LASTEXITCODE -ne 0) { Falla "sync" "GetSorteos.bat salio con codigo $LASTEXITCODE (posible cambio de estructura del sitio)" }

# ==================== 2. EXTRACCION INCREMENTAL ====================
Log "== 2. Extraccion de PDFs nuevos =="
$salida = & $Python "$DirRaiz\Script\ExtraePremiosV2.py" --nuevos 2>&1
$salida | ForEach-Object { Add-Content $FchLog "    $_" -Encoding ascii }
$nuevos = @()
foreach ($lin in $salida) {
  if ("$lin" -match '^NUEVOS: (.+)$') { $nuevos = $Matches[1].Split(",") | Where-Object { $_ } }
}
if ($LASTEXITCODE -ne 0) { Falla "extraccion" "ExtraePremiosV2 --nuevos con codigo $LASTEXITCODE" }
Log "   sorteos nuevos: $(if ($nuevos.Count) { $nuevos -join ', ' } else { 'ninguno' })"

# ==================== 3. CARGA A RQLITE ====================
$script:RqUrl = Get-RqliteUrl
if (-not $script:RqUrl) {
  Falla "rqlite" "ningun nodo semilla responde; se omite carga/calidad/prediccion en BD"
} else {
  Log "== 3. Carga a rqlite ($script:RqUrl) =="
  if ($nuevos.Count) {
    try {
      $setN = ($nuevos -join ",")
      Invoke-Rq @("DELETE FROM premio WHERE metodo='py-coord' AND num_sorteo IN ($setN)")
      $sb = New-Object System.Text.StringBuilder
      $enLote = 0
      $lector = New-Object System.IO.StreamReader("$DirRaiz\Resultados\ExtraccionV2.csv")
      try {
        while ($null -ne ($lin = $lector.ReadLine())) {
          $p = $lin.Split("|")
          if ($p.Count -lt 5 -or $nuevos -notcontains $p[0]) { continue }
          if ($p[2] -notmatch '^\d{5}$') { continue }
          $monto = "NULL"; $m2 = 0.0
          if ($p[3] -ne "" -and [double]::TryParse($p[3], [ref]$m2)) { $monto = $m2 }
          $conf = 0.0; [void][double]::TryParse($p[4], [ref]$conf)
          $tp = $p[1].Trim().Replace("'", "''")
          if ($enLote -eq 0) { [void]$sb.Append("INSERT INTO premio (num_sorteo,tipo_premio,numero,monto,metodo,confianza) VALUES ") }
          else { [void]$sb.Append(",") }
          [void]$sb.Append("($($p[0]),'$tp','$($p[2])',$monto,'py-coord',$conf)")
          $enLote++; $script:FilasNuevas++
          if ($enLote -ge 1000) { Invoke-Rq @($sb.ToString()); [void]$sb.Clear(); $enLote = 0 }
        }
      } finally { $lector.Close() }
      if ($enLote) { Invoke-Rq @($sb.ToString()) }
      Log "   $script:FilasNuevas premios nuevos cargados."
    } catch { Falla "carga-premios" $_.Exception.Message }
  }

  # Refresco de metadatos (archivos con hash + catalogo de sorteos).
  try {
    powershell -NoProfile -ExecutionPolicy Bypass -File "$DirRaiz\Script\CargaRqlite.ps1" -Etapas archivos,sorteos 2>&1 |
      ForEach-Object { Add-Content $FchLog "    $_" -Encoding ascii }
    if ($LASTEXITCODE -ne 0) { Falla "metadatos" "CargaRqlite archivos,sorteos con codigo $LASTEXITCODE" }
  } catch { Falla "metadatos" $_.Exception.Message }

  # ==================== 4. CALIDAD ====================
  Log "== 4. Calidad =="
  # 4a. Control de congruencia de la jerarquia de premios (MAYOR > SEGUNDO > ...).
  try {
    & $Python "$DirRaiz\Script\ControlCongruencia.py" --corrige 2>&1 |
      ForEach-Object { Add-Content $FchLog "    $_" -Encoding ascii }
    if ($LASTEXITCODE -ne 0) { throw "ControlCongruencia codigo $LASTEXITCODE" }
    $nCorr = (Get-Content "$DirRaiz\Resultados\CongruenciaCorrecciones.csv" | Measure-Object -Line).Lines - 1
    if ($nCorr -gt 0) {
      powershell -NoProfile -ExecutionPolicy Bypass -File "$DirRaiz\Script\AplicaCongruencia.ps1" 2>&1 |
        ForEach-Object { Add-Content $FchLog "    $_" -Encoding ascii }
      if ($LASTEXITCODE -ne 0) { throw "AplicaCongruencia codigo $LASTEXITCODE" }
      Log "   congruencia: $nCorr correcciones aplicadas."
    } else {
      Log "   congruencia: sin correcciones."
    }
  } catch { Falla "congruencia" $_.Exception.Message }
  # 4b. Metricas de calidad y score.
  try {
    Invoke-Rq @(
      "UPDATE calidad_sorteo SET premios_extraidos = (SELECT COUNT(*) FROM premio p WHERE p.num_sorteo = calidad_sorteo.num_sorteo AND p.metodo='py-coord' AND p.monto IS NOT NULL)",
      ("UPDATE calidad_sorteo SET score = ROUND(COALESCE(tiene_pdf,0)*15 + COALESCE(tiene_img,0)*5 + COALESCE(tiene_info,0)*5 " +
       "+ COALESCE(nombre_coincide, 0.5)*15 + (CASE WHEN premios_extraidos > 0 THEN 30 ELSE 0 END) " +
       "+ (CASE WHEN acuerdo_metodos IS NOT NULL THEN acuerdo_metodos*0.30 WHEN premios_extraidos > 0 THEN 25 ELSE 0 END), 1), " +
       "evaluado_en = datetime('now')")
    )
    Log "   calidad_sorteo recalculada."
  } catch { Falla "calidad" $_.Exception.Message }
}

# ==================== 5. NOTAS + PREDICCION ====================
Log "== 5. Notas del mayor y prediccion =="
try {
  & $Python "$DirRaiz\Script\ExtraeNotasMayor.py" 2>&1 | Select-Object -Last 1 | ForEach-Object { Log "   $_" }
  if ($LASTEXITCODE -ne 0) { throw "ExtraeNotasMayor codigo $LASTEXITCODE" }
  & $Python "$DirRaiz\Script\SistemaPredictivo.py" 2>&1 | ForEach-Object { Add-Content $FchLog "    $_" -Encoding ascii }
  if ($LASTEXITCODE -ne 0) { throw "SistemaPredictivo codigo $LASTEXITCODE" }

  if ($script:RqUrl) {
    $j = Get-Content "$DirRaiz\Resultados\Prediccion.json" -Raw | ConvertFrom-Json
    $gen = $j.generado_en; $ps = $j.para_sorteo
    $lote = @("DELETE FROM prediccion WHERE para_sorteo=$ps AND modelo='dirichlet-nota'")
    foreach ($d in 0..9) {
      $pp = $j.posterior_ultimo_digito.($d.ToString())
      $ev = $j.ev_terminacion.($d.ToString())
      $lote += "INSERT INTO prediccion (generado_en,para_sorteo,modelo,ambito,valor,probabilidad) VALUES ($(Esc $gen),$ps,'dirichlet-nota','ultimo-digito','$d',$pp)"
      $lote += "INSERT INTO prediccion (generado_en,para_sorteo,modelo,ambito,valor,probabilidad) VALUES ($(Esc $gen),$ps,'dirichlet-nota','ev-terminacion-cordobas','$d',$ev)"
    }
    $lote += "INSERT INTO prediccion (generado_en,para_sorteo,modelo,ambito,valor,probabilidad) VALUES ($(Esc $gen),$ps,'dirichlet-nota','veredicto',$(Esc $j.nota_honesta),NULL)"
    Invoke-Rq $lote
    Log "   prediccion del sorteo $ps publicada en la BD."
  }
} catch { Falla "prediccion" $_.Exception.Message }

# ==================== 6. REGISTRO Y CIERRE ====================
$ok = if ($script:Errores.Count) { 0 } else { 1 }
if ($script:RqUrl) {
  try {
    $det = if ($script:Errores.Count) { Esc (($script:Errores -join "; ")) } else { "NULL" }
    Invoke-Rq @("INSERT INTO corrida (inicio,fin,comando,filas_procesadas,ok,detalle) VALUES ($(Esc $inicio),$(Esc ((Get-Date).ToString('s'))),'TareaDiaria',$script:FilasNuevas,$ok,$det)")
  } catch { Log "aviso: no se pudo registrar la corrida: $($_.Exception.Message)" }
}
if ($script:Errores.Count) {
  Log "ALERTA: la tarea termino con $($script:Errores.Count) error(es): $($script:Errores -join ' | ')"
  exit 1
}
Log "Fin OK."
exit 0
