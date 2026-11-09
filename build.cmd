@echo off
rem Double-click (asks 32 / 64 / both) or "build.cmd 32|64|both [options]" - see README.md
chcp 65001 >nul
python "%~dp0tools\build.py" %*
echo.
pause
