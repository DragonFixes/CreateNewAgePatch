@echo off
setlocal
rem Builds the Create New Age Patch mod jar into build\.
rem Usage: build.bat [-LibrariesDir <server libraries folder>] [-Version <version>] [-Jdk <jdk home>] [-CopyTo <mods folder>]
rem Example: build.bat -CopyTo "%USERPROFILE%\curseforge\minecraft\Instances\Com (SRV) (T)\mods"

if not exist "%~dp0build.ps1" (
    echo build.ps1 not found next to build.bat
    exit /b 1
)

where pwsh >nul 2>nul
if %ERRORLEVEL%==0 (
    pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0build.ps1" %*
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build.ps1" %*
)
exit /b %ERRORLEVEL%
