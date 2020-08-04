#import "Basic";
Math :: #import "Math";
#import "raylib";
#import "raymath";
#load "toolbelt.jai";

gameWidth :: 640;
gameHeight :: 360;

PLAYER_JUMP_SPD :: 350;
PLAYER_HOR_SPD :: 200;
G :: 600;
GLSL_VERSION :: 330;

Entity :: struct {
    position: Vector2;
}

Enemy :: struct {
    using entity: Entity;
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
    gino_texture: Texture;

    sprites: struct {
        idle: []Sprite;
        run: []Sprite;
        jump_start: []Sprite;
        jump_mid: []Sprite;
        jump_landing: []Sprite;
        attack: []Sprite;
        attack_air: []Sprite;
    };
}

EnvItem :: struct {
    rect: Rectangle;
    blocking: int;
    color: Color;
}

state: struct {
    player: Player;
    envItems: [..]EnvItem;
    camera: Camera2D;

    bgm: Music;

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
        // actual init
        player.gino_texture = LoadTexture("resources/sprites/gino.png");
        gino_sprites := parse_spriter_atlas("resources/sprites/gino.atlas");
        {
            using player.sprites;
            idle         = sprites_with_prefix(gino_sprites, "Idle/");
            run          = sprites_with_prefix(gino_sprites, "Run/");
            jump_start   = sprites_with_prefix(gino_sprites, "Jump/start/");
            jump_mid     = sprites_with_prefix(gino_sprites, "Jump/mid/");
            jump_landing = sprites_with_prefix(gino_sprites, "Jump/landing/");
            attack       = sprites_with_prefix(gino_sprites, "Attacks/A/");
            attack_air   = sprites_with_prefix(gino_sprites, "Attack in jump/");
        }

        bgm = LoadMusicStream("resources/music/white-knuckle.mp3");
        PlayMusicStream(bgm);

        screen.texture = LoadRenderTexture(gameWidth, gameHeight);
        screen.shader = LoadShader(null, null);

        player.position = Vector2.{ 400, 280 };
        player.speed = 0;
        player.canJump = false;

        array_add(*envItems,
            //EnvItem.{.{ 0, 0, 1000, 400 },   0, LIGHTGRAY },
            EnvItem.{.{ 0, 400, 1000, 200 }, 1, GRAY },
            EnvItem.{.{ 300, 200, 400, 10 }, 1, GRAY },
            EnvItem.{.{ 250, 300, 100, 10 }, 1, GRAY },
            EnvItem.{.{ 650, 300, 100, 10 }, 1, GRAY }
        );
        
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

    {
        UpdateMusicStream(bgm);

        deltaTime := GetFrameTime();
        bg.timer += deltaTime * 0.2;

        set_shader_val(bg.shader, "secondes", cast(float)bg.timer);
       
        player_update(*player, envItems, deltaTime);

        camera.zoom += (cast(float)GetMouseWheelMove()*0.05);
        
        if camera.zoom > 3.0 camera.zoom = 3.0;
        else if camera.zoom < 0.25 camera.zoom = 0.25;
        
        if IsKeyPressed(.KEY_R)
        {
            camera.zoom = 1.0;
            player.position = Vector2.{ 400, 280 };
        }

        if IsKeyPressed(.KEY_C)
            cameraOption = (cameraOption + 1) % cameraUpdaters.count;

        if IsKeyPressed(.KEY_F)
            ToggleFullscreen();

        // Call update camera function by its pointer
        cameraUpdaters[cameraOption](*camera, *player, envItems, deltaTime, gameWidth, gameHeight);
        //----------------------------------------------------------------------------------
    }
    {
        BeginDrawing();
        defer EndDrawing();
        {
            BeginTextureMode(screen.texture);
            defer EndTextureMode();

            ClearBackground(LIGHTGRAY);
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

                for * envItems {
                    color := it.color;
                    color2 := color;
                    color2.r -= 100;
                    color2.g -= 100;
                    color2.b -= 100;

                    DrawRectangleGradientEx(it.rect, color, color2, color2, color);
                }

                player_draw(*player);
            }
        }

        {
            // blit to screen
            BeginShaderMode(screen.shader);
            defer EndShaderMode();

            //DrawTextureRec(screen.texture.texture, make_Rectangle(0, 0, screen.texture.texture.width, -screen.texture.texture.height), Vector2.{ 0, 0 }, WHITE);

            source_rect := make_Rectangle(0, 0, screen.texture.texture.width, -screen.texture.texture.height);
            dest_rect   := make_Rectangle(0, 0, GetScreenWidth(), GetScreenHeight());
            DrawTexturePro(screen.texture.texture, source_rect, dest_rect, Vector2.{0, 0}, 0, WHITE);
        }
    }
}

