@echo off
setlocal

set JAI_DIR=\jai
set DEST=Window_Creation
set SRC=%JAI_DIR%\modules\%DEST%

if not exist %SRC% echo Error: Coult not find source directory '%SRC%' && exit /b 1

echo This will overwrite all the contents of %DEST% with the version from %JAI_DIR%.
set /p var=Are You Sure? [y/n]: 
if not %var%== y echo Cancelled. && exit /b 1

rmdir /s /q %DEST%
xcopy /e /k /h /i %SRC% %DEST%
