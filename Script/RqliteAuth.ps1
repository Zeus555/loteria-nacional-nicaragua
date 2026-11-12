# RqliteAuth.ps1 - credenciales y llamadas a rqlite comunes a TareaDiaria.ps1,
# CargaRqlite.ps1 y AplicaCongruencia.ps1. Se carga con punto, desde el script:
#     . "$PSScriptRoot\RqliteAuth.ps1"
# ASCII puro a proposito (PS 5.1).
#
# Fichero: %USERPROFILE%\.config\rqlite\loteria.curlrc, una linea en formato curl:
#     user = "loteria:<clave>"
# La cabecera Authorization Basic se arma aqui, en memoria: la clave no va en la
# linea de comandos ni sale en el log. Sin fichero (o si la linea no tiene ese
# formato) no se manda cabecera y todo sigue como siempre: un rqlited sin -auth
# la ignora de todos modos.
#
# Con -auth, rqlite rechaza con HTTP 401 y cuerpo vacio. Invoke-RqRest lo convierte
# en un error de texto fijo ($RqMsg401): asi el log no lo confunde con "semilla
# caida" o "sin lider", y los reintentos no insisten con la misma clave.

$RqMsg401 = "rqlite rechaza las credenciales de loteria (401)"
$RqCredFichero = $null
if ($env:USERPROFILE) { $RqCredFichero = Join-Path $env:USERPROFILE ".config\rqlite\loteria.curlrc" }

function Get-RqCabecera {
  if (-not $RqCredFichero -or -not (Test-Path -LiteralPath $RqCredFichero -PathType Leaf)) { return @{} }
  try {
    foreach ($lin in @(Get-Content -LiteralPath $RqCredFichero -ErrorAction Stop)) {
      if ($lin -match '^\s*user\s*=\s*"([^:"]+):([^"]*)"\s*$') {
        $par = [System.Text.Encoding]::UTF8.GetBytes($Matches[1] + ":" + $Matches[2])
        return @{ Authorization = "Basic " + [Convert]::ToBase64String($par) }
      }
    }
  } catch { }
  return @{}
}

$RqCabecera = Get-RqCabecera
# Para el log: dice si hay credenciales, nunca cuales.
if ($RqCabecera.Count) { $RqCredEstado = "con credenciales (loteria.curlrc)" }
elseif ($RqCredFichero -and (Test-Path -LiteralPath $RqCredFichero -PathType Leaf)) {
  $RqCredEstado = "SIN credenciales: loteria.curlrc no tiene la forma user = ""usuario:clave"""
}
else { $RqCredEstado = "sin credenciales (no hay loteria.curlrc)" }

# Codigo HTTP de un error de Invoke-RestMethod (0 si no hubo respuesta HTTP).
function Get-RqEstadoHttp($Err) {
  $ex = if ($Err -is [System.Management.Automation.ErrorRecord]) { $Err.Exception } else { $Err }
  while ($ex) {
    $resp = $null
    try { $resp = $ex.Response } catch { }
    if ($resp) { try { return [int]$resp.StatusCode } catch { } }
    $ex = $ex.InnerException
  }
  return 0
}

# Verdadero si el error es el rechazo de credenciales de Invoke-RqRest.
function Test-RqRechazo($Err) {
  $m = if ($Err -is [System.Management.Automation.ErrorRecord]) { $Err.Exception.Message } else { [string]$Err }
  return ([string]$m).StartsWith($RqMsg401)
}

# Invoke-RestMethod con la cabecera de rqlite. Usarla para TODA llamada a rqlite
# (y solo a rqlite: la cabecera no debe salir hacia otro host).
function Invoke-RqRest {
  param(
    [Parameter(Mandatory = $true)][string]$Uri,
    [string]$Method = "Get",
    $Body = $null,
    [string]$ContentType = "",
    [int]$TimeoutSec = 60
  )
  $p = @{ Uri = $Uri; Method = $Method; TimeoutSec = $TimeoutSec }
  if ($RqCabecera.Count) { $p.Headers = $RqCabecera }
  if ($null -ne $Body) { $p.Body = $Body }
  if ($ContentType) { $p.ContentType = $ContentType }
  try {
    return Invoke-RestMethod @p
  } catch {
    if ((Get-RqEstadoHttp $_) -eq 401) { throw $RqMsg401 }
    throw
  }
}

# Pregunta /status a las semillas, en orden, y devuelve la IP del lider ($null si
# ninguna lo sabe). En $script:RqRechazo quedan las semillas que contestaron 401,
# para que quien llama diga "rechaza las credenciales" y no "ninguna responde".
function Find-RqLider([string[]]$Semillas) {
  $script:RqRechazo = @()
  $script:RqViaSemilla = $null
  foreach ($ip in $Semillas) {
    try {
      $st = Invoke-RqRest -Uri "http://${ip}:4001/status" -TimeoutSec 6
      $lider = ([string]$st.store.leader.addr -split ":")[0]
      if ($lider) { $script:RqViaSemilla = $ip; return $lider }
    } catch {
      if (Test-RqRechazo $_) { $script:RqRechazo += $ip }
    }
  }
  return $null
}

# Texto para el log cuando Find-RqLider no encontro lider por un 401 ($null si no).
function Get-RqMotivoRechazo {
  if ($script:RqRechazo -and $script:RqRechazo.Count) {
    return "$RqMsg401 en las semillas $($script:RqRechazo -join ', ')"
  }
  return $null
}
