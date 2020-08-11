#import "Basic";
#import "raylib";
#import "raymath";
#import "toolbelt";
wbml :: #import "wbml";
screenlog :: #import "screenlog";
reaper :: #import "reaper";

#import "entity";

gameWidth :: 640;
gameHeight :: 360;
DEFAULT_CAM_ZOOM :: 1.2;
PLAYER_JUMP_SPD :: 350;
PLAYER_HOR_SPD :: 220;
G :: 1150;
JUMP_FLOAT :: 0.39;
JUMP_FLOAT_POW :: 1.1;
GLSL_VERSION :: 330;
DEFAULT_BGM_VOLUME :: 0.03;

Entity :: struct {
    position: Vector2;
}

Enemy :: struct {
    using entity: Entity;
    sprite_timer: float64;
}

Player :: struct {
    using entity: Entity;

    speed: float;
    can_jump: bool;
    grounded: bool;

    jump_button_time: float64;
    jump_button_last_frame: bool;
    last_jump_time:float64 = -10000;

    last_attack_time:float64 = -10000;
    attack_did_hit: bool;

    last_grounded_time:float64 = -10000;

    horizontal_movement: float;
    last_direction: float;

    sprite_timer: float64;
    walk_timer: float64;
}

EnvItem :: struct {
    rect: Rectangle;
    blocking: int;
    color: Color;
}

state: struct {
    txt: *Worldspace_Text;
    muted := false;
    textures: struct {
        gino: Texture;
        evilplant: Texture;
    };
    world: World;
    worldspace_texts: [..]struct {
        message: string;
        position: Vector2;
        time: float64;
    };
    sprites: struct {
        player: struct {
            idle: []Sprite;
            run: []Sprite;
            jump_start: []Sprite;
            jump_mid: []Sprite;
            jump_landing: []Sprite;
            attack: []Sprite;
            attack_miss: []Sprite;
            attack_air: []Sprite;
        };
        evilplant: struct {
            idle: []Sprite;
            hit: []Sprite;
        };
    };

    song: reaper.Song;
    nearest_marker: *reaper.Marker;
    bgm: Music;
    beat_timer: float64;

    player: Player;
    envItems: [..]EnvItem;
    camera: Camera2D;

    cameraOption: int = 2;

    bg: struct {
        texture: Texture;
        timer: float64;
        shader: Shader;
    };

    screen: struct {
        shader: Shader;
        texture: RenderTexture;
    };

    enemies: [..]Enemy;
};

CameraFunc :: #type (camera: *Camera2D, player: *Player, items: []EnvItem, delta: float, w: int, h: int);

cameraUpdaters :: CameraFunc.[
    UpdateCameraCenter,
    UpdateCameraCenterInsideMap,
    UpdateCameraCenterSmoothFollow,
    UpdateCameraEvenOutOnLanding,
    UpdateCameraPlayerBoundsPush
];

update_bgm_volume :: () {
    using state;
    SetMusicVolume(bgm, ifx muted then 0 else 0.03);
}

