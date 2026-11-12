# AplicaCongruencia.ps1 - Aplica a rqlite las correcciones de ControlCongruencia.py.
# Filas: sorteo|numero|actual|nuevo|causa. 'actual'/'nuevo' son un tipo de premio
# o "monto:<valor>"/"monto:NULL". Idempotente: el WHERE exige el valor actual.
# Acepta un fichero alterno como parametro (lotes de correccion manual).

param([string]$Fichero = "D:\PRC Loteria Nacional\Resultados\CongruenciaCorrecciones.csv")

$ErrorActionPreference = "Stop"
$Semillas = @("192.168.0.34", "192.168.0.154", "192.168.0.231", "192.168.0.166")
# Credenciales de rqlite (loteria.curlrc) e Invoke-RqRest / Find-RqLider.
. (Join-Path $PSScriptRoot "RqliteAuth.ps1")

function DescubreLider { return (Find-RqLider $Semillas) }

$script:lider = DescubreLider
if (-not $script:lider) {
  $motivo = Get-RqMotivoRechazo
  if ($motivo) { Write-Host "ERROR: $motivo"; throw $motivo }
  throw "ningun nodo rqlite responde"
}
if ($script:RqRechazo.Count) { Write-Host "Aviso: $(Get-RqMotivoRechazo)" }

# Con reintentos: el cluster de telefonos pierde el lider transitoriamente.
function Ejecuta([string[]]$stmts) {
  $json = "[" + (($stmts | ForEach-Object { '"' + $_.Replace("\", "\\").Replace('"', '\"') + '"' }) -join ",") + "]"
  for ($intento = 1; $intento -le 6; $intento++) {
    try {
      if (-not $script:lider) { $script:lider = DescubreLider }
      if (-not $script:lider) {
        if (Get-RqMotivoRechazo) { throw $RqMsg401 }
        throw "sin lider"
      }
      $r = Invoke-RqRest -Method Post -Uri "http://$($script:lider):4001/db/execute?transaction" -Body $json -ContentType "application/json" -TimeoutSec 300
      $tot = 0
      foreach ($res in $r.results) { if ($res.error) { throw "rqlite: $($res.error)" }; $tot += $res.rows_affected }
      return $tot
    } catch {
      # Un error de SQL o un 401 no se arreglan reintentando.
      if ($_.Exception.Message -match 'rqlite:' -or (Test-RqRechazo $_)) { throw }
      $script:lider = $null
      Start-Sleep -Seconds (3 * $intento)
    }
  }
  throw "rqlite: reintentos agotados (cluster sin lider estable)"
}

$lote = New-Object System.Collections.Generic.List[string]
$n = 0; $af = 0
foreach ($fila in (Import-Csv $Fichero -Delimiter "|")) {
  $s = $fila.sorteo; $num = $fila.numero
  if ($fila.actual -like "monto:*") {
    $vAct = $fila.actual.Substring(6)
    $vNvo = $fila.nuevo.Substring(6)
    if ($vAct -eq "NULL") { $cond = "monto IS NULL" }
    else { $cond = "monto IS NOT NULL AND ABS(monto-$vAct)<0.01" }
    if ($vNvo -eq "NULL") {
      $lote.Add("UPDATE premio SET monto=NULL, confianza=0 WHERE metodo='py-coord' AND num_sorteo=$s AND numero='$num' AND $cond")
    } else {
      $lote.Add("UPDATE premio SET monto=$vNvo, confianza=50 WHERE metodo='py-coord' AND num_sorteo=$s AND numero='$num' AND $cond")
    }
  } else {
    $tAct = $fila.actual.Replace("'", "''")
    $tNvo = $fila.nuevo.Replace("'", "''")
    $lote.Add("UPDATE premio SET tipo_premio='$tNvo' WHERE metodo='py-coord' AND num_sorteo=$s AND numero='$num' AND tipo_premio='$tAct'")
  }
  $n++
  if ($lote.Count -ge 200) { $af += Ejecuta $lote.ToArray(); $lote.Clear(); if (($n % 1000) -eq 0) { Write-Host "  ... $n" } }
}
if ($lote.Count) { $af += Ejecuta $lote.ToArray() }
Write-Host "Correcciones: $n sentencias, $af filas afectadas."
