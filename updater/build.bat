@echo off
cd /d "%~dp0"
"C:\Users\CharlotteBryant\AppData\Local\Programs\Python\Python312\python.exe" -m pip install --upgrade pyinstaller
"C:\Users\CharlotteBryant\AppData\Local\Programs\Python\Python312\python.exe" make_icon.py
"C:\Users\CharlotteBryant\AppData\Local\Programs\Python\Python312\python.exe" -m PyInstaller --noconfirm BlindMiceUpdater.spec
echo.
echo Built file is dist\BMG-Updater.exe
pause
