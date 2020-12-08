#scope_module

get_gamepad_dpad :: (gamepad: int) -> Vector2 {
    result: Vector2;

    if rl.IsGamepadButtonDown(gamepad, .GAMEPAD_BUTTON_LEFT_FACE_LEFT)  result.x -= 1;
    if rl.IsGamepadButtonDown(gamepad, .GAMEPAD_BUTTON_LEFT_FACE_RIGHT) result.x += 1;

    if rl.IsGamepadButtonDown(gamepad, .GAMEPAD_BUTTON_LEFT_FACE_UP)    result.y += 1;
    if rl.IsGamepadButtonDown(gamepad, .GAMEPAD_BUTTON_LEFT_FACE_DOWN)  result.y -= 1;

    return result;
}

get_gamepad_stick :: (gamepad: int, x_axis: rl.GamepadAxis, y_axis: rl.GamepadAxis, DEAD_ZONE := 0.17) -> Vector2 {
    stick := rl.make_Vector2(rl.GetGamepadAxisMovement(gamepad, x_axis),
                             rl.GetGamepadAxisMovement(gamepad, y_axis));

    if abs(stick.x) < DEAD_ZONE stick.x = 0;
    if abs(stick.y) < DEAD_ZONE stick.y = 0;

    return stick;
}

Input_Type :: enum_flags u16 {
    KEYBOARD_WASD       :: 1 << 0;
    KEYBOARD_ARROWS     :: 1 << 1;
    GAMEPAD_LEFT_STICK  :: 1 << 2;
    GAMEPAD_RIGHT_STICK :: 1 << 3;
    GAMEPAD_DPAD        :: 1 << 4;
    GAMEPAD             :: GAMEPAD_LEFT_STICK | GAMEPAD_DPAD;
    ALL                 :: 0xffff;
}

Axes :: enum u16 {
    HORIZONTAL :: 1 << 0;
    VERTICAL   :: 1 << 1;
    BOTH       :: HORIZONTAL | VERTICAL;
}

movement :: (input_types := Input_Type.ALL, axes := Axes.BOTH, gamepad_index := 0) -> Vector2 {
    move: Vector2;

    // keyboard
    if input_types & .KEYBOARD_WASD {
        if axes & .HORIZONTAL {
            if rl.IsKeyDown(.KEY_A) move.x -= 1.0;
            if rl.IsKeyDown(.KEY_D) move.x += 1.0;
        }
        if axes & .VERTICAL {
            if rl.IsKeyDown(.KEY_W) move.y += 1.0;
            if rl.IsKeyDown(.KEY_S) move.y -= 1.0;
        }
    }

    if input_types & .KEYBOARD_ARROWS {
        if axes & .HORIZONTAL {
            if rl.IsKeyDown(.KEY_LEFT)  move.x -= 1.0;
            if rl.IsKeyDown(.KEY_RIGHT) move.x += 1.0;
        }
        if axes & .VERTICAL {
            if rl.IsKeyDown(.KEY_UP)  move.y += 1.0;
            if rl.IsKeyDown(.KEY_DOWN) move.y -= 1.0;
        }
    }

    gamepad := gamepad_index; // the gamepad index

    if input_types & .GAMEPAD_LEFT_STICK
        move += get_gamepad_stick(gamepad, .GAMEPAD_AXIS_LEFT_X, .GAMEPAD_AXIS_LEFT_Y);
    
    if input_types & .GAMEPAD_RIGHT_STICK
        move += get_gamepad_stick(gamepad, .GAMEPAD_AXIS_RIGHT_X, .GAMEPAD_AXIS_RIGHT_Y);

    if input_types & .GAMEPAD_DPAD
        move += get_gamepad_dpad(gamepad);

    if move.x != 0 || move.y != 0
        move = Vector2Normalize(move);
    
    assert(move.x >= -1 && move.x <= 1);
    assert(move.y >= -1 && move.y <= 1);

    return move;
}

#scope_file
rl :: #import "raylib";
#import "raymath";
#import "Math";
#import "Basic";
