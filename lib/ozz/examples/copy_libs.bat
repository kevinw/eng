@set BUILD_DIR=C:\src\ozz-animation\build-dll\samples\framework\Release
copy %BUILD_DIR%\sample_framework_r.dll . || exit /b 1
copy %BUILD_DIR%\sample_framework_r.dll ..\lib\win\release || exit /b 1
copy %BUILD_DIR%\sample_framework_r.lib ..\lib\win\release || exit /b 1
