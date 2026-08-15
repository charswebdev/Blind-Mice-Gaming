@echo off
title Blind Mice Gaming Updater
cd /d "%~dp0"
"C:\Users\CharlotteBryant\AppData\Local\Programs\Python\Python312\python.exe" "%~dp0app.py"
if errorlevel 1 (
  echo.
  echo The updater did not start. The error is above.
  pause
)
