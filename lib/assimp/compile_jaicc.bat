@echo off
setlocal

pushd ..\jaicc || exit /b 1
jai first.jai || exit /b 1
set myerr=%ERRORLEVEL%
popd

exit /b %myerr%

