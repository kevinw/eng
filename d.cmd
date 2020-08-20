@echo off

start /b remedybg first.exe --no-topmost
timeout /t 1
remedybg start-debugging
