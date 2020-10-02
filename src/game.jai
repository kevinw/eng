GAME_NAME :: "beat_platformer";
#load "game_base.jai";
#import "Basic";
#import "Sprite_Anim";
Math :: #import "Math";
reaper :: #import "reaper";
rl :: #import "raylib";

DEFAULT_CAM_ZOOM :: 1.2;
GLSL_VERSION :: 330;

State :: struct {
    using _base: State_Base;

    start_canary: u32; @noui // = 0xBEEFBEEF;

    muted := true;
    sprites: struct {
        test_ase: Sprite_Anim;
    };

    song: reaper.Song;
    nearest_marker: *reaper.Marker;
    bgm: Music;
    beat_timer: float64;

    bg: struct {
        timer: float64;
        texture: LiveTexture;
        shader: LiveShader;
    };

    end_canary: u32; @noui // = 0xBEEFBEEF;
};

envitem :: (world: *World, x: float, y: float, width: float, height: float, collision: Collision_Type, color: Color, is_editor: bool = false) -> *Entity {
    undo: *Undo.Impl;
    if is_editor undo = *context.state.editor.undo_state;

    entity, entity_handle := create_entity(world, "box", undo=undo);
    assert(entity != null);

    transform := get_component(entity, TRS);
    assert(transform != null);
    transform.position.xy = v2(x, y);
    transform.scale = make_Vector3(width, height, 1);

    box := add_component(entity_handle, BoxCollider, undo=undo);
    box.collision = .PLATFORM;

    renderer := add_component(entity_handle, RectRenderer, undo=undo);
    renderer.color = color;

    return entity;
}

update_bgm_volume :: () {
    using context.state;
    set_volume(sound_state.bgm_voice, ifx muted then 0.0 else 1.0);
}

set_context_funcs :: () {
    context.state.restart = restart;
    context.state.editor.callbacks.did_drag = editor_did_drag;
}

on_host_did_reload_game_dll :: () {
    set_context_funcs();
    game_base_did_reload_dll();
}

editor_did_drag :: (rect: Rectangle) {
    color := RED;
    color.b = cast(u8)random_get_within_range(100, 255);
    block := envitem(*context.state.world,
        rect.x, rect.y, rect.width, rect.height,
        .PLATFORM, color, is_editor=true);
    Undo.commit(*context.state.editor.undo_state);
}

on_host_init :: () {
    using context.state;
    set_context_funcs();

    game_base_init();
    // print("host inited. state at %. world.entities at %\n", context.state, context.state.world.entities);

    {
        using sound_state;

        #import "soloud";
        bgm_voice = Soloud_play(soloud, bgm);
    }

    start_canary = 0xBEEFBEEF;
    end_canary =   0xDEADBEEF;

    // load textures and sprites

    ok: bool;
    //ok, song = reaper.parse_reaper_project_file("resources/music/i-think-she-knows.rpp");
    ok, song = reaper.create_song_for_tempo(60);
    assert(ok);
    update_bgm_volume();

    screen.texture = LoadRenderTexture(gameWidth, gameHeight);
    screen.shader = LoadShader(null, null);

    player_entity, player_handle := spawn_prefab("player");
    player := get_component(player_entity, Player);
    player_reset(player);

    spawn_prefab("plant_chomper", v3(400, 197, 0));
    spawn_prefab("plant_chomper", v3(600, 197, 0));

    bg.texture = LoadLiveTexture("resources/textures/space.png");
    bg.shader = LoadLiveShader("", tprint("resources/shaders/glsl%/wave.fs", GLSL_VERSION));

    envitem(*world, 0,   400, 1000, 200, .PLATFORM, GRAY);
    envitem(*world, 300, 200, 400, 10, .PLATFORM, GRAY);
    envitem(*world, 250, 300, 100, 10, .PLATFORM, GRAY);
    envitem(*world, 650, 300, 100, 10, .PLATFORM, GRAY);

    cam_e, cam_eh := create_entity(*world, "camera");
    cam := add_component(cam_eh, Cam);
    cam_follow := add_component(cam_eh, Cam_Follow);
    cam_follow.target_entity = player_handle;
    cam.cam2D.zoom = DEFAULT_CAM_ZOOM;

    if false {
        r :: #bake_arguments random_get_within_range(min=0, max=1000);
        rc :: #bake_arguments random_get_within_range(min=0, max=255);
        for i: 0..100
            envitem(*world, r(), r(), r(), r(), .PLATFORM, make_Color(rc(), rc(), rc(), 255));
    }
}

on_host_shutdown :: () {
    using context.state;

    UnloadLiveTexture(bg.texture);
    UnloadShader(bg.shader.resource);

    game_base_shutdown();
}

restart :: () {
    using context.state;

    player := get_component_in_entity_named("player", Player);
    if player != null
        get_transform(player).position = .{400, 280, 0};

    // Reset the song back to the beginning for now.
    seek(sound_state.bgm_voice, 0);

    beat_timer = 0;
}

update_and_draw :: () {
    using context.state;

    #if HOTLOADING_ENABLED {
        assert(start_canary == 0xBEEFBEEF);
        if end_canary != 0xDEADBEEF {
            logprint("gamestruct", "warning: State struct changed size\n");
            end_canary = 0xDEADBEEF;
        }
    }

    game_base_update();

    // update
    {
        player := get_component_in_entity_named("player", Player);
        {
            // update beat
            {
                using sound_state;
                beat_timer = get_stream_time(bgm_voice);
            }
            bgm_bpm:float = 122.069;
            beats_per_second := bgm_bpm * (1.0 / 60.0);
            found: bool;
            nearest_marker = reaper.get_nearest_marker(song, null, beat_timer);
            if player != null {
                player.nearest_marker = nearest_marker;
                player.beat_timer = beat_timer;
            }
        }

        bg.timer += Time.delta_time * 0.2;

        //if Time.frame_count % 8 == 0 {
        set_shader_val(bg.shader, "secondes", cast(float)bg.timer);
        set_shader_val(bg.shader, "size", make_Vector2(gameWidth, gameHeight));
        set_shader_val(bg.shader, "freqX", 25.0);
        set_shader_val(bg.shader, "freqY", 25.0);
        set_shader_val(bg.shader, "ampX", 5.0);
        set_shader_val(bg.shader, "ampY", 5.0);
        set_shader_val(bg.shader, "speedX", 8.0);
        set_shader_val(bg.shader, "speedY", 8.0);
        //}
       
        if IsKeyPressed(.KEY_M) {
            muted = !muted;
            update_bgm_volume();
        }
    }

    {
        // DRAW
        game_base_push_drawing();

        {
            PushTextureMode(screen.texture);
            {
                // draw background
                PushShaderMode(bg.shader.resource);
                DrawTexture(bg.texture, 0, 0, WHITE);
                DrawTexture(bg.texture, bg.texture.width, 0, WHITE);
                DrawTexture(bg.texture, 0, bg.texture.height, WHITE);
                DrawTexture(bg.texture, bg.texture.width, bg.texture.height, WHITE);
            }
            {
                // draw foreground
                camera := get_main_camera();
                if camera != null begin_mode_2D(camera.cam2D);
                world_draw(*world);
                editor_draw_world(context.state);
                screenlog.draw_world();
                if camera != null EndMode2D();
            }


        }

        {
            PushShaderMode(screen.shader);
            blit_render_texture_to_screen(screen.texture);
            editor_draw(context.state);
        }

    }
}

