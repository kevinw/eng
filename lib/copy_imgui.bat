@REM
@REM the intent here is to copy the imgui library and its binaries into our lib/ folder,
@REM so we don't need to reference an external project in our module paths
@REM

setlocal
set IMGUI_DIR=\src\jai-imgui
if not exist imgui mkdir imgui
copy %IMGUI_DIR%\imgui.jai .\imgui\module.jai || exit /b 1
xcopy /y /q /E %IMGUI_DIR%\win .\imgui\win\ || exit /b 1
copy /y %IMGUI_DIR%\win\dll\imgui.dll .. || exit /b 1
copy /y %IMGUI_DIR%\win\dll\imgui.pdb .. || exit /b 1
@echo.
@echo Success - Updated 'imgui' folder" from "%IMGUI_DIR%" and copied DLL/PDB into ..
@echo.