#program_export
plugin_init :: (old_value: *void) {

    using state;

    if old_value != null {
        old_state := cast(*type_of(state))old_value;
        state = << old_state;
        free(old_state);
    } else {
        // actual init

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
        }

        textures.evilplant = LoadTexture("resources/sprites/evilplant.png");
        {
            using sprites.evilplant;
            evilplant_sprites := parse_spriter_atlas("resources/sprites/evilplant.atlas");
            idle = sprites_with_prefix(evilplant_sprites, "Idle/");
            hit  = sprites_with_prefix(evilplant_sprites, "Hit/");
        }

        ok: bool;
        //ok, song = reaper.parse_reaper_project_file("resources/music/i-think-she-knows.rpp");
        ok, song = reaper.create_song_for_tempo(60);
        assert(ok);
        //bgm = LoadMusicStream("resources/music/Jivasifoki.mp3");
        bgm = LoadMusicStream("resources/music/kick-snare-60.mp3");
        update_bgm_volume();
        SetMusicLoopCount(bgm, 0);
        PlayMusicStream(bgm);

        screen.texture = LoadRenderTexture(gameWidth, gameHeight);
        screen.shader = LoadShader(null, null);

        player.position = Vector2.{ 400, 280 };
        player.speed = 0;
        player.can_jump = false;

        array_add(*envItems,
            //EnvItem.{.{ 0, 0, 1000, 400 },   0, LIGHTGRAY },
            EnvItem.{.{ 0, 400, 1000, 200 }, 1, GRAY },
                   .{.{ 300, 200, 400, 10 }, 1, GRAY },
                   .{.{ 250, 300, 100, 10 }, 1, GRAY },
                   .{.{ 650, 300, 100, 10 }, 1, GRAY }
        );

        enemy: Enemy;
        enemy.position.x = 400;
        enemy.position.y = 197;
        array_add(*enemies, enemy);
        
        {
            e := array_add(*enemies);
            e.position.x = 600;
            e.position.y = 197;
        }
        
        camera.target = player.position;
        camera.offset = Vector2.{ cast(float)gameWidth/2.0, cast(float)gameHeight/2.0 };
        camera.rotation = 0.0;
        camera.zoom = DEFAULT_CAM_ZOOM;

        bg.texture = LoadTexture("resources/textures/space.png");
        bg.shader = LoadShader(null, TextFormat("resources/shaders/glsl%i/wave.fs", GLSL_VERSION));

        test := create_entity(*world);
        txt = add_component(test, Worldspace_Text);
    }

    set_shader_val(bg.shader, "size", make_Vector2(gameWidth, gameHeight));
    set_shader_val(bg.shader, "freqX", 25.0);
    set_shader_val(bg.shader, "freqY", 25.0);
    set_shader_val(bg.shader, "ampX", 5.0);
    set_shader_val(bg.shader, "ampY", 5.0);
    set_shader_val(bg.shader, "speedX", 8.0);
    set_shader_val(bg.shader, "speedY", 8.0);
}

#program_export
plugin_deinit :: (shutting_down: bool) -> *void {
    using state;

    if shutting_down {
        UnloadTexture(bg.texture);
        UnloadShader(bg.shader);
        UnloadMusicStream(bgm);
        return null;
    }

    heap_state := cast(*type_of(state))alloc(size_of(type_of(state)) * 2); // * 2 for adding extra things on the end
    << heap_state = state;
    return heap_state;
}

restart :: () {
    using state;

    camera.zoom = DEFAULT_CAM_ZOOM;
    camera.target = .{0, 0};
    player.position = .{400, 280};

    // Reset the song back to the beginning for now.
    StopMusicStream(bgm);
    PlayMusicStream(bgm);
    beat_timer = 0;
}

