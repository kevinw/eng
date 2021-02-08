if exist game_dev.exe (
    del game_dev.exe || exit /b 1
)

@jai first.jai -- all && game_dev.exe %*
