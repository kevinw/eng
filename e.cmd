@setlocal
@echo off

del d3d11_example.exe > nul 2>&1
jai build_d3d11_example.jai && d3d11_example.exe