#program_export
update_and_draw :: () {
    using state;

    deltaTime := GetFrameTime();

    // update
    {
        screenlog.update(deltaTime);

        UpdateMusicStream(bgm);

        {
            // update beat
            beat_timer = GetMusicTimePlayed(bgm);
            bgm_bpm:float = 122.069;
            beats_per_second := bgm_bpm * (1.0 / 60.0);
            found: bool;
            nearest_marker = reaper.get_nearest_marker(song, null, beat_timer);
        }

        bg.timer += deltaTime * 0.2;

        set_shader_val(bg.shader, "secondes", cast(float)bg.timer);
       
        player_update(*player, envItems, deltaTime);
        txt.position = player.position;

        for * enemies
            it.sprite_timer += deltaTime;

        camera.zoom += cast(float)GetMouseWheelMove() * 0.05;
        
        camera.zoom = clamp(camera.zoom, 0.25, 3.0);
        
        if IsKeyPressed(.KEY_R) restart();
        if IsKeyPressed(.KEY_C) cameraOption = (cameraOption + 1) % cameraUpdaters.count;
        if IsKeyPressed(.KEY_F) ToggleFullscreen();
        if IsKeyPressed(.KEY_M) {
            muted = !muted;
            update_bgm_volume();
        }

        cameraUpdaters[cameraOption](*camera, *player, envItems, deltaTime, gameWidth, gameHeight);

        now := GetTime();
        for * worldspace_texts
            if now - it.time > 2 remove it;

        world_update(*world, deltaTime);
    }

    {
        // DRAW
        BeginDrawing();
        defer EndDrawing();
        {
            BeginTextureMode(screen.texture);
            defer EndTextureMode();

            {
                // draw background
                BeginShaderMode(bg.shader);
                defer EndShaderMode();
                DrawTexture(bg.texture, 0, 0, WHITE);
                DrawTexture(bg.texture, bg.texture.width, 0, WHITE);
                DrawTexture(bg.texture, 0, bg.texture.height, WHITE);
                DrawTexture(bg.texture, bg.texture.width, bg.texture.height, WHITE);
            }
            {
                // draw foreground
                BeginMode2D(camera);
                defer EndMode2D();

                // draw world
                for * envItems {
                    color := it.color;
                    color2 := color;
                    color2.r -= 100; color2.g -= 100; color2.b -= 100;
                    DrawRectangleGradientEx(it.rect, color, color2, color2, color);
                }

                // draw enemies
                for * enemies {
                    fps := 10;
                    sprite_rect, offset := sprite_get_rect(sprites.evilplant.idle, it.sprite_timer, fps);
                    dest_rect_pos := it.position - v2(10, 37) + offset;
                    dest_rect := rect(dest_rect_pos.x, dest_rect_pos.y, sprite_rect.width, sprite_rect.height);
                    DrawTexturePro(textures.evilplant, sprite_rect, dest_rect, v2(0, 0), 0, WHITE);
                }

                player_draw(*player);
                world_draw(*world);
            }

            // Update beats
            if nearest_marker != null {
                time_since_marker := beat_timer - state.nearest_marker.time;
                alpha := max(cast(float64)0.0, 1.0 - Math.abs(time_since_marker));
                color := Vector4.{1, 1, 1, 1};
                color.w = cast(float32)alpha;
                DrawText(tprint("%", nearest_marker.beat_type), 16, 10, 40, ColorFromNormalized(color));
            }
        }

        {
            BeginShaderMode(screen.shader);
            defer EndShaderMode();
            blit_render_texture_to_screen(screen.texture);
            screenlog.draw();
        }
    }
}

sprite_get_rect :: (spr: []Sprite, timer: float64, fps: int, flip_x := false) -> (rect: Rectangle, offset: Vector2) {
    sprite_index := cast(int)(timer * fps);
    while sprite_index >= spr.count sprite_index -= spr.count;
    s := *spr[sprite_index];
    offset := v2(s.offset.x, s.offset.y);
    if flip_x
        offset.x = cast(float)(-s.size.x - s.offset.x);
    return rect(s.xy.x, s.xy.y, s.size.x, s.size.y), offset;
}

ATTACK_FPS :: 13;

player_is_attacking :: (player: *Player) -> bool {
    return (GetTime() - player.last_attack_time) < cast(float)state.sprites.player.attack.count/ATTACK_FPS;
}

player_draw :: (using player: *Player) {
    attacking := player_is_attacking(player);

    spr: []Sprite;
    fps: int;
    timer: float64 = sprite_timer;

    // Should this be an argument? Probably. I think we want "now" to stay the
    // same, except maybe for graphics-y interpolated things.
    now := GetTime(); 
    
    {
        using state.sprites.player;
        if !grounded {
            if attacking {
                spr = attack_air;
                fps = ATTACK_FPS;
            } else {
                fps = 9;
                if now - player.last_jump_time < cast(float)state.sprites.player.jump_start.count/fps
                    spr = jump_start;
                else 
                    spr = jump_mid;
            }
        } else if attacking {
            spr = ifx attack_did_hit then attack else attack_miss;
            fps = ATTACK_FPS;
        } else if Math.abs(horizontal_movement) > 0 {
            fps = 18;
            spr = run;
            timer = walk_timer;
        } else {
            fps = 10;
            if now - player.last_grounded_time < cast(float)state.sprites.player.jump_landing.count/fps
                spr = jump_landing;
            else
                spr = idle;
        }
    }

    flip_x := last_direction < 0;
    sprite_rect, offset := sprite_get_rect(spr, timer, fps, last_direction < 0);

    x_offset := 21 * (ifx flip_x then -1 else 1);
    dest_rect_pos := position - v2(x_offset, 38) + offset;
    dest_rect := rect(dest_rect_pos.x, dest_rect_pos.y, sprite_rect.width, sprite_rect.height);
    sprite_rect.width *= ifx flip_x then -1 else 1;
    DrawTexturePro(state.textures.gino, sprite_rect, dest_rect, v2(0, 0), 0, WHITE);

    // debug pos
    //w := 6;
    //DrawRectangleV(position - v2(w/2, w/2), make_Vector2(w, w), RED);

}

