@echo off

start /b remedybg first.exe --no-topmost --no-live-reload
timeout /t 1
remedybg start-debugging
