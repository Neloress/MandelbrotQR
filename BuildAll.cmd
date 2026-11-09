@echo off
rem Doppelklick oder "BuildAll.cmd [32|64] [Optionen]" -> siehe BUILDALL-ANLEITUNG.md
chcp 65001 >nul
python "%~dp0BuildAll.py" %*
echo.
pause