add_worldspace_text :: (message: string, pos: Vector2) {
    txt := array_add(*state.worldspace_texts);
    txt.message = message;
    txt.position = pos;
    txt.time = GetTime();
}

player_update :: (using player: *Player, envItems: []EnvItem, delta_time: float)
{
    sprite_timer += delta_time;

    horizontal_movement = 0;
    attacking := player_is_attacking(player);

    // keyboard movement
    if IsKeyDown(.KEY_LEFT) || IsKeyDown(.KEY_A)  horizontal_movement -= 1.0;
    if IsKeyDown(.KEY_RIGHT) || IsKeyDown(.KEY_D) horizontal_movement += 1.0;

    // gamepad movement
    gamepad :: 0;
    horizontal_movement += get_gamepad_stick(gamepad, .GAMEPAD_AXIS_LEFT_X, .GAMEPAD_AXIS_UNKNOWN).x;
    horizontal_movement += get_gamepad_dpad(gamepad).x;

    if horizontal_movement > 1  horizontal_movement = 1;
    if horizontal_movement < -1 horizontal_movement = -1;

    if attacking && player.grounded
        horizontal_movement = 0;

    position.x += horizontal_movement * PLAYER_HOR_SPD * delta_time;
    if Math.abs(horizontal_movement) > 0
        last_direction = cast(float)sign(horizontal_movement);
    walk_timer += delta_time * Math.abs(horizontal_movement);

    jump_button_this_frame := IsKeyDown(.KEY_SPACE) ||
                              IsKeyDown(.KEY_W) ||
                              IsKeyDown(.KEY_UP) ||
                              IsGamepadButtonDown(gamepad, .GAMEPAD_BUTTON_RIGHT_FACE_DOWN);
    

    now := GetTime();
    if jump_button_this_frame && !jump_button_last_frame
        jump_button_time = now;

    jump_button_last_frame = jump_button_this_frame;

    time_since_marker := state.beat_timer - state.nearest_marker.time;

    allow_all_beats := false;

    // ATTACK
    if !attacking && (IsKeyDown(.KEY_E) || IsGamepadButtonDown(gamepad, .GAMEPAD_BUTTON_RIGHT_FACE_LEFT)) {
        attack_offset :: Vector2.{0, -20};
        if allow_all_beats || (Math.abs(time_since_marker) < .2 && state.nearest_marker.beat_type == .Kick) {
            logprint("player", "HIT attack");
            add_worldspace_text("HIT", player.position + attack_offset);
            last_attack_time = now;
            attack_did_hit = true;
            sprite_timer = 0;
        } else {
            logprint("player", "MISS attack");
            add_worldspace_text("MISS", player.position + attack_offset);
            last_attack_time = now;
            attack_did_hit = false;
            sprite_timer = 0;
        }
    }

    // JUMP
    if !attacking && grounded && (now - jump_button_time) < 0.15 {
        beat_match_type := state.nearest_marker.beat_type == .Snare;
        if allow_all_beats || (Math.abs(time_since_marker) < .2 && beat_match_type) {
            add_worldspace_text("HIT", player.position);
            logprint("player", "jump %", time_since_marker);
            speed = -PLAYER_JUMP_SPD;
        } else {
            add_worldspace_text("MISS", player.position);
            early_late := ifx time_since_marker > 0 then "late" else "early";
            if !beat_match_type early_late = "wrong beat";
            logprint("player", "MISS % jump %", early_late, time_since_marker);
            speed = -PLAYER_JUMP_SPD * 0.25;
        }

        grounded = false;
        can_jump = false;
        last_jump_time = now;
    }

    hitObstacle := false;

    // COLLISION
    for * envItems {
        p := *position;
        if it.blocking &&
           it.rect.x <= p.x && it.rect.x + it.rect.width >= p.x &&
           it.rect.y >= p.y && it.rect.y < p.y + speed * delta_time
        {
            hitObstacle = true;
            speed = 0.0;
            p.y = it.rect.y;
            if !grounded 
                last_grounded_time = now;
            grounded = true;
        }
    }

    // GRAVITY
    if !hitObstacle {
        position.y += speed * delta_time;
        drag := G * delta_time;
        if speed < 0 && jump_button_this_frame
            drag = Math.pow(drag * JUMP_FLOAT, JUMP_FLOAT_POW);
        speed += drag;
        can_jump = false;
    } else {
        can_jump = true;
    }

    // catch player falling off the universe
    if position.y > 1000 restart();
}

