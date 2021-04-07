@setlocal
@set PATH=lib\imgui_docking\win\dll;%PATH%
jai first.jai -- %* && game_dev.exe %*
