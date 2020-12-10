@echo off


REM jai -x64 first.jai -- %* > .compiler_errors 2>&1
REM set JAI_ERR=%ERRORLEVEL%
REM type .compiler_errors
REM if %JAI_ERR% EQU 0 game_dev.exe %*

jai -x64 first.jai -- %* && game_dev.exe %*
