@echo off

:: Seteamos ambiente para usar variables retrasadas.
SETLOCAL ENABLEDELAYEDEXPANSION

:: Obtenemos fecha y hora actual.
call :ObtieneFecha

:: Directorios de trabajo.
set DirRaiz=D:\PRC Loteria Nacional\
set DirScript=%DirRaiz%Script\
set DirLog=%DirRaiz%Log\

:: Fichero de salida HTML con listado de Sorteos.
set FchLog=%YYYYMMDDHH24MISSCE%_GetSorteos.log

:: Creamos unidad virtual para que use directorio Temporal donde se creara el fichero HTML.
pushd "%DirLog%"

:: Ejecutar script dejando un log de ejecucion.
start "" /B /W "%DirScript%GetSorteos.bat" > "%FchLog%"
if NOT ERRORLEVEL 0 (
	goto :Error_Ejecucion
)

:: Eliminamos unidad virtual.
popd

:: Salimos reportando ejecución Ok
call :ObtieneFecha
echo [%YYYYMMDD_HH24_MI_SS%] ... Fin.

Exit 0

:Error_Ejecucion
	call :ObtieneFecha
	echo [%YYYYMMDD_HH24_MI_SS%] ... Error: al ejecutar GetSorteos.
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