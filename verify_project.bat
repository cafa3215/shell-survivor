@echo off
setlocal

REM Convenience wrapper for Windows users.
REM Pass through all args to verify_project.py.

python "%~dp0verify_project.py" %*
exit /b %ERRORLEVEL%

