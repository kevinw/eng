
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

    last_walk_sprite_idx: s16 = -1;
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
    horizontal_movement += input.get_gamepad_stick(gamepad, .GAMEPAD_AXIS_LEFT_X, .GAMEPAD_AXIS_UNKNOWN).x;
    horizontal_movement += input.get_gamepad_dpad(gamepad).x;

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

    allow_all_beats := true;

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
            //logprint("player", "jump %", time_since_marker);
            speed = -PLAYER_JUMP_SPD;
        } else {
            add_worldspace_text("MISS", player.position);
            early_late := ifx time_since_marker > 0 then "late" else "early";
            if !beat_match_type early_late = "wrong beat";
            //logprint("player", "MISS % jump %", early_late, time_since_marker);
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

    squish:float = 1.0;

    walking := false;
    
    {
        using state.sprites.player;
        if !grounded {
            if attacking {
                spr = attack_air;
                fps = ATTACK_FPS;
            } else {
                fps = 9;
                since_jump := now - player.last_jump_time;
                launching_anim_time := cast(float)state.sprites.player.jump_start.count/fps;
                if since_jump < launching_anim_time {
                    spr = jump_start;
                    N:float : 1.27;
                    squish = 1.0 + (N - 1.0) * (1.0 - cast(float)(since_jump / launching_anim_time));
                } else {
                    spr = jump_mid;
                }
            }
        } else if attacking {
            spr = ifx attack_did_hit then attack else attack_miss;
            fps = ATTACK_FPS;
        } else if Math.abs(horizontal_movement) > 0 {
            fps = 18;
            spr = run;
            timer = walk_timer;

            walking = true;
        } else {

            fps = 10;
            since_land := now - player.last_grounded_time;
            landing_animation_time := cast(float)state.sprites.player.jump_landing.count/fps;
            if since_land < landing_animation_time {
                spr = jump_landing;
                N:float : 0.6;
                squish = N + (1.0 - N) * cast(float)(since_land / landing_animation_time);
            } else {
                spr = idle;
            }
        }
    }

    flip_x := last_direction < 0;
    sprite_rect, offset, idx := sprite_get_rect(spr, timer, fps, last_direction < 0);

    if walking && last_walk_sprite_idx != idx {
        last_walk_sprite_idx = cast(s16)idx;
        if idx % 4 == 0 {
            using state.sound_state;
            wav := ifx idx < 4 then fx.footstep1 else fx.footstep2;
            Soloud_play(soloud, wav, 0.1);
        }
    }

    x_offset := 21 * (ifx flip_x then -1 else 1);
    dest_rect_pos := position - v2(x_offset, 38) + offset;
    dest_rect := rect(dest_rect_pos.x, dest_rect_pos.y, sprite_rect.width, sprite_rect.height);
    sprite_rect.width *= ifx flip_x then -1 else 1;

    squish_offset := dest_rect.height * (1.0 - squish);
    dest_rect.height *= squish;
    dest_rect.y += squish_offset;

    DrawTexturePro(state.textures.gino, sprite_rect, dest_rect, v2(0, 0), 0, WHITE);

    // debug pos
    //w := 6;
    //DrawRectangleV(position - v2(w/2, w/2), make_Vector2(w, w), RED);
}
