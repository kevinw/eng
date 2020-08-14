#scope_file

#import "raylib";
#import "raymath";
Math :: #import "Math";

#scope_module

get_gamepad_dpad :: (gamepad: int) -> Vector2 {
    result: Vector2;

    if IsGamepadButtonDown(gamepad, .GAMEPAD_BUTTON_LEFT_FACE_LEFT)  result.x -= 1;
    if IsGamepadButtonDown(gamepad, .GAMEPAD_BUTTON_LEFT_FACE_RIGHT) result.x += 1;

    if IsGamepadButtonDown(gamepad, .GAMEPAD_BUTTON_LEFT_FACE_UP)    result.x += 1;
    if IsGamepadButtonDown(gamepad, .GAMEPAD_BUTTON_LEFT_FACE_DOWN)  result.x -= 1;

    return result;
}

get_gamepad_stick :: (gamepad: int, x_axis: GamepadAxis, y_axis: GamepadAxis, DEAD_ZONE := 0.17) -> Vector2 {
    stick := make_Vector2(
        GetGamepadAxisMovement(gamepad, x_axis),
        GetGamepadAxisMovement(gamepad, y_axis));

    if Math.abs(stick.x) < DEAD_ZONE stick.x = 0;
    if Math.abs(stick.y) < DEAD_ZONE stick.y = 0;

    return stick;
}

movement :: () -> Vector2 {
    move: Vector2;

    // keyboard
    if IsKeyDown(.KEY_LEFT)  || IsKeyDown(.KEY_A) move.x -= 1.0;
    if IsKeyDown(.KEY_RIGHT) || IsKeyDown(.KEY_D) move.x += 1.0;

    gamepad :: 0; // the gamepad index

    // gamepad stick
    move += get_gamepad_stick(gamepad, .GAMEPAD_AXIS_LEFT_X, .GAMEPAD_AXIS_LEFT_Y);

    // gamepad dpad
    move += get_gamepad_dpad(gamepad);

    if move.x != 0 || move.y != 0
        move = Vector2Normalize(move);

    return move;
}