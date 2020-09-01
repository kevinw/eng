#import "Basic";
#import "raylib";
#import "raygui";
#import "raymath";
#import "toolbelt";
wbml :: #import "wbml";
screenlog :: #import "screenlog";
reaper :: #import "reaper";
inp :: #import "inp";

SOUND_ENABLED :: true;
#load "game_sound_soloud.jai";

#load "player.jai";
#load "enemy.jai";

#import "soloud";

#import "entity";
#load "editor.jai";

#load "live_raylib.jai";
#load "plugin_exports.jai";

#load "../lib/imgui_inspector.jai";


gameWidth :: 640;
gameHeight :: 360;
DEFAULT_CAM_ZOOM :: 1.2;
G :: 1150;
JUMP_FLOAT :: 0.39;
JUMP_FLOAT_POW :: 1.1;
GLSL_VERSION :: 330;
DEFAULT_BGM_VOLUME :: 0.03;

envitem :: (world: *World, x: float, y: float, width: float, height: float, collision: Collision_Type, color: Color) -> *Entity {
    e := create_entity(world);

    e.position.xy = v2(x, y);
    e.scale = make_Vector3(width, height, 1);

    box := add_component(e, BoxCollider);
    box.collision = .PLATFORM;

    renderer := add_component(e, RectRenderer);
    renderer.color = color;

    return e;
}

State :: type_of(state);

SpriteAnim :: struct {
    MAX_FRAME_COUNT :: 500;

    Frame :: struct {
        texture: LiveTexture;
        rect: Rectangle;
        offset: Vector2;
        duration_secs: float;
    }

    frames: [..]Frame;
    total_duration_secs: float;
}

get_rect :: (using sprite_anim: *SpriteAnim, timer: float64) -> (Rectangle, LiveTexture, int) {
    assert(total_duration_secs > 0);
    timer_mod := Math.fmod(timer, total_duration_secs);

    t := 0.0;
    for * frames {
        t += it.duration_secs;
        if t > timer_mod {
            return it.rect, it.texture, it_index;
        }
    }

    assert(false, "couldn't get a spriteanim rect");
    return .{}, 0, -1;
}

draw_sprite_anim :: (using sprite_anim: *SpriteAnim, time: float64, pos: Vector2) {
    assert(sprite_anim != null);
    assert(frames.count > 0);
    assert(frames.count < MAX_FRAME_COUNT);

    src_rect, texture, frame_index := get_rect(sprite_anim, time);
    dest_rect := rect(pos.x, pos.y, src_rect.width, src_rect.height);
    logprint("=sprite_debug", "tex: %", texture._entry.id);
    DrawTexturePro(texture, src_rect, dest_rect, sprite_anim.frames[frame_index].offset);
}

from_ase :: (sprite_anim: *SpriteAnim, filename: string) -> bool {
    assert(sprite_anim.frames.count == 0);

    Aseprite_Loader :: #import "Aseprite_Loader";
    imgs: []Aseprite_Loader.Frame;
    sprite_info := Aseprite_Loader.load(filename, *imgs);
    if !sprite_info.ok return false;

    total_width:s32 = 0;
    total_height:s32 = 0;
    for imgs {
        total_width += it.width;
        total_height = max(total_height, it.height);
    }

    atlas_img := GenImageColor(total_width, total_height, Color.{0, 0, 0, 0});
    print("generating atlas (% x %) for '%'\n", total_width, total_height, filename);
    
    dest_rect: Rectangle;
    for imgs {
        src_img := LoadImageEx(cast(*Color)it.pixels.data, it.width, it.height);
        defer UnloadImage(src_img);

        src_rect := make_Rectangle(0, 0, it.width, it.height);
        dest_rect.width = cast(float)it.width;
        dest_rect.height = cast(float)it.height;
        ImageDraw(*atlas_img, src_img, src_rect, dest_rect, WHITE);

        frame := array_add(*sprite_anim.frames);
        frame.rect = dest_rect;
        frame.duration_secs = cast(float)it.duration_ms / 1000.0;
        if sprite_info.pivot_x != -1
            frame.offset.x = cast(float)sprite_info.pivot_x;
        if sprite_info.pivot_y != -1
            frame.offset.y = cast(float)sprite_info.pivot_y;
        sprite_anim.total_duration_secs += frame.duration_secs;

        dest_rect.x += dest_rect.width;
    }

    tex := LoadTextureFromImage(atlas_img);
    live_tex := LoadLiveTexture(filename, tex);

    for imgs
        sprite_anim.frames[it_index].texture = live_tex;

    return true;
}

