@echo off

:: Punto de entrada de la tarea programada "PRC Loteria Nacional".
:: Desde 2026-07-20 (Fase 7) delega en TareaDiaria.ps1, que ejecuta la cadena
:: completa: sincronizacion, extraccion incremental, carga a rqlite, calidad,
:: prediccion y espejo a D:\Loteria Nacional. El log queda en Log\*_TareaDiaria.log.
:: Version anterior respaldada en Script\Historico\20260720\.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\PRC Loteria Nacional\Script\TareaDiaria.ps1"

exit %ERRORLEVEL%
