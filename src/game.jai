#import "Basic";
Math :: #import "Math";
#import "raylib";
#import "raymath";
#load "toolbelt.jai";

G :: 400;
PLAYER_JUMP_SPD :: 350;
PLAYER_HOR_SPD :: 200;

Player :: struct {
    position: Vector2;
    speed: float;
    canJump: bool;
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

    cameraOption: int;

    bg_texture: Texture;
    shader: Shader;
    seconds: float;
};

CameraFunc :: #type (camera: *Camera2D, player: *Player, items: []EnvItem, delta: float, w: int, h: int);

cameraUpdaters :: CameraFunc.[
    UpdateCameraCenter,
    UpdateCameraCenterInsideMap,
    UpdateCameraCenterSmoothFollow,
    UpdateCameraEvenOutOnLanding,
    UpdateCameraPlayerBoundsPush
];

cameraDescriptions :: string.[
    "Follow player center",
    "Follow player center, but clamp to map edges",
    "Follow player center; smoothed",
    "Follow player center horizontally; updateplayer center vertically after landing",
    "Player push camera on getting too close to screen edge",
];

screenWidth :: 800;
screenHeight :: 450;

#program_export
plugin_init :: (old_value: *void) {
    using state;

    if old_value != null {
        old_state := cast(*type_of(state))old_value;
        state = << old_state;
        free(old_state);
        return;
    }

    // actual init

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
    camera.offset = Vector2.{ cast(float)screenWidth/2.0, cast(float)screenHeight/2.0 };
    camera.rotation = 0.0;
    camera.zoom = 1.0;

    bg_texture = LoadTexture("resources/textures/space.png");
    shader = LoadShader(null, TextFormat("resources/shaders/glsl%i/wave.fs", 330));

    screenSize: [2]float;
    screenSize[0] = cast(float)GetScreenWidth();
    screenSize[1] = cast(float)GetScreenHeight();

    set_shader_val(shader, "size", screenSize);
    set_shader_val(shader, "freqX", 25.0);
    set_shader_val(shader, "freqY", 25.0);
    set_shader_val(shader, "ampX", 5.0);
    set_shader_val(shader, "ampY", 5.0);
    set_shader_val(shader, "speedX", 8.0);
    set_shader_val(shader, "speedY", 8.0);
}

set_shader_val :: (shader: Shader, name: string, val: $T) {
    location := GetShaderLocation(shader, to_temp_c_string(name));

    uniform_type: ShaderUniformDataType;
    #if T == Vector2 || T == [2]float32
        uniform_type = .UNIFORM_VEC2;
    else if T == Vector3 || T == [3]float32
        uniform_type = .UNIFORM_VEC3;
    else if T == Vector4 || T == [4]float32
        uniform_type = .UNIFORM_VEC4;
    else if T == float
        uniform_type = .UNIFORM_FLOAT;
    else
        print("unknown type %", T);

    SetShaderValue(shader, location, *val, uniform_type);
}

#program_export
plugin_deinit :: (shutting_down: bool) -> *void {
    using state;
    if shutting_down {
        UnloadTexture(bg_texture);
        UnloadShader(shader);
        return null;
    }

    heap_state := New(type_of(state));
    << heap_state = state;
    return heap_state;
}

#program_export
update_and_draw :: () {
    using state;

    {
        deltaTime := GetFrameTime();
        seconds += deltaTime * 0.2;

        set_shader_val(shader, "secondes", seconds);

        
        UpdatePlayer(*player, envItems, deltaTime);

        camera.zoom += (cast(float)GetMouseWheelMove()*0.05);
        
        if camera.zoom > 3.0 camera.zoom = 3.0;
        else if camera.zoom < 0.25 camera.zoom = 0.25;
        
        if IsKeyPressed(.KEY_R)
        {
            camera.zoom = 1.0;
            player.position = Vector2.{ 400, 280 };
        }

        if IsKeyPressed(.KEY_C) cameraOption = (cameraOption + 1) % cameraUpdaters.count;

        // Call update camera function by its pointer
        cameraUpdaters[cameraOption](*camera, *player, envItems, deltaTime, screenWidth, screenHeight);
        //----------------------------------------------------------------------------------
    }
    {
        BeginDrawing();
        defer EndDrawing();
        ClearBackground(LIGHTGRAY);

        {
            BeginShaderMode(shader);
            defer EndShaderMode();
            DrawTexture(bg_texture, 0, 0, WHITE);
            DrawTexture(bg_texture, bg_texture.width, 0, WHITE);
        }
        {
            BeginMode2D(camera);
            defer EndMode2D();

            for * envItems
                DrawRectangleRec(it.rect, it.color);

            playerRect := make_Rectangle(player.position.x - 20, player.position.y - 40, 40, 40);
            DrawRectangleRec(playerRect, RED);
        }


/*
        DrawText("Controls:", 20, 20, 10, BLACK);
        DrawText("- Right/Left to move", 40, 40, 10, DARKGRAY);
        DrawText("- Space to jump", 40, 60, 10, DARKGRAY);
        DrawText("- Mouse Wheel to Zoom in-out, R to reset zoom", 40, 80, 10, DARKGRAY);
        DrawText("- C to change camera mode", 40, 100, 10, DARKGRAY);
        DrawText("Current camera mode:", 20, 120, 10, BLACK);

        desc := to_temp_c_string(cameraDescriptions[cameraOption]);
        DrawText(desc, 40, 140, 10, DARKGRAY);
        */
    }
}

UpdatePlayer :: (player: *Player, envItems: []EnvItem, delta: float)
{
    if IsKeyDown(.KEY_LEFT) || IsKeyDown(.KEY_A)  player.position.x -= PLAYER_HOR_SPD * delta;
    if IsKeyDown(.KEY_RIGHT) || IsKeyDown(.KEY_D) player.position.x += PLAYER_HOR_SPD * delta;
    if (IsKeyDown(.KEY_SPACE) || IsKeyDown(.KEY_W)) && player.canJump
    {
        player.speed = -PLAYER_JUMP_SPD;
        player.canJump = false;
    }

    hitObstacle := false;

    for * envItems
    {
        p := *player.position;
        if it.blocking &&
           it.rect.x <= p.x && it.rect.x + it.rect.width >= p.x &&
           it.rect.y >= p.y && it.rect.y < p.y + player.speed * delta
        {
            hitObstacle = true;
            player.speed = 0.0;
            p.y = it.rect.y;
        }
    }
    
    if !hitObstacle {
        player.position.y += player.speed * delta;
        player.speed += G * delta;
        player.canJump = false;
    } 
    else player.canJump = true;
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
    fractionSpeed :: 0.8;
    
    camera.offset = make_Vector2(width/2, height/2);
    diff := Vector2Subtract(player.position, camera.target);
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