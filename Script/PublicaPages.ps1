# PublicaPages.ps1 - Regenera la rama gh-pages con SOLO los ficheros del sitio.
#
# Por que una rama aparte: GitHub Pages publica el arbol entero de la rama que se le
# indique. La rama principal pesa ~670 MB (el archivo de PDFs e imagenes), asi que
# servirla entera desperdicia el presupuesto de Pages y hace lento cada despliegue.
# Esta rama huerfana lleva solo el sitio (~1 MB).
#
# Uso:  powershell -ExecutionPolicy Bypass -File Script\PublicaPages.ps1
# Requiere: git en el PATH y estar dentro del repositorio.

$ErrorActionPreference = "Stop"

$DirRaiz = Split-Path -Parent $PSScriptRoot
Set-Location $DirRaiz

# Ficheros que componen el sitio publicado: origen -> destino en la rama gh-pages.
# El video se sirve desde Pages porque GitHub no reproduce los MP4 del repositorio.
$Sitio = @{
  "index.html"                                          = "index.html"
  ".nojekyll"                                           = ".nojekyll"
  "Docs\Dashboard Estado de Datos.html" = "Docs\Dashboard Estado de Datos.html"
  "Docs\Mapa Premios.html"              = "Docs\Mapa Premios.html"
  "Docs\cobertura-sorteos.png"          = "Docs\cobertura-sorteos.png"
  "videos\loteria-nacional-explicado\renders\video.mp4" = "video\explicador.mp4"
}

foreach ($f in $Sitio.Keys) {
  if (-not (Test-Path -LiteralPath $f)) { throw "falta el fichero del sitio: $f" }
}

$RamaActual = (git rev-parse --abbrev-ref HEAD).Trim()
$Temporal = Join-Path $env:TEMP ("pages_" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $Temporal | Out-Null

try {
  # Copiar el sitio a un area temporal, conservando la estructura de carpetas.
  foreach ($origen in $Sitio.Keys) {
    $destino = Join-Path $Temporal $Sitio[$origen]
    $carpeta = Split-Path -Parent $destino
    if ($carpeta -and -not (Test-Path -LiteralPath $carpeta)) {
      New-Item -ItemType Directory -Force -Path $carpeta | Out-Null
    }
    Copy-Item -LiteralPath $origen -Destination $destino -Force
  }

  # Rama huerfana: sin historia, se reescribe entera en cada publicacion.
  git checkout --orphan gh-pages-tmp
  git rm -rf --cached . | Out-Null
  Get-ChildItem -Force | Where-Object { $_.Name -ne ".git" } | Remove-Item -Recurse -Force

  Copy-Item -Path (Join-Path $Temporal "*") -Destination $DirRaiz -Recurse -Force

  git add -A
  git commit -m "Sitio de GitHub Pages: dashboard, mapa animado y portada" | Out-Null

  git branch -D gh-pages 2>$null | Out-Null
  git branch -m gh-pages

  Write-Host "Rama gh-pages regenerada. Para publicarla:"
  Write-Host "  git push -f origin gh-pages"
} finally {
  Remove-Item -Recurse -Force $Temporal -ErrorAction SilentlyContinue
  git checkout -f $RamaActual 2>$null | Out-Null
}
