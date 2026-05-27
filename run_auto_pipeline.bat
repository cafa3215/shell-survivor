@echo off
setlocal
cd /d "%~dp0"
python "tools\advance_project.py" run-auto
if errorlevel 1 exit /b %errorlevel%
python "tools\advance_project.py" validate-auto
endlocal

