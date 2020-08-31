@setlocal
echo off
cl /nologo /Os /c miniz.c && lib /nologo /OUT:miniz.lib miniz.obj && ^
del *.obj && ^
echo built miniz.lib
