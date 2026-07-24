	@echo off

:: Seteamos ambiente para usar variables retrasadas.
SETLOCAL ENABLEDELAYEDEXPANSION

:: Obtenemos fecha y hora actual.
call :ObtieneFecha

:: Mes actual en formato numerico.
if %MM:~0,1% == 0 ( set /a nMM=%MM:~1,1% ) else ( set /a nMM=%MM% )

:: Directorios de trabajo.
set DirRaiz=D:\PRC Loteria Nacional\
set DirScript=%DirRaiz%Script\
set DirTemporal=%DirRaiz%Temporal\
set DirLog=%DirRaiz%Log\
set DirDatos=%DirRaiz%Datos\
set DirImg=%DirRaiz%Imagenes\

:: Actualizar directorio programas de windows.
set path=%path%;D:\Herramientas\GAWK\bin

:: Proxy
set Proxy=192.168.55.10:3128

:: Sitio web donde esta publicado listado de sorteos.
set URL_Raiz=https://www.loterianacional.com.ni
set URL_ListaSorteos=%URL_Raiz%/lista-sorteos/

:: Fichero de salida HTML con listado de Sorteos.
set FchListaSorteosHtml=%YYYYMMDDHH24MISSCE%_Sorteos.html

:: Fichero de salida CSV con tabla de sorteos.
set FchListaSorteosCSV=%YYYYMMDDHH24MISSCE%_Sorteos.csv

:: Especificamos en la configuracion que el useragent es Google Chrome.
set UserAgent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36 Edg/91.0.864.67

:: Creamos unidad virtual para que use directorio Temporal donde se creara el fichero HTML.
pushd "%DirTemporal%"

:: Iniciamos ejecución.
echo [%YYYYMMDD_HH24_MI_SS%] ... inicio.

:: Extrae XML de tendencias diarias de Google desde la web y guarda resultados en fichero de texto.
echo [%YYYYMMDD_HH24_MI_SS%] ... ... descargar sorteos desde la web.

:: Obtiene HTML donde esta el listado de Sorteos.
call :ObtieneFecha && echo [%YYYYMMDD_HH24_MI_SS%] ... obtener listado de sorteos.
curl -s %URL_ListaSorteos% -o "%FchListaSorteosHtml%" -A "%UserAgent%"
IF ERRORLEVEL 1 ( goto :Error_Extrae_Lista_Sorteos )

:: Obtenemos listado de Sorteos en CSV.
call :ObtieneFecha && echo [%YYYYMMDD_HH24_MI_SS%] ... creamos listado de sorteos CSV.
gawk -f "%DirScript%GetSorteos.awk" %FchListaSorteosHtml% > %FchListaSorteosCSV%
IF ERRORLEVEL 1 ( goto :Error_CSV_Vacio )

:: Si el CSV quedo vacio el sitio cambio de estructura: fallar ruidosamente.
for %%z in (%FchListaSorteosCSV%) do if %%~zz EQU 0 ( goto :Error_CSV_Vacio )

