#import "Basic";
#import "raylib";
#import "raymath";
#import "toolbelt";
#import "Sprite_Anim";
Math :: #import "Math";
wbml :: #import "wbml";
screenlog :: #import "screenlog";
reaper :: #import "reaper";
inp :: #import "inp";

HOTLOADING_ENABLED :: true;

#import "game_sound_soloud";

#import "entity";
#load "editor.jai";

#import "live_raylib";
#import "Live_Types";

#load "plugin_exports.jai";

#load "../imgui_impl_gl.jai";

#add_context state: *State;

gameWidth :: 640;
gameHeight :: 360;
DEFAULT_CAM_ZOOM :: 1.2;
GLSL_VERSION :: 330;
DEFAULT_BGM_VOLUME :: 0.03;

envitem :: (world: *World, x: float, y: float, width: float, height: float, collision: Collision_Type, color: Color) -> *Entity {
    entity, entity_handle := create_entity(world);
    assert(entity != null);

    entity.position.xy = v2(x, y);
    entity.scale = make_Vector3(width, height, 1);

    box := add_component(entity_handle, BoxCollider);
    box.collision = .PLATFORM;

    renderer := add_component(entity_handle, RectRenderer);
    renderer.color = color;

    return entity;
}


State :: struct {
    start_canary: u32; @noui // = 0xBEEFBEEF;
    blob: LiveSprite;

    ui: UI_State;
    ui_open: bool = true;
    Time: struct {
        now: float64;
        unscaled_now: float64;
        delta_time: float;
    };
    default_font: Font;
    global_time_scale:float = 1.0;

    // TODO: this is a kind of weird inversion of control. other files we import
    // provide the structs that we use here. is that badly designed, or using a
    // jai feature in a way that is actually fine?
    editor: Editor;
    sound_state: Sound_State;
    live: Live_Asset_Database;

    muted := true;
    textures: struct {
        gino: Texture;
        evilplant: Texture;
    };
    world: World;
    sprites: struct {
        test_ase: Sprite_Anim;
        player: struct {
            idle: []Sprite;
            run: []Sprite;
            jump_start: []Sprite;
            jump_mid: []Sprite;
            jump_landing: []Sprite;
            attack: []Sprite;
            attack_miss: []Sprite;
            attack_air: []Sprite;
            damaged: []Sprite;
        };
        evilplant: struct {
            idle: []Sprite;
            hit: []Sprite;
            attack_left: []Sprite;
            attack_right: []Sprite;
        };
    };

    song: reaper.Song;
    nearest_marker: *reaper.Marker;
    bgm: Music;
    beat_timer: float64;

    player: *Player;
    scene: struct {};
    camera: Camera2D;

    cameraOption: int = 1;

    bg: struct {
        timer: float64;
        texture: LiveTexture;
        shader: LiveShader;
    };

    screen: struct {
        shader: Shader;
        texture: RenderTexture;
    };

    debug_draw := false;
    restart: ();

    end_canary: u32; @noui // = 0xBEEFBEEF;
};

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

