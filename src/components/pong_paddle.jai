Pong_Paddle :: struct {
    using component: Component; @noui

    player_index: u8;

    gun_dir: rl.Vector2; // normalized
}

get_gun_tip :: (using it: *Pong_Paddle, transform: *Transform) -> rl.Vector2 {
    return transform.position.xy + gun_dir * 50.0;
}

draw :: (using it: *Pong_Paddle, transform: *Transform) {
    rl.DrawLineEx(transform.position.xy, get_gun_tip(it, transform), 3, rl.MAGENTA);
}

update :: (using it: *Pong_Paddle, transform: *Transform, sprite_renderer: *SpriteRenderer) {
    using context.state;

    input_type: inp.Input_Type;
    fire := false;
    if player_index == {
        case 0;
            input_type = inp.Input_Type.KEYBOARD_ARROWS | .GAMEPAD_LEFT_STICK | .GAMEPAD_DPAD;
            fire = rl.IsKeyPressed(.KEY_RIGHT_SHIFT) || rl.IsGamepadButtonPressed(player_index, .GAMEPAD_BUTTON_RIGHT_TRIGGER_1);
        case 1;
            input_type = .KEYBOARD_WASD;
            fire = rl.IsKeyPressed(.KEY_LEFT_SHIFT);
    }

    m := inp.movement(input_type, .HORIZONTAL, gamepad_index = player_index);
    m.y = 0; // TODO: .HORIZONTAL should impyl this, this should be assert(m.y == 0)
    transform.position.xy += m * Time.delta_time * 600;

    transform.position.x = clamp(transform.position.x, 50, 575);

    gun_dir = inp.movement(.GAMEPAD_RIGHT_STICK, gamepad_index = player_index);
    Math :: #import "Math";

    if fire && length(<<cast(*Math.Vector2)*gun_dir) > 0.0001 {
        new_ball := spawn_prefab("pong_ball", get_gun_tip(it, transform));

        new_transform := get_transform(new_ball);
        new_transform.scale.xy = v2(10, 10);

        new_bounce := get_component(new_ball, Bounce);
        new_bounce.velocity = gun_dir * 40;
        new_bounce.dies_on_collide = true;
    }
        
}

#scope_file
inp :: #import "inp";
#import "raymath";
rl :: #import "raylib";
