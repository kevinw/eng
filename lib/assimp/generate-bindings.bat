@echo off
setlocal

set THIS_DIR=%~dp0
cd /D "%THIS_DIR%"

set JAICC="%THIS_DIR%..\jaicc\bin\jaicc.exe"
set ASSIMP_DLL_NAME=assimp-vc142-mt
set BUILD_DIR_IN_ASSIMP=build
set ASSIMP_SRC=%THIS_DIR%subrepo\assimp

cd "%ASSIMP_SRC%\include" || exit /b 1
%JAICC% assimp/cimport.h -I. -I..\%BUILD_DIR_IN_ASSIMP%\include -L..\%BUILD_DIR_IN_ASSIMP%\bin\Release -l%ASSIMP_DLL_NAME% -o "%THIS_DIR%module.jai" || exit /b 1