on_host_init :: () {
    using context.state;
    set_context_funcs();
    init_world(*world);

    gl_load(*gl);
    ImGui_Impl_CreateContext(*ui);
    ImGui.StyleColorsDark();
    style := ImGui.GetStyle();
    style.ScaleAllSizes(style, 1.2);

    io := ImGui.GetIO();
    io.Fonts.AddFontFromFileTTF(io.Fonts, "resources/fonts/FiraCode-VariableFont_wght.ttf", 26);

    ImGui_Impl_Init(*ui, GetWindowHandle());

    blob = LoadLiveSprite("resources/sprites/blob.aseprite");

    set_default_font(*default_font, "resources/fonts/FiraCode-VariableFont_wght.ttf");

    start_canary = 0xBEEFBEEF;
    end_canary =   0xDEADBEEF;

    sound_init(*sound_state);
    
    // load textures and sprites
    textures.gino = LoadTexture("resources/sprites/gino.png");
    {
        using sprites.player;
        gino_sprites := parse_spriter_atlas("resources/sprites/gino.atlas");
        idle         = sprites_with_prefix(gino_sprites, "Idle/");
        run          = sprites_with_prefix(gino_sprites, "Run/");
        jump_start   = sprites_with_prefix(gino_sprites, "Jump/start/");
        jump_mid     = sprites_with_prefix(gino_sprites, "Jump/mid/");
        jump_landing = sprites_with_prefix(gino_sprites, "Jump/landing/");
        attack       = sprites_with_prefix(gino_sprites, "Attacks/A/");
        attack_miss  = sprites_with_prefix(gino_sprites, "Throw/Throw Attack/");
        attack_air   = sprites_with_prefix(gino_sprites, "Attack in jump/");
        damaged      = sprites_with_prefix(gino_sprites, "Damage/");
    }

    textures.evilplant = LoadTexture("resources/sprites/evilplant.png");
    {
        using sprites.evilplant;
        evilplant_sprites := parse_spriter_atlas("resources/sprites/evilplant.atlas");
        idle = sprites_with_prefix(evilplant_sprites, "Idle/");
        hit  = sprites_with_prefix(evilplant_sprites, "Hit/");
        attack_left = sprites_with_prefix(evilplant_sprites, "Attack_Left/");
        attack_right = sprites_with_prefix(evilplant_sprites, "Attack_Right/");
    }

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


    /*
    my_obj, my_obj_handle := create_entity(*world);
    my_obj.transform.position = Vector3.{380, 380, 0};
    my_obj.transform.scale = Vector3.{300, 200, 1};

    my_sprite := add_component(my_obj_handle, SpriteRenderer);
    my_sprite.sprite = sprites.evilplant.idle;
    my_sprite.texture = textures.evilplant;
    */

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

    World.deinit(*world);

    UnloadLiveTexture(bg.texture);
    UnloadShader(bg.shader.resource);

    sound_deinit(*sound_state);
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

Sloppy_Math :: #import "Sloppy_Math";

change_global_time_scale :: (delta: float) {
    using context.state;

    STEP :: 0.2;

    global_time_scale = clamp(global_time_scale + delta * STEP, 0.1, 4.0);
    if Sloppy_Math.values_are_close(global_time_scale, 1.0)
        global_time_scale = 1;

    logprint("=time_scale", "time scale %", global_time_scale);
}

update_and_draw :: () {
    using context.state;

    ImGui_SetMouseEvents(*ui,
        left = IsMouseButtonDown(.MOUSE_LEFT_BUTTON),
        middle = IsMouseButtonDown(.MOUSE_MIDDLE_BUTTON),
        right = IsMouseButtonDown(.MOUSE_RIGHT_BUTTON),
        wheel = cast(float)GetMouseWheelMove());
    ImGui_Impl_NewFrame(*ui, GetWindowHandle(), GetScreenWidth(), GetScreenHeight());

    #if HOTLOADING_ENABLED {
        assert(start_canary == 0xBEEFBEEF);
        if end_canary != 0xDEADBEEF {
            logprint("gamestruct", "warning: State struct changed size\n");
            end_canary = 0xDEADBEEF;
        }
    }

    absolute_delta_time := GetFrameTime();

    Time.delta_time = global_time_scale * absolute_delta_time;
    Time.now += Time.delta_time;
    Time.unscaled_now = GetTime();


    if IsKeyPressed(.KEY_TAB) || IsGamepadButtonPressed(0, .GAMEPAD_BUTTON_MIDDLE_RIGHT)
        editor_toggle(context.state);

    // update
    {
        editor_update(context.state);
        screenlog.update(Time.delta_time);
        sound_update(*sound_state);
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

        shift := IsKeyDown(.KEY_LEFT_SHIFT) || IsKeyDown(.KEY_RIGHT_SHIFT);
        
        if IsKeyPressed(.KEY_R) && !shift restart();
        if IsKeyPressed(.KEY_MINUS) change_global_time_scale(-1);
        if IsKeyPressed(.KEY_EQUAL)  change_global_time_scale(+1);
        if IsKeyPressed(.KEY_D) && shift {
            debug_draw = !debug_draw;
            logprint("=debug_draw", "debug_draw is now %\n", debug_draw);
        }
        if IsKeyPressed(.KEY_C) cameraOption = (cameraOption + 1) % cameraUpdaters.count;
        if IsKeyPressed(.KEY_F) || IsGamepadButtonPressed(0, .GAMEPAD_BUTTON_MIDDLE_LEFT) {
            USE_REAL_FULLSCREEN :: false;
            if USE_REAL_FULLSCREEN {
                ToggleFullscreen();
            } else {
                ToggleFakeFullscreen();
            }
        }
        if IsKeyPressed(.KEY_M) {
            muted = !muted;
            update_bgm_volume();
        }

        if context.state.editor.play_mode == .Play
            cameraUpdaters[cameraOption](*camera, player, Time.delta_time, gameWidth, gameHeight);

        world_update(*world, Time.delta_time);
    }

    {
        // DRAW
        PushDrawing();
        {
            PushTextureMode(screen.texture);

            if 1 {
                // draw background
                PushShaderMode(bg.shader.resource);
                DrawTexture(bg.texture, 0, 0, WHITE);
                DrawTexture(bg.texture, bg.texture.width, 0, WHITE);
                DrawTexture(bg.texture, 0, bg.texture.height, WHITE);
                DrawTexture(bg.texture, bg.texture.width, bg.texture.height, WHITE);
            } else {
                ClearBackground(BLACK);
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
        rlglDraw();

        ImGui.Render();
        ImGui_Impl_RenderDrawData(*context.state.ui, ImGui.GetDrawData());

        // TODO: @Speed the EndDrawing implied by PushDrawing is calling
        // rlglDraw() again, but rlglDraw() above ImGui.Render() is necessary
        // for us to be able to overlay IMGUI onto raylib
        // https://github.com/raysan5/raylib/issues/1216
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
