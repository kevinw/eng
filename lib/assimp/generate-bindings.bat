@echo off
setlocal

set THIS_DIR=%~dp0
cd /D "%THIS_DIR%"

set JAICC="%THIS_DIR%..\jaicc\bin\jaicc.exe"
set CFG=Release
set ASSIMP_DLL_NAME=assimp-vc142-mt
set BUILD_DIR_IN_ASSIMP=build
set ASSIMP_SRC=%THIS_DIR%subrepo\assimp
set ASSIMP_BUILD=%ASSIMP_SRC%\%BUILD_DIR_IN_ASSIMP%
set ROOT_FILE=%THIS_DIR%assimp_headers.h

cd "%ASSIMP_SRC%\include" || exit /b 1
%JAICC% ^
%ROOT_FILE% ^
-I. -I..\%BUILD_DIR_IN_ASSIMP%\include ^
-L..\%BUILD_DIR_IN_ASSIMP%\bin\%CFG% -l%ASSIMP_DLL_NAME% ^
-o "%THIS_DIR%module.jai" ^
--type-replacement aiVector2D=Vector2 ^
--type-replacement aiVector3D=Vector3 ^
--type-replacement aiMatrix3x3=Matrix3 ^
--type-replacement aiMatrix4x4=Matrix4 ^
--extra-file-scope-import Math ^
--strip-prefix ai ^
--strip-enum-values-with-suffix _ENFORCE_ENUM_SIZE ^
--strip-enum-value-prefix aiPostProcessSteps=aiProcess_ || exit /b 1

copy %ASSIMP_BUILD%\bin\%CFG%\assimp-vc142-mt.dll . || exit /b 1
copy %ASSIMP_BUILD%\lib\%CFG%\assimp-vc142-mt.lib . || exit /b 1
