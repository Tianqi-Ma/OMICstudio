@echo off
REM OMICstudio launcher for Windows. Double-click this file.
REM Requires R installed and on PATH, with the OMICstudio package installed.
Rscript -e "OMICstudio::run_app()"
pause
