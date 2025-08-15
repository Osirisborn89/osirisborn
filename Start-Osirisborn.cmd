@echo off
setlocal
for /f "delims=" %%P in ('where pwsh 2^>NUL') do set "PSH=%%P"
if not defined PSH set "PSH=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
set "ROOT=%~dp0"
pushd "%ROOT%MythicCore\scripts"
start "" "%PSH%" -NoProfile -ExecutionPolicy Bypass -File "Osirisborn.Server.ps1"
popd
timeout /t 2 >NUL
start "" "http://localhost:7777/"
exit /b 0
