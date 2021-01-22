setlocal
cd /D "%~dp0"

cd subrepo\assimp || exit /b 1
if not exist build mkdir build
cd build
cmake .. || exit /b 1
cmake --build . --config Release || exit /b 1
