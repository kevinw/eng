if exist game_dev.exe (
    del game_dev.exe || exit /b 1
)

@set PATH=lib\imgui_docking\win\dll;%PATH%
@set PATH=lib\assimp;%PATH%
@set PATH=lib\lz4-1.9.3\win\dll;%PATH%
jai first.jai -- all && game_dev.exe %*
