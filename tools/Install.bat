@echo off
REM Double-click installer for Windows. Runs install-windows.ps1, asking for
REM administrator rights first, because the ProPresenter Bibles folder under
REM ProgramData needs them.
setlocal

REM The PowerShell script sits next to this file in a checkout, and under
REM tools\ in the release zip. Accept either.
set "SCRIPT=%~dp0install-windows.ps1"
if not exist "%SCRIPT%" set "SCRIPT=%~dp0tools\install-windows.ps1"
if not exist "%SCRIPT%" (
    echo Could not find install-windows.ps1 next to this file.
    echo Unpack the whole download and run Install.bat from inside it.
    echo.
    pause
    exit /b 1
)

REM Already elevated? net session only succeeds for an administrator.
net session >/dev/null 2>&1
if %errorlevel%==0 goto run

echo Asking for administrator rights...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -Verb RunAs -FilePath %~f0"
exit /b 0

:run
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
set "RESULT=%errorlevel%"
echo.
if not "%RESULT%"=="0" echo The installer reported a problem ^(code %RESULT%^).
echo Quit ProPresenter completely and open it again to see the Bibles.
echo.
pause
exit /b %RESULT%