:: Leemos fichero CSV: refrescamos .Info y descargamos PDF/imagen faltantes o en 0 bytes.
:: Las URLs del CSV son absolutas y campos sin dato vienen como "-".
call :ObtieneFecha && echo [%YYYYMMDD_HH24_MI_SS%] ... recorremos listado de sorteos CSV.
for /f "tokens=* delims=@" %%k in (%FchListaSorteosCSV%) do (
	for /f "tokens=1,2,4 delims=@" %%a in ("%%k") do (
		set NumSorteo=%%a
		set urlPDF=%%b
		set urlImg=%%c
	)

	rem El .Info se refresca siempre: es metadato derivado y asi se auto-corrigen
	rem los que quedaron con el emparejamiento corrido (bug corregido 2026-07-19).
	echo %%k > "%DirDatos%!NumSorteo!.Info"

	set DescargaPDF=0
	if not exist "%DirDatos%!NumSorteo!.pdf" set DescargaPDF=1
	if exist "%DirDatos%!NumSorteo!.pdf" for %%f in ("%DirDatos%!NumSorteo!.pdf") do if %%~zf EQU 0 set DescargaPDF=1
	if "!urlPDF!"=="-" set DescargaPDF=0
	if !DescargaPDF! EQU 1 (
		call :ObtieneFecha && echo [%YYYYMMDD_HH24_MI_SS%] ... ... descargamos PDF desde la web para sorteo !NumSorteo!.
							  echo [%YYYYMMDD_HH24_MI_SS%] ... ... ... "%DirDatos%!NumSorteo!.pdf"
		curl -f -s --retry 3 "!urlPDF!" -o "%DirDatos%!NumSorteo!.pdf" -A "%UserAgent%"
		if ERRORLEVEL 1 ( echo [%YYYYMMDD_HH24_MI_SS%] ... ... ... Error: fallo descarga PDF sorteo !NumSorteo!. )
	)

	set DescargaImg=0
	if not exist "%DirImg%!NumSorteo!.jpg" set DescargaImg=1
	if exist "%DirImg%!NumSorteo!.jpg" for %%f in ("%DirImg%!NumSorteo!.jpg") do if %%~zf EQU 0 set DescargaImg=1
	if "!urlImg!"=="-" set DescargaImg=0
	if !DescargaImg! EQU 1 (
		call :ObtieneFecha && echo [%YYYYMMDD_HH24_MI_SS%] ... ... descargamos Imagen del sorteo desde la web para sorteo !NumSorteo!.
							  echo [%YYYYMMDD_HH24_MI_SS%] ... ... ... "%DirImg%!NumSorteo!.jpg"
		curl -f -s --retry 3 "!urlImg!" -o "%DirImg%!NumSorteo!.jpg" -A "%UserAgent%"
		if ERRORLEVEL 1 ( echo [%YYYYMMDD_HH24_MI_SS%] ... ... ... Error: fallo descarga Imagen sorteo !NumSorteo!. )
	)
)

:: Eliminamos unidad virtual.
popd

:: Salimos reportando ejecución Ok
call :ObtieneFecha
echo [%YYYYMMDD_HH24_MI_SS%] ... Fin.

Exit 0

:Error_Extrae_Lista_Sorteos
	call :ObtieneFecha
	echo [%YYYYMMDD_HH24_MI_SS%] ... ... ... Error: al extraer listado de Sorteos desde la Web.
	exit 1
goto :eof

:Error_CSV_Vacio
	call :ObtieneFecha
	echo [%YYYYMMDD_HH24_MI_SS%] ... ... ... Error: el CSV de sorteos quedo VACIO, el sitio web cambio de estructura. Revisar GetSorteos.awk.
	popd
	exit 1
goto :eof

:ObtieneFecha
	for /f "tokens=2 delims==" %%a in ('wmic OS Get localdatetime /value') do set "dt=%%a"
	set "YY=%dt:~2,2%" & set "YYYY=%dt:~0,4%" & set "MM=%dt:~4,2%" & set "DD=%dt:~6,2%"
	set "HH24=%dt:~8,2%" & set "MIN=%dt:~10,2%" & set "SEG=%dt:~12,2%" & set "CENT=%dt:~15,2%" & set "MIL=%dt:~15,3%"

	set YYYYMM=%YYYY%%MM%
	set YYYYMMDD=%YYYY%%MM%%DD%
	set YYYYMMDDHH24MISS=%YYYY%%MM%%DD%%HH24%%MIN%%SEG%
	set YYYYMMDDHH24MISSCE=%YYYY%%MM%%DD%%HH24%%MIN%%SEG%%CENT%
	set YYYYMMDDHH24MISSML=%YYYY%%MM%%DD%%HH24%%MIN%%SEG%%MIL%
	set YYYYMMDD_HH24_MI_SS=%YYYY%%MM%%DD% %HH24%:%MIN%:%SEG%
goto :eof