#import "Basic";
#load "game_base.jai";
#import "Sprite_Anim";
Math :: #import "Math";
wbml :: #import "wbml";
reaper :: #import "reaper";

gameWidth  :: 640;
gameHeight :: 360;
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

    player: *Player;
    scene: struct {};

    cameraOption: int = 1;

    bg: struct {
        timer: float64;
        texture: LiveTexture;
        shader: LiveShader;
    };

    end_canary: u32; @noui // = 0xBEEFBEEF;
};

envitem :: (world: *World, x: float, y: float, width: float, height: float, collision: Collision_Type, color: Color) -> *Entity {
    entity, entity_handle := create_entity(world, "box");
    assert(entity != null);

    entity.position.xy = v2(x, y);
    entity.scale = make_Vector3(width, height, 1);

    box := add_component(entity_handle, BoxCollider);
    box.collision = .PLATFORM;

    renderer := add_component(entity_handle, RectRenderer);
    renderer.color = color;

    return entity;
}



CameraFunc :: #type (camera: *Camera2D, player: *Player, delta: float, w: int, h: int);

cameraUpdaters :: CameraFunc.[
    UpdateCameraCenter,
    UpdateCameraCenterSmoothFollow,
    UpdateCameraEvenOutOnLanding,
    UpdateCameraPlayerBoundsPush
];

update_bgm_volume :: () {
    using context.state;
    set_volume(sound_state.bgm_voice, ifx muted then 0.0 else 1.0);
}

set_context_funcs :: () {
    context.state.restart = restart;
}

on_host_did_reload_game_dll :: () {
    using context.state;
    set_context_funcs();
    set_default_font(*default_font);

    gl_load(*gl);
    ImGui_Impl_DLL_Was_Reloaded(*context.state.ui);

    //ImGui_Impl_Init(*ui, GetWindowHandle());
    logprint("game", "game dll reloaded at % secs", cast(int)GetTime());
}

editor_did_drag :: (rect: Rectangle) {
    color := RED;
    color.b = cast(u8)random_get_within_range(100, 255);
    block := envitem(*context.state.world,
        rect.x, rect.y, rect.width, rect.height,
        .PLATFORM, color);
}

on_host_init :: () {
    using context.state;
    set_context_funcs();
    editor.callbacks.did_drag = editor_did_drag;

    game_base_init();

    start_canary = 0xBEEFBEEF;
    end_canary =   0xDEADBEEF;

    // load textures and sprites

    ok: bool;
    //ok, song = reaper.parse_reaper_project_file("resources/music/i-think-she-knows.rpp");
    ok, song = reaper.create_song_for_tempo(60);
    assert(ok);
    //bgm = LoadMusicStream("resources/music/Jivasifoki.mp3");
    //bgm = LoadMusicStream("resources/music/kick-snare-60.mp3");
    update_bgm_volume();
    //SetMusicLoopCount(bgm, 0);
    //PlayMusicStream(bgm);

    screen.texture = LoadRenderTexture(gameWidth, gameHeight);
    screen.shader = LoadShader(null, null);

    player_entity := spawn_prefab("player");
    player = get_component(player_entity, Player);
    player_reset(player);

    spawn_prefab("plant_chomper", v3(400, 197, 0));
    spawn_prefab("plant_chomper", v3(600, 197, 0));

    camera.target = get_transform(player).position.xy;
    camera.offset = Vector2.{ cast(float)gameWidth/2.0, cast(float)gameHeight/2.0 };
    camera.rotation = 0.0;
    camera.zoom = DEFAULT_CAM_ZOOM;

    bg.texture = LoadLiveTexture("resources/textures/space.png");
    bg.shader = LoadLiveShader("", tprint("resources/shaders/glsl%/wave.fs", GLSL_VERSION));

    envitem(*world, 0,   400, 1000, 200, .PLATFORM, GRAY);
    envitem(*world, 300, 200, 400, 10, .PLATFORM, GRAY);
    envitem(*world, 250, 300, 100, 10, .PLATFORM, GRAY);
    envitem(*world, 650, 300, 100, 10, .PLATFORM, GRAY);

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

    camera.zoom = DEFAULT_CAM_ZOOM;
    camera.target = .{0, 0};
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
            player.nearest_marker = nearest_marker;
            player.beat_timer = beat_timer;
        }

        bg.timer += Time.delta_time * 0.2;

        set_shader_val(bg.shader, "secondes", cast(float)bg.timer);
        set_shader_val(bg.shader, "size", make_Vector2(gameWidth, gameHeight));
        set_shader_val(bg.shader, "freqX", 25.0);
        set_shader_val(bg.shader, "freqY", 25.0);
        set_shader_val(bg.shader, "ampX", 5.0);
        set_shader_val(bg.shader, "ampY", 5.0);
        set_shader_val(bg.shader, "speedX", 8.0);
        set_shader_val(bg.shader, "speedY", 8.0);
       
        if context.state.editor.play_mode == .Play {
            wheel := GetMouseWheelMove();
            if wheel != 0 {
                camera.zoom = clamp(camera.zoom + cast(float)wheel * 0.05, 0.25, 3.0);
                logprint("=camera zoom", "camera zoom %", camera.zoom);
            }
        }

        if IsKeyPressed(.KEY_C) cameraOption = (cameraOption + 1) % cameraUpdaters.count;
        if IsKeyPressed(.KEY_M) {
            muted = !muted;
            update_bgm_volume();
        }

        if context.state.editor.play_mode == .Play
            cameraUpdaters[cameraOption](*camera, player, Time.delta_time, gameWidth, gameHeight);
    }

    {
        // DRAW
        game_base_push_drawing();

        {
            PushTextureMode(screen.texture);

            // draw background
            {
                PushShaderMode(bg.shader.resource);
                DrawTexture(bg.texture, 0, 0, WHITE);
                DrawTexture(bg.texture, bg.texture.width, 0, WHITE);
                DrawTexture(bg.texture, 0, bg.texture.height, WHITE);
                DrawTexture(bg.texture, bg.texture.width, bg.texture.height, WHITE);
            }
            {
                // draw foreground
                push_mode_2D(camera);
                world_draw(*world);
                editor_draw_world(context.state);
                screenlog.draw_world();
            }
            editor_draw(context.state);

            // Update beats
            if nearest_marker != null {
                time_since_marker := beat_timer - context.state.nearest_marker.time;
                alpha := max(cast(float64)0.0, 1.0 - Math.abs(time_since_marker));
                color := Vector4.{1, 1, 1, 1};
                if time_since_marker < 0 color = Vector4.{0, 0, 0, 1};
                color.w = cast(float32)alpha;
                draw_text(tprint("%", nearest_marker.beat_type), 596, 5, 20, ColorFromNormalized(color));
            }
        }

        {
            PushShaderMode(screen.shader);
            blit_render_texture_to_screen(screen.texture);

            editor_draw_ui();
            screenlog.draw();
            host_debug_draw();
        }

    }
}