state: struct {
    start_canary: u32; @noui // = 0xBEEFBEEF;
    test_anim: SpriteAnim;
    ui: UI_State;
    ui_open: bool = true;
    Time: struct {
        now: float64;
        unscaled_now: float64;
        delta_time: float;
    };
    default_font: Font;
    global_time_scale:float = 1.0;

    editor: Editor;

    sound_state: Sound_State;

    live: struct {
        textures: [..]LiveTextureEntry;
        shaders:  [..]LiveShaderEntry;
    };
    muted := true;
    textures: struct {
        gino: Texture;
        evilplant: Texture;
    };
    world: World;
    sprites: struct {
        test_ase: SpriteAnim;
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

    player: Player;
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

    enemies: [..]Enemy;

    end_canary: u32; @noui // = 0xBEEFBEEF;

    debug_draw := false;
};

CameraFunc :: #type (camera: *Camera2D, player: *Player, delta: float, w: int, h: int);

cameraUpdaters :: CameraFunc.[
    UpdateCameraCenter,
    UpdateCameraCenterSmoothFollow,
    UpdateCameraEvenOutOnLanding,
    UpdateCameraPlayerBoundsPush
];

update_bgm_volume :: () {
    #if SOUND_ENABLED {
        using state.sound_state;
        Soloud_setVolume(soloud, bgm_voice, ifx state.muted then 0.0 else 1.0);
    }
}

on_host_did_reload_game_dll :: () {
    set_default_font(*state.default_font);

    ImGui_Impl_InvalidateDeviceObjects(*state.ui);
    ImGui_Impl_Init(*state.ui, GetWindowHandle());

    logprint("game", "game dll reloaded at % secs", cast(int)GetTime());
}

on_host_init :: () {
    using state;

    ImGui_Impl_CreateContext(*ui);
    ImGui_Impl_Init(*ui, GetWindowHandle());

    from_ase(*test_anim, "resources/sprites/numbers.ase");

    set_default_font(*default_font, "resources/fonts/FiraCode-VariableFont_wght.ttf");

    start_canary = 0xBEEFBEEF;
    end_canary =   0xDEADBEEF;

    #if SOUND_ENABLED
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

    player_reset(*player);

    add_enemy_at :: (x: float, y: float) #expand {
        e := array_add(*state.enemies);
        e.position.x = x;
        e.position.y = y;
    }

    add_enemy_at(400, 197);
    add_enemy_at(600, 197);

    camera.target = player.position.xy;
    camera.offset = Vector2.{ cast(float)gameWidth/2.0, cast(float)gameHeight/2.0 };
    camera.rotation = 0.0;
    camera.zoom = DEFAULT_CAM_ZOOM;

    bg.texture = LoadLiveTexture("resources/textures/space.png");
    bg.shader = LoadLiveShader("", tprint("resources/shaders/glsl%/wave.fs", GLSL_VERSION));

    my_obj := create_entity(*world);
    my_sprite := add_component(my_obj, SpriteRenderer);
    on_enable(my_sprite);
    my_sprite.entity.transform.position = Vector3.{380, 380, 0};
    my_sprite.entity.transform.scale = Vector3.{300, 200, 1};
    my_sprite.sprite = state.sprites.evilplant.idle;
    my_sprite.texture = state.textures.evilplant;

    envitem(*world, 0, 400, 1000, 200, .PLATFORM, GRAY);
    envitem(*world, 300, 200, 400, 10, .PLATFORM, GRAY);
    envitem(*world, 250, 300, 100, 10, .PLATFORM, GRAY);
    envitem(*world, 650, 300, 100, 10, .PLATFORM, GRAY);
}


on_host_shutdown :: () {
    using state;
    UnloadTexture(bg.texture);
    UnloadShader(bg.shader.resource);

    #if SOUND_ENABLED
        sound_deinit(*sound_state);
    ImGui_ImplSdl_Shutdown(*ui);
}

restart :: () {
    using state;

    camera.zoom = DEFAULT_CAM_ZOOM;
    camera.target = .{0, 0};
    player.position = .{400, 280, 0};

    {
        // Reset the song back to the beginning for now.
        using sound_state;

        #if SOUND_ENABLED
            Soloud_seek(soloud, bgm_voice, 0);
    }

    beat_timer = 0;
}

Sloppy_Math :: #import "Sloppy_Math";

