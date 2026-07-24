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
set DirTemporal=%DirRaiz%Temporal\

:: Seteamos fichero donde se guardan las estadisticas de historicas.
set FchEstadisticas=%DirResultados%EstadisticasLoteria.txt
:: Fichero donde estan guardados listado de numeros con premios que proceso no puede clasificar.
set FicheroNumNoFound=%DirDat2%Listado No Encontrados.dat

:: Agregamos directorio de libreria PDFtoText.
set path=%path%;%DirDrive%Herramientas\xpdfbin-win-3.04\bin64\;

:: Recorremos todos los PDF del directorio de datos.
echo Convertimos los PDF a Texto.
for %%a in ("%DirDat%*.pdf") do (
	if not exist "%DirTemporal%%%~na.txt" (
		echo Convertimos a TXT fichero %%a
		:: Convertimos todos los PDF a Texto.
		pdftotext -table "%%~fa" "%DirTemporal%%%~na.txt"
	) else (
		echo Ya se habia convertido a TXT %%a
	)
)

echo Obtenemos los numeros ganadores.
echo Archivo^|TipoPremio^|NumeroBillete^|MontoGanado > "%FchEstadisticas%"
for %%i in ("%DirTemporal%*.txt") do (
	echo Obtenemos numeros ganadores de %%i
	gawk -v "FicheroNumNoFound=%FicheroNumNoFound%" -f "%DirScript%ObtieneNumerosGanadores.awk" "%%i" >> "%FchEstadisticas%"
)

echo Se procesaron todos los PDF.
pause	
exit 0