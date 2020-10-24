@setlocal

set outputd=C:\src\The-Forge\Examples_3\Unit_Tests\PC Visual Studio 2017\x64\ReleaseDx_Static\CAPI
copy /y "%outputd%\CAPI.dll" . && copy /y "%outputd%\capi.lib" lib\The_Forge\win && copy /y "%outputd%\CAPI.pdb" . && jai first.jai -- forge_host && first.exe