UpdateCameraCenter :: (using camera: *Camera2D, player: *Player, envItems: []EnvItem, delta: float, width: int, height: int)
{
    offset = make_Vector2(width/2, height/2);
    target = player.position;
}

UpdateCameraCenterInsideMap :: (camera: *Camera2D, player: *Player, envItems: []EnvItem, delta: float, width: int, height: int)
{
    camera.target = player.position;
    camera.offset = make_Vector2(width/2, height/2);

    minX :float = 1000;
    minY :float = 1000;
    maxX :float = -1000;
    maxY :float = -1000;
    
    for * envItems {
        minX = min(it.rect.x, minX);
        maxX = max(it.rect.x + it.rect.width, maxX);
        minY = min(it.rect.y, minY);
        maxY = max(it.rect.y + it.rect.height, maxY);
    }
    
    max_val := GetWorldToScreen2D(make_Vector2(maxX, maxY), << camera);
    min_val := GetWorldToScreen2D(make_Vector2(minX, minY), << camera);
    
    if max_val.x < cast(float)width camera.offset.x = width - (max_val.x - width/2);
    if max_val.y < cast(float)height camera.offset.y = height - (max_val.y - height/2);
    if min_val.x > 0 camera.offset.x = width/2 - min_val.x;
    if min_val.y > 0 camera.offset.y = height/2 - min_val.y;
}

UpdateCameraCenterSmoothFollow :: (camera: *Camera2D, player: *Player, envItems: []EnvItem, delta: float, width: int, height: int)
{
    minSpeed :: 30.0;
    minEffectLength :: 10.0;
    fractionSpeed :: 2.9;
    
    camera.offset = make_Vector2(width/2, height/2);
    diff := player.position - camera.target;
    length := Vector2Length(diff);
    
    if length > minEffectLength
    {
        speed := max(fractionSpeed*length, minSpeed);
        camera.target = Vector2Add(camera.target, Vector2Scale(diff, speed*delta/length));
    }
}

even_out_state: struct {
    eveningOut: int;
    evenOutTarget: float;
};

UpdateCameraEvenOutOnLanding :: (camera: *Camera2D, player: *Player, envItems: []EnvItem, delta: float, width: int, height: int)
{
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
        if player.can_jump && (player.speed == 0) && (player.position.y != camera.target.y) {
            eveningOut = 1;
            evenOutTarget = player.position.y;
        }
    }
}

UpdateCameraPlayerBoundsPush :: (camera: *Camera2D, player: *Player, envItems: []EnvItem, delta: float, width: int, height: int)
{
    bbox: Vector2 = .{ 0.2, 0.2 };

    bboxWorldMin := GetScreenToWorld2D(make_Vector2((1 - bbox.x)*0.5*width, (1 - bbox.y)*0.5*height ), << camera);
    bboxWorldMax := GetScreenToWorld2D(make_Vector2((1 + bbox.x)*0.5*width, (1 + bbox.y)*0.5*height ), << camera);
    camera.offset = make_Vector2((1 - bbox.x)*0.5 * width, (1 - bbox.y)*0.5*height);

    if player.position.x < bboxWorldMin.x camera.target.x = player.position.x;
    if player.position.y < bboxWorldMin.y camera.target.y = player.position.y;
    if player.position.x > bboxWorldMax.x camera.target.x = bboxWorldMin.x + (player.position.x - bboxWorldMax.x);
    if player.position.y > bboxWorldMax.y camera.target.y = bboxWorldMin.y + (player.position.y - bboxWorldMax.y);
}