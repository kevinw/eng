GAME_NAME :: "pong";
#load "game_base.jai";

State :: struct {
    using _base: State_Base;
}

update_and_draw :: () {
    using context.state;

    {
        game_base_update();
    }

    {
        game_base_push_drawing();

        {
            rl.PushTextureMode(screen.texture);
            rl.ClearBackground(rl.BLACK);
            world_draw();
            editor_draw_world(context.state);
            screenlog.draw_world();
            editor_draw(context.state);
        }

        {
            rl.PushShaderMode(screen.shader);
            blit_render_texture_to_screen(screen.texture);
        }
    }
}

on_host_init :: () {
    using context.state;

    game_base_init();

    screen.texture = rl.LoadRenderTexture(gameWidth, gameHeight);
    screen.shader = rl.LoadShader(null, null);

    p1 := get_component(spawn_prefab("paddle", v3(200, 50, 0)), Pong_Paddle);
    p1.player_index = 0;

    p2 := get_component(spawn_prefab("paddle", v3(200, 320, 0)), Pong_Paddle);
    p2.player_index = 1;

    ball := spawn_prefab("pong_ball");
    get_transform(ball).position.xy = v2(100, 100);
}

on_host_did_reload_game_dll :: () {
    game_base_did_reload_dll();
}

on_host_shutdown :: () {
    game_base_shutdown();
}

#scope_file

rl :: #import "raylib";
