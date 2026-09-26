@echo off
rem Show whether the proxy is on.
rem
rem Double-click this file. It only reads the hosts file, so no
rem administrator rights are needed.
rem
rem Plain ASCII on purpose: cmd.exe reads .bat files in the console codepage,
rem and anything else turns into garbage on a non-English Windows.

setlocal

cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\bin\ai-sni-proxy.ps1" status %*

echo.
if errorlevel 1 (
    echo Something went wrong - see the messages above.
)
echo You can close this window.
pause >nul
endlocal
