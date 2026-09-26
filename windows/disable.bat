@echo off
rem Turn the proxy off: restore the hosts file.
rem
rem Double-click this file. It asks for administrator rights itself, because
rem the Windows hosts file cannot be edited without them.
rem
rem Plain ASCII on purpose: cmd.exe reads .bat files in the console codepage,
rem and anything else turns into garbage on a non-English Windows.

setlocal

rem Rights are checked with a command that fails without them.
rem "if errorlevel 1" rather than comparing %errorlevel%: inside a block cmd
rem expands the variable before the command runs, and the comparison lies.
net session >nul 2>&1
if errorlevel 1 (
    echo Administrator rights are needed. Windows will ask for them now.
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..in\dns-ai-proxy.ps1" disable %*

echo.
if errorlevel 1 (
    echo Something went wrong - see the messages above.
)
echo You can close this window.
pause >nul
endlocal