change_global_time_scale :: (delta: float) {
    using state;

    STEP :: 0.2;

    global_time_scale = clamp(global_time_scale + delta * STEP, 0.1, 4.0);
    if Sloppy_Math.values_are_close(global_time_scale, 1.0)
        global_time_scale = 1;

    logprint("=time_scale", "time scale %", global_time_scale);
}

update_and_draw :: () {
    using state;

    ImGui_ProcessRaylibEvents(*state.ui);
    ImGui_Impl_NewFrame(*state.ui, GetWindowHandle(), GetScreenWidth(), GetScreenHeight());
    {
        ImGui.Begin("state", *ui_open);
        inspect("state", *state);
        ImGui.End();
    }

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


    if IsKeyPressed(.KEY_TAB)
        editor_toggle(*state);

    // update
    {
        editor_update(*state);
        screenlog.update(Time.delta_time);
        sound_update(*sound_state);
        {
            // update beat
            {
                using sound_state;

                #if SOUND_ENABLED
                    beat_timer = Soloud_getStreamTime(soloud, bgm_voice);
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
       
        player_update(*state, *player);

        enemy_update_all();

        wheel := GetMouseWheelMove();
        if wheel != 0 {
            camera.zoom = clamp(camera.zoom + cast(float)wheel * 0.05, 0.25, 3.0);
            logprint("=camera zoom", "camera zoom %", camera.zoom);
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
        if IsKeyPressed(.KEY_F) {
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

        if state.editor.play_mode == .Play
            cameraUpdaters[cameraOption](*camera, *player, Time.delta_time, gameWidth, gameHeight);

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

                // draw world
                for * world._RectRenderer {
                    if it.dead continue;
                    color2 := it.color;
                    color2.r -= 100; color2.g -= 100; color2.b -= 100;
                    DrawRectangleGradientEx(entity_rect(it.entity), it.color, color2, color2, it.color);
                }

                // draw enemies
                for * enemies enemy_draw(it);

                player_draw(*player);
                draw_sprite_anim(*test_anim, player.sprite_timer, player.position.xy);
                world_draw(*world);

                editor_draw_world(*state);
                screenlog.draw_world();
            }
            editor_draw(*state);

            // Update beats
            if nearest_marker != null {
                time_since_marker := beat_timer - state.nearest_marker.time;
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
        }
        rlglDraw();
        ImGui.Render();

        // TODO: @Speed the EndDrawing implied by PushDrawing is calling
        // rlglDraw() again, but rlglDraw() above ImGui.Render() is necessary
        // for us to be able to overlay IMGUI onto raylib
        // https://github.com/raysan5/raylib/issues/1216
    }
}

UpdateCameraCenter :: (using camera: *Camera2D, player: *Player, delta: float, width: int, height: int) {
    offset = make_Vector2(width/2, height/2);
    target = player.position.xy;
}

UpdateCameraCenterSmoothFollow :: (camera: *Camera2D, player: *Player, delta: float, width: int, height: int) {
    minSpeed :: 30.0;
    minEffectLength :: 10.0;
    fractionSpeed :: 2.9;
    
    camera.offset = make_Vector2(width/2, height/2);
    diff := player.position.xy - camera.target;
    length := Vector2Length(diff);
    
    if length > minEffectLength
    {
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
    camera.target.x = player.position.x;
    
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
        if player.can_jump && (player.speed.y == 0) && (player.position.y != camera.target.y) {
            eveningOut = 1;
            evenOutTarget = player.position.y;
        }
    }
}

UpdateCameraPlayerBoundsPush :: (camera: *Camera2D, player: *Player, delta: float, width: int, height: int) {
    bbox :: Vector2.{ 0.2, 0.2 };

    bboxWorldMin := GetScreenToWorld2D(make_Vector2((1 - bbox.x)*0.5*width, (1 - bbox.y)*0.5*height ), << camera);
    bboxWorldMax := GetScreenToWorld2D(make_Vector2((1 + bbox.x)*0.5*width, (1 + bbox.y)*0.5*height ), << camera);
    camera.offset = make_Vector2((1 - bbox.x)*0.5 * width, (1 - bbox.y)*0.5*height);

    if player.position.x < bboxWorldMin.x camera.target.x = player.position.x;
    if player.position.y < bboxWorldMin.y camera.target.y = player.position.y;
    if player.position.x > bboxWorldMax.x camera.target.x = bboxWorldMin.x + (player.position.x - bboxWorldMax.x);
    if player.position.y > bboxWorldMax.y camera.target.y = bboxWorldMin.y + (player.position.y - bboxWorldMax.y);
}