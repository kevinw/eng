@echo off

setlocal
set PATH=lib\Chipmunk\win\dll;%PATH%;
set PATH=lib\imgui_docking\win\dll;%PATH%
set PATH=lib\assimp;%PATH%
set PATH=lib\lz4-1.9.3\win\dll;%PATH%

echo on
jai -quiet first.jai -- %* && game_dev.exe %*
