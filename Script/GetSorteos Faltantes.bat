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

:: Buscar sorteos los PDF.
set /a sYYYY=2024
for /L %%c in (2185,1,2198) do (
	set /a NumSorteo=%%c
	echo !NumSorteo!

	:: Recorrer todos los meses.
	set /a aa=0
	for /L %%b in (6,1,9) do (
		if !aa! EQU 0 (
			:: Validar que el numero de mes sea en formato MM.
			if %%b LSS 10 (
				set sMM=0%%b
			) else (
				set sMM=%%b
			)
			
			:: Descargar PDF.
			if not exist "%DirDatos%!NumSorteo!.pdf" (
				set SearchPDF=%URL_Raiz%/wp-content/uploads/!sYYYY!/!sMM!/Lista-!NumSorteo!.pdf
				curl -s -f !SearchPDF! -o "%DirDatos%!NumSorteo!.pdf" -A "%UserAgent%"
				if !errorlevel! EQU 23 (
					echo Sorteo !NumSorteo!.pdf para el mes !sYYYY!!sMM! descargado con exito.
					set /a aa=1
				)
			)
			
			:: Descargar Imagen.
			if not exist "%DirDatos%!NumSorteo!.jpg" (
				set SearchImg=%URL_Raiz%/wp-content/uploads/!sYYYY!/!sMM!/!NumSorteo!.jpg
				curl -s -f !SearchImg! -o "%DirDatos%!NumSorteo!.jpg" -A "%UserAgent%"
				if !errorlevel! EQU 23 (
					echo Imagen !NumSorteo!.jpg para el mes !sYYYY!!sMM! descargado con exito.
					set /a aa=2
				)
			)
		)
	)
	rem if !NumSorteo! GEQ 2167 ( goto :Fin )
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