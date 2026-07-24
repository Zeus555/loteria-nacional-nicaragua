@echo off

:: Habilitamos extension variables.
setlocal enabledelayedexpansion enableextensions

:: Obtenemos el nombre del usuario del sistema operativo.
:: for /f "tokens=1,2,3 delims=\" %%i in ("%userprofile%") do set Usuario=%%k

:: Seteamos directorio de trabajo.
set DirDrive=C:\Users\Ariel Mairena\Google Drive\
set DirRaiz=C:\Users\Ariel Mairena\Google Drive\Casa\Loteria Nacional\
set DirRaiz2=C:\\Users\\Ariel Mairena\\Google Drive\\Casa\\Loteria Nacional\\
set DirLog=%DirRaiz%Log\
set DirDat=%DirRaiz%Datos\
set DirDat2=%DirRaiz2%Datos\\
set DirScript=%DirRaiz%Script\
set DirResultados=%DirRaiz%Resultados\
set DirResultados2=%DirRaiz2%Resultados\\
set DirTemporal=%DirRaiz%Temporal\

:: Seteamos fichero donde se guardan las estadisticas de historicas.
set FchEstadisticas1=%DirResultados%EstadisticasLoteria1.txt
set FchEstadisticas2=%DirResultados%EstadisticasLoteria2.txt
set FchEstadisticas21=%DirResultados2%EstadisticasLoteria1.txt
set FchEstadisticas22=%DirResultados2%EstadisticasLoteria2.txt
:: Fichero donde estan guardados listado de numeros con premios que proceso no puede clasificar.
set FicheroNumNoFound=%DirDat2%Listado No Encontrados.txt

:: Agregamos directorio de libreria PDFtoText.
set path=%path%;%DirDrive%Herramientas\xpdfbin-win-3.04\bin64\;

:: Recorremos todos los PDF del directorio de datos.
call :ObtieneFecha
echo Convertimos los PDF a Texto ... %YYYYMMDD_HH24_MI_SS%.
for %%a in ("%DirDat%*.pdf") do (
	rem Convertimos con formato TABLE.
	if not exist "%DirTemporal%%%~na Vj.txt" (
		echo Convertimos con metodo TABLE	"%%a".
		:: Convertimos todos los PDF a Texto.
		pdftotext -table "%%~fa" "%DirTemporal%%%~na Vj.txt"
	) else (
		echo Ya se habia convertido con metodo TABLE "%%a".
	)

	rem Convertimos con formato RAW.
	if not exist "%DirTemporal%%%~na Nv.txt" (
		echo Convertimos con metodo RAW "%%a".
		:: Convertimos todos los PDF a Texto.
		pdftotext -raw "%%~fa" "%DirTemporal%%%~na Nv.txt"
	) else (
		echo Ya se habia convertido con metodo RAW "%%a".
	)
)

:: Obtenemos el texto del PDF segun metodo TABLE.
call :ObtieneFecha
echo Procesamos los numeros ganadores con metodo viejo ... %YYYYMMDD_HH24_MI_SS%.
echo Archivo^|TipoPremio^|NumeroBillete^|MontoGanado^|TipoBusqueda > "%FchEstadisticas1%"
for %%i in ("%DirTemporal%*Vj.txt") do (
	set Sorteo=%%~ni
	set Sorteo=!Sorteo: Vj=!
	echo Ganadores metodo TABLE de %%~fi
	gawk -v "FicheroNumNoFound=%FicheroNumNoFound%" -v "Sorteo=!Sorteo!" -v "FchEstadisticas=%FchEstadisticas21%" -f "%DirScript%ObtieneNumerosGanadores.awk" "%%i"
	if ERRORLEVEL 1 (
		echo ... Error: al procesar fichero %%~fi.
	)
)

:: Obtenemos el texto del PDF segun metodo RAW.
call :ObtieneFecha
echo Procesamos los numeros ganadores con nuevo metodo ... %YYYYMMDD_HH24_MI_SS%.
echo Archivo^|TipoPremio^|NumeroBillete^|MontoGanado^|TipoBusqueda^|PorcConfianza > "%FchEstadisticas2%"
for %%j in ("%DirTemporal%*Nv.txt") do (
	set Sorteo=%%~nj
	set Sorteo=!Sorteo: Nv=!
	echo Ganadores metodo RAW %%~fj
	gawk -v "FicheroNumNoFound=%FicheroNumNoFound%" -v "Sorteo=!Sorteo!" -v "FchEstadisticas=%FchEstadisticas22%" -f "%DirScript%ObtieneNumerosGanadoresNw.awk" "%%j"
	if ERRORLEVEL 1 (
		echo ... Error: al procesar fichero %%~fj.
	)
)

:: Obtenemos el detalle de las diferencias entre ambos metodos.
call :ObtieneFecha
echo Procesamos resultados de ambos metodos y camparamos ... %YYYYMMDD_HH24_MI_SS%.
gawk -f "%DirScript%Diferencias entre Estadisticas.awk"

call :ObtieneFecha
echo Fin del procesamiento ... %YYYYMMDD_HH24_MI_SS%.
pause	
exit 0

:ObtieneFecha
	set FECHA_ACTUAL=%DATE%
	set HORA_ACTUAL=%TIME%
	set ANIO=%FECHA_ACTUAL:~-4,4%
	set MES=%FECHA_ACTUAL:~-7,2%
	set DIA=%FECHA_ACTUAL:~-10,2%
	set HORA=%HORA_ACTUAL:~0,2%
	REM La hora en formato numerico, tanto para evaluar la hora maxima de ejecucion a como si viene menor que 10 le ponga el cero.
	set /a HORA2=%HORA_ACTUAL:~0,2% + 0
	if %HORA2% LSS 10 set HORA=0%HORA2%
	set MINUTOS=%HORA_ACTUAL:~3,2%
	set SEGUNDOS=%HORA_ACTUAL:~6,2%
	set CENTESIMAS=%HORA_ACTUAL:~9,2%
	set YYYYMM=%ANIO%%MES%
	set YYYYMMDD=%ANIO%%MES%%DIA%
	set YYYYMMDDHH24MISS=%ANIO%%MES%%DIA%%HORA%%MINUTOS%%SEGUNDOS%
	set YYYYMMDDHH24MISSCE=%ANIO%%MES%%DIA%%HORA%%MINUTOS%%SEGUNDOS%%CENTESIMAS%
	set YYYYMMDD_HH24_MI_SS=%ANIO%%MES%%DIA% %HORA%:%MINUTOS%:%SEGUNDOS%
	set HH24_MI_SS=%HORA%:%MINUTOS%:%SEGUNDOS%
goto :eof