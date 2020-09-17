GAME_NAME :: "pong";
#load "game_base.jai";

State :: struct {
    using _base: State_Base;
}

on_host_shutdown :: () {
    game_base_shutdown();
}

update_and_draw :: () {
    {
        game_base_update();
    }
    {
        game_base_push_drawing();
        editor_draw(context.state);
        ClearBackground(RED);
        DrawText("PONG?", 0, 0, 32, WHITE);
    }
}

on_host_did_reload_game_dll :: () {
    using context.state;

    set_default_font(*default_font);

    gl_load(*gl);
    ImGui_Impl_DLL_Was_Reloaded(*context.state.ui);

    logprint("game", "game dll reloaded at % secs", cast(int)GetTime());
}

on_host_init :: () {
    game_base_init();
}
