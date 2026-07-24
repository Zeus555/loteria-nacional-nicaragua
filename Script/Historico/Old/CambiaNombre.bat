@echo off

:: Habilitamos extension variables.
setlocal enabledelayedexpansion enableextensions

cd C:\Users\Ariel Mairena\Google Drive\Casa\Loteria Nacional\Temporal\Historico\

for %%a in (*.txt) do (
	set nom=%%~nxa
	rem set nombre=!nom:~-8,4!
	set nombre=%%~na Vj%%~xa
	echo !nom! "!nombre!"
	rename !nom! "!nombre!"
)

pause
exit 0