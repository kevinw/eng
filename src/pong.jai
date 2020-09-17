GAME_NAME :: "pong";
#load "game_base.jai";

gameWidth  :: 640;
gameHeight :: 360;

State :: struct {
    using _base: State_Base;
}

on_host_shutdown :: () {
    game_base_shutdown();
}

update_and_draw :: () {
    using context.state;

    {
        game_base_update();
    }

    {
        game_base_push_drawing();

        {
            PushTextureMode(screen.texture);
            ClearBackground(RED);
            world_draw();
            editor_draw_world(context.state);
            screenlog.draw_world();

            editor_draw(context.state);
        }

        {
            PushShaderMode(screen.shader);
            blit_render_texture_to_screen(screen.texture);
        }
    }
}

on_host_did_reload_game_dll :: () {
    game_base_did_reload_dll();
}

on_host_init :: () {
    using context.state;

    game_base_init();

    screen.texture = LoadRenderTexture(gameWidth, gameHeight);
    screen.shader = LoadShader(null, null);

    spawn_prefab("paddle");
    //spawn_prefab("paddle_2");
}
