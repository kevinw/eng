@REM
@REM the intent here is to copy the imgui library and its binaries into our lib/ folder,
@REM so we don't need to reference an external project in our module paths
@REM

setlocal
set IMGUI_DIR=\src\jai-imgui
set DEST=imgui_docking
if not exist %DEST% mkdir %DEST%
copy %IMGUI_DIR%\imgui.jai %DEST%\module.jai || exit /b 1
xcopy /y /q /E %IMGUI_DIR%\win %DEST%\win\ || exit /b 1
@echo.
@echo Success - Updated '%DEST%' folder" from "%IMGUI_DIR%"
@echo.

