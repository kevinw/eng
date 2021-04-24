@setlocal
@set PATH=lib\imgui_docking\win\dll;%PATH%
@set PATH=lib\assimp;%PATH%
@set PATH=lib\lz4-1.9.3\win\dll;%PATH%
@jai first.jai -- --release all && game.exe %*
