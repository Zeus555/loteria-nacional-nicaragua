@echo off

set DirDatos=D:\Raspado\Loteria Nacional\Datos\
set FchFaltantes=%DirDatos%ListadoSorteosFaltantes.txt


if exist "%FchFaltantes%" del /f "%FchFaltantes%"

for /L %%i in (1356,1,2015) do (
	if not exist "%DirDatos%%%i.*" (
		echo https://issuu.com/loteriadenicaragua/docs/%%i>> "%FchFaltantes%"
	)
)

exit 0