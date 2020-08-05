#import "Basic";
#import "raylib";
#import "raymath";
screenlog :: #import "screenlog";
#import "toolbelt";
reaper :: #import "reaper";

gameWidth :: 640;
gameHeight :: 360;

PLAYER_JUMP_SPD :: 350;
PLAYER_HOR_SPD :: 220;
G :: 1150;
JUMP_FLOAT :: 0.39;
JUMP_FLOAT_POW :: 1.1;
GLSL_VERSION :: 330;

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
    canJump: bool;
    grounded: bool;

    jump_button_time: float64;
    jump_button_last_frame: bool;

    last_attack_time:float64 = -10000;

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
    textures: struct {
        gino: Texture;
        evilplant: Texture;
    };
    sprites: struct {
        player: struct {
            idle: []Sprite;
            run: []Sprite;
            jump_start: []Sprite;
            jump_mid: []Sprite;
            jump_landing: []Sprite;
            attack: []Sprite;
            attack_air: []Sprite;
        };
        evilplant: struct {
            idle: []Sprite;
            hit: []Sprite;
        };
    };

    beat_markers: []reaper.Marker;
    current_marker: *reaper.Marker;
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

#program_export
plugin_init :: (old_value: *void) {
    using state;

    if old_value != null {
        old_state := cast(*type_of(state))old_value;
        state = << old_state;
        free(old_state);
    } else {
        ok: bool;
        ok, beat_markers = reaper.parse_reaper_project_file("resources/music/i-think-she-knows.rpp");
        assert(ok);

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
            attack_air   = sprites_with_prefix(gino_sprites, "Attack in jump/");
        }

        textures.evilplant = LoadTexture("resources/sprites/evilplant.png");
        {
            using sprites.evilplant;
            evilplant_sprites := parse_spriter_atlas("resources/sprites/evilplant.atlas");
            idle = sprites_with_prefix(evilplant_sprites, "Idle/");
            hit  = sprites_with_prefix(evilplant_sprites, "Hit/");
        }

        bgm = LoadMusicStream("resources/music/i-think-she-knows.mp3");
        SetMusicVolume(bgm, 0.01);
        SetMusicLoopCount(bgm, 0);
        PlayMusicStream(bgm);

        screen.texture = LoadRenderTexture(gameWidth, gameHeight);
        screen.shader = LoadShader(null, null);

        player.position = Vector2.{ 400, 280 };
        player.speed = 0;
        player.canJump = false;

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
        enemy.position.x = 600;
        enemy.position.y = 197;
        array_add(*enemies, enemy);
        
        camera.target = player.position;
        camera.offset = Vector2.{ cast(float)gameWidth/2.0, cast(float)gameHeight/2.0 };
        camera.rotation = 0.0;
        camera.zoom = 1.0;

        bg.texture = LoadTexture("resources/textures/space.png");
        bg.shader = LoadShader(null, TextFormat("resources/shaders/glsl%i/wave.fs", GLSL_VERSION));
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

#program_export
update_and_draw :: () {
    using state;

    deltaTime := GetFrameTime();

    // update
    {
        screenlog.update(deltaTime);

        UpdateMusicStream(bgm);

        // update beat
        {
            beat_timer = GetMusicTimePlayed(bgm);
            bgm_bpm:float = 122.069;
            beats_per_second := bgm_bpm * (1.0 / 60.0);
            found: bool;
            found, current_marker = reaper.most_recent_marker(beat_markers, beat_timer);
        }

        bg.timer += deltaTime * 0.2;

        set_shader_val(bg.shader, "secondes", cast(float)bg.timer);
       
        player_update(*player, envItems, deltaTime);

        for * enemies {
            it.sprite_timer += deltaTime;
        }

        camera.zoom += (cast(float)GetMouseWheelMove()*0.05);
        
        camera.zoom = clamp(camera.zoom, 0.25, 3.0);
        
        if IsKeyPressed(.KEY_R) {
            camera.zoom = 1.0;
            camera.target = .{0, 0};
            player.position = .{ 400, 280 };
        }
        if IsKeyPressed(.KEY_C) cameraOption = (cameraOption + 1) % cameraUpdaters.count;
        if IsKeyPressed(.KEY_F) ToggleFullscreen();

        cameraUpdaters[cameraOption](*camera, *player, envItems, deltaTime, gameWidth, gameHeight);
    }
    {
        BeginDrawing();
        defer EndDrawing();
        {
            BeginTextureMode(screen.texture);
            defer EndTextureMode();

            {
                BeginShaderMode(bg.shader);
                defer EndShaderMode();
                DrawTexture(bg.texture, 0, 0, WHITE);
                DrawTexture(bg.texture, bg.texture.width, 0, WHITE);
                DrawTexture(bg.texture, 0, bg.texture.height, WHITE);
                DrawTexture(bg.texture, bg.texture.width, bg.texture.height, WHITE);
            }
            {
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
                {
                    for * enemies {
                        fps := 10;
                        sprite_rect := sprite_get_rect(sprites.evilplant.idle, it.sprite_timer, fps);
                        dest_rect_pos := it.position - v2(10, 37);
                        dest_rect := rect(dest_rect_pos.x, dest_rect_pos.y, sprite_rect.width, sprite_rect.height);
                        DrawTexturePro(textures.evilplant, sprite_rect, dest_rect, v2(0, 0), 0, WHITE);
                    }
                }

                // draw entities
                player_draw(*player);
            }

            // Update beats
            if current_marker != null {
                time_since_marker := beat_timer - current_marker.time;
                alpha := max(cast(float64)0.0, 1.0 - time_since_marker);
                color := Vector4.{1, 1, 1, 1};
                color.w = cast(float32)alpha;
                DrawText(to_temp_c_string(tprint("%", current_marker.beat_type)), 16, 10, 10, ColorFromNormalized(color));
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

sprite_get_rect :: (spr: []Sprite, timer: float64, fps: int) -> Rectangle {
    sprite_index := cast(int)(timer * fps);
    while sprite_index >= spr.count sprite_index -= spr.count;
    s := *spr[sprite_index];
    return rect(s.xy.x, s.xy.y, s.size.x, s.size.y);
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
    
    {
        using state.sprites.player;
        if !grounded {
            if attacking {
                spr = attack_air;
                fps = ATTACK_FPS;
            } else {
                spr = jump_mid;
                fps = 14;
            }
        } else if attacking {
            spr = attack;
            fps = ATTACK_FPS;
        } else if Math.abs(horizontal_movement) > 0 {
            spr = run;
            timer = walk_timer;
            fps = 18;
        } else {
            spr = idle;
            fps = 10;
        }
    }

    sprite_rect := sprite_get_rect(spr, timer, fps);

    dest_rect_pos := position - v2(10, 37);
    dest_rect := rect(dest_rect_pos.x, dest_rect_pos.y, sprite_rect.width, sprite_rect.height);
    sprite_rect.width *= ifx last_direction < 0 then -1 else 1;
    DrawTexturePro(state.textures.gino, sprite_rect, dest_rect, v2(0, 0), 0, WHITE);
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

    if IsKeyDown(.KEY_E) || IsGamepadButtonDown(gamepad, .GAMEPAD_BUTTON_RIGHT_FACE_LEFT) {
        last_attack_time = now;
        sprite_timer = 0;
    }

    if !attacking && grounded && (now - jump_button_time) < 0.15 {
        // JUMP
        speed = -PLAYER_JUMP_SPD;
        grounded = false;
        canJump = false;

        logprint("player", "did jump at %", now);
    }

    hitObstacle := false;

    for * envItems {
        p := *position;
        if it.blocking &&
           it.rect.x <= p.x && it.rect.x + it.rect.width >= p.x &&
           it.rect.y >= p.y && it.rect.y < p.y + speed * delta_time
        {
            hitObstacle = true;
            speed = 0.0;
            p.y = it.rect.y;
            grounded = true;
        }
    }

    if !hitObstacle {
        position.y += speed * delta_time;
        drag := G * delta_time;
        if speed < 0 && jump_button_this_frame
            drag = Math.pow(drag * JUMP_FLOAT, JUMP_FLOAT_POW);
        speed += drag;
        canJump = false;
    } else {
        canJump = true;
    }
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
    
    if eveningOut
    {
        if evenOutTarget > camera.target.y
        {
            camera.target.y += evenOutSpeed*delta;
            
            if camera.target.y > evenOutTarget
            {
                camera.target.y = evenOutTarget;
                eveningOut = 0;
            }
        } 
        else 
        {
            camera.target.y -= evenOutSpeed*delta;
            
            if camera.target.y < evenOutTarget
            {
                camera.target.y = evenOutTarget;
                eveningOut = 0;
            }
        }
    } 
    else 
    {
        if player.canJump && (player.speed == 0) && (player.position.y != camera.target.y)
        {
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