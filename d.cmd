@echo off

@set PATH=lib\imgui_docking\win\dll;%PATH%
start /b remedybg game_dev.exe --no-topmost --no-live-reload
timeout /t 1
remedybg start-debugging
