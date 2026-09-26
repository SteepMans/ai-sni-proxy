@echo off
rem Show whether the proxy is on. No rights needed.
rem
rem Double-click this file. It asks for administrator rights itself, because
rem the Windows hosts file cannot be edited without them.
rem
rem Plain ASCII on purpose: cmd.exe reads .bat files in the console codepage,
rem and anything else turns into garbage on a non-English Windows.

setlocal

cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..in\dns-ai-proxy.ps1" status %*

echo.
if errorlevel 1 (
    echo Something went wrong - see the messages above.
)
echo You can close this window.
pause >nul
endlocal