sprite_get_rect :: (spr: []Sprite, timer: float64, fps: int) -> Rectangle {
    sprite_index := cast(int)(timer * fps);
    while sprite_index >= spr.count sprite_index -= spr.count;
    s := *spr[sprite_index];
    return rect(s.xy.x, s.xy.y, s.size.x, s.size.y);
}

ATTACK_FPS :: 9;

player_is_attacking :: (player: *Player) -> bool {
    return (GetTime() - player.last_attack_time) < cast(float)player.sprites.attack.count/ATTACK_FPS;
}

player_draw :: (player: *Player) {
    attacking := player_is_attacking(player);

    spr: []Sprite;
    fps: int;
    timer: float64 = player.sprite_timer;
    
    if !player.grounded {
        if attacking {
            spr = player.sprites.attack_air;
            fps = ATTACK_FPS;
        } else {
            spr = player.sprites.jump_mid;
            fps = 14;
        }
    } else if attacking {
        spr = player.sprites.attack;
        fps = ATTACK_FPS;
    } else if Math.abs(player.horizontal_movement) > 0 {
        spr = player.sprites.run;
        timer = player.walk_timer;
        fps = 18;
    } else {
        spr = player.sprites.idle;
        fps = 10;
    }

    sprite_rect := sprite_get_rect(spr, timer, fps);
    player_rect := rect(player.position.x - 15, player.position.y - 40, 30, 40);

    //DrawRectangleRec(playerRect, RED);
    //DrawRectangleGradientEx(player_rect, RED, GREEN, WHITE, BLUE);
    //DrawCircleV(player.position - v2(0, 45), 10, make_Color(90, 40, 60, 255));
    // void DrawTexturePro(Texture2D texture, Rectangle sourceRec, Rectangle destRec, Vector2 origin, float rotation, Color tint);       // Draw a part of a texture defined by a rectangle with 'pro' parameters

    dest_rect_pos := player.position - v2(10, 37);
    dest_rect := rect(dest_rect_pos.x, dest_rect_pos.y, sprite_rect.width, sprite_rect.height);
    sprite_rect.width *= ifx player.last_direction < 0 then -1 else 1;
    DrawTexturePro(player.gino_texture, sprite_rect, dest_rect, v2(0, 0), 0, WHITE);
}

player_update :: (player: *Player, envItems: []EnvItem, delta_time: float)
{
    player.sprite_timer += delta_time;

    horizontal_movement: float;

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

    player.horizontal_movement = horizontal_movement;
    player.position.x += horizontal_movement * PLAYER_HOR_SPD * delta_time;
    if Math.abs(horizontal_movement) > 0
        player.last_direction = cast(float)sign(horizontal_movement);
    player.walk_timer += delta_time * Math.abs(horizontal_movement);

    jump_button_this_frame := IsKeyDown(.KEY_SPACE) ||
                              IsKeyDown(.KEY_W) ||
                              IsKeyDown(.KEY_UP) ||
                              IsGamepadButtonDown(gamepad, .GAMEPAD_BUTTON_RIGHT_FACE_DOWN);
    

    now := GetTime();
    if jump_button_this_frame && !player.jump_button_last_frame
        player.jump_button_time = now;

    player.jump_button_last_frame = jump_button_this_frame;


    if IsKeyDown(.KEY_E) || IsGamepadButtonDown(gamepad, .GAMEPAD_BUTTON_RIGHT_FACE_LEFT) {
        player.last_attack_time = now;
        player.sprite_timer = 0;
    }

    if player.grounded && (now - player.jump_button_time) < 0.15
    {
        player.speed = -PLAYER_JUMP_SPD;
        player.grounded = false;
        player.canJump = false;
    }


    hitObstacle := false;

    for * envItems
    {
        p := *player.position;
        if it.blocking &&
           it.rect.x <= p.x && it.rect.x + it.rect.width >= p.x &&
           it.rect.y >= p.y && it.rect.y < p.y + player.speed * delta_time
        {
            hitObstacle = true;
            player.speed = 0.0;
            p.y = it.rect.y;
            player.grounded = true;
        }
    }
    
    if !hitObstacle {
        player.position.y += player.speed * delta_time;
        player.speed += G * delta_time;
        player.canJump = false;
    } else {
        player.canJump = true;
    }
}

UpdateCameraCenter :: (camera: *Camera2D, player: *Player, envItems: []EnvItem, delta: float, width: int, height: int)
{
    camera.offset = make_Vector2(width/2, height/2);
    camera.target = player.position;
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