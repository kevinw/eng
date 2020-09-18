#scope_file
inp :: #import "inp";
#import "raymath";
#scope_export

Pong_Paddle :: struct {
    using component: Component;

    player_index: u8;
}

on_enable :: (it: *Pong_Paddle, entity: *Entity) {
}

update :: (using it: *Pong_Paddle, transform: *Transform, sprite_renderer: *SpriteRenderer) {
    using context.state;

    input_type: inp.Input_Type;
    fire := false;
    if player_index == {
        case 0;
            input_type = .KEYBOARD_ARROWS;
            fire = IsKeyPressed(.KEY_RIGHT_SHIFT);
        case 1;
            input_type = .KEYBOARD_WASD;
            fire = IsKeyPressed(.KEY_LEFT_SHIFT);
    }

    m := inp.movement(input_type, .HORIZONTAL);
    assert(m.y == 0);
    transform.position.xy += m * Time.delta_time * 600;

    transform.position.x = clamp(transform.position.x, 0, 500);

    if fire
        logprint("paddle", "player % fired", player_index);
        
}