UpdateCameraCenter :: (using camera: *Camera2D, player: *Player, delta: float, width: int, height: int) {
    offset = make_Vector2(width/2, height/2);
    target = get_transform(player).position.xy;
}

UpdateCameraCenterSmoothFollow :: (camera: *Camera2D, player: *Player, delta: float, width: int, height: int) {
    minSpeed :: 30.0;
    minEffectLength :: 10.0;
    fractionSpeed :: 2.9;
    
    camera.offset = make_Vector2(width/2, height/2);
    diff := get_transform(player).position.xy - camera.target;
    length := Vector2Length(diff);
    
    if length > minEffectLength {
        speed := max(fractionSpeed*length, minSpeed);
        camera.target = Vector2Add(camera.target, Vector2Scale(diff, speed*delta/length));
        //camera.target.x = round(camera.target.x);
        //camera.target.y = round(camera.target.y);
    }
}

even_out_state: struct {
    eveningOut: int;
    evenOutTarget: float;
};

UpdateCameraEvenOutOnLanding :: (camera: *Camera2D, player: *Player, delta: float, width: int, height: int) {
    using even_out_state;

    evenOutSpeed :: 700;
    
    camera.offset = make_Vector2(width/2, height/2);
    transform := get_transform(player);
    camera.target.x = transform.position.x;
    
    if eveningOut {
        if evenOutTarget > camera.target.y {
            camera.target.y += evenOutSpeed*delta;
            
            if camera.target.y > evenOutTarget {
                camera.target.y = evenOutTarget;
                eveningOut = 0;
            }
        } else {
            camera.target.y -= evenOutSpeed*delta;
            
            if camera.target.y < evenOutTarget {
                camera.target.y = evenOutTarget;
                eveningOut = 0;
            }
        }
    } else {
        if (player.speed.y == 0) && (transform.position.y != camera.target.y) {
            eveningOut = 1;
            evenOutTarget = transform.position.y;
        }
    }
}

UpdateCameraPlayerBoundsPush :: (camera: *Camera2D, player: *Player, delta: float, width: int, height: int) {
    bbox :: Vector2.{ 0.2, 0.2 };

    bboxWorldMin := GetScreenToWorld2D(make_Vector2((1 - bbox.x)*0.5*width, (1 - bbox.y)*0.5*height ), << camera);
    bboxWorldMax := GetScreenToWorld2D(make_Vector2((1 + bbox.x)*0.5*width, (1 + bbox.y)*0.5*height ), << camera);
    camera.offset = make_Vector2((1 - bbox.x)*0.5 * width, (1 - bbox.y)*0.5*height);

    ok, player_entity := get_entity(player.entity);
    assert(ok);
    transform := *player_entity.transform;

    if transform.position.x < bboxWorldMin.x camera.target.x = transform.position.x;
    if transform.position.y < bboxWorldMin.y camera.target.y = transform.position.y;
    if transform.position.x > bboxWorldMax.x camera.target.x = bboxWorldMin.x + (transform.position.x - bboxWorldMax.x);
    if transform.position.y > bboxWorldMax.y camera.target.y = bboxWorldMin.y + (transform.position.y - bboxWorldMax.y);
}
