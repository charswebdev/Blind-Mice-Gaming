@echo off
cd /d "%~dp0"
set "PYTHON=C:\Users\CharlotteBryant\AppData\Local\Programs\Python\Python312\python.exe"
set "ISCC=%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe"
if not exist "%ISCC%" set "ISCC=%ProgramFiles%\Inno Setup 6\ISCC.exe"
if not exist "%ISCC%" set "ISCC=%LocalAppData%\Programs\Inno Setup 6\ISCC.exe"

"%PYTHON%" -m pip install --upgrade pyinstaller
"%PYTHON%" make_icon.py
"%PYTHON%" make_wizard_art.py
"%PYTHON%" -m PyInstaller --noconfirm BlindMiceUpdater.spec
if errorlevel 1 goto :fail

if not exist "%ISCC%" (
  echo Inno Setup compiler not found. Installed the portable exe only.
  echo Expected: %ISCC%
  goto :done
)

"%ISCC%" BMG-Updater.iss
if errorlevel 1 goto :fail

echo.
echo App:       dist\BMG-Updater.exe
echo Installer: dist\BMG-Updater-Setup.exe
goto :end

:fail
echo.
echo Build failed.
pause
exit /b 1

:done
echo.
echo Built file is dist\BMG-Updater.exe
:end
pause
