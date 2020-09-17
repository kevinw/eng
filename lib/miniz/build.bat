@setlocal
echo off
cl /nologo /Z7 /Os /c miniz.c && lib /nologo /OUT:miniz.lib miniz.obj && ^
del *.obj && ^
move miniz.lib win && ^
echo built win/miniz.lib
