#scope_file
ATTACK_FPS :: 13;
DAMAGE_FPS :: 6;
PLAYER_JUMP_SPD :: 350;
DAMAGE_KNOCKBACK :: 250;
PLAYER_HOR_SPD :: 220;
DAMAGE_TIME :: 0.9;
HORIZONTAL_DRAG :: 0.1;

player_was_damaged :: (damage: *Takes_Damage) -> bool { return false; }

#scope_module

On_Damage_Func :: #type (takes_damage: *Takes_Damage) -> bool;

patch_function_pointers :: () {
    /*
    this assumes that functions will be linked in the same order
    
    offset = NEW_DLL_BASE - OLD_DLL_BASE

    for all objects we care about
        for member in type
            if member is a function pointer
                func_ptr += add the offset
    */
}

Takes_Damage :: struct {
    // damage
    time: float64 = -999999;
    delta: Vector2;

    health: float = 100;

    damage_time: float = 1;

    damage_func_type: enum {
        Player;
        Enemy;
    };
    //damage_func: On_Damage_Func;
}

invoke_damage_func :: (it: *Takes_Damage) {
    if it.damage_func_type == {
        case .Player; player_was_damaged(it);
        case .Enemy;  enemy_was_damaged(it);
        case; assert(false, "unhandled damage case");
    }
}

being_damaged :: (damage: *Takes_Damage) -> bool {
    using state;
    return Time.now - damage.time < damage.damage_time;
}

try_take_damage :: (it: *Takes_Damage, delta: Vector2) -> bool {
    if being_damaged(it) return false;

    take_damage(it, delta);
    return true;
}

take_damage :: (using it: *Takes_Damage, in_delta: Vector2) {
    using state;

    amount := 1.0;

    health -= amount;
    time = Time.now;
    delta = in_delta;

    invoke_damage_func(it);
}

Player :: struct {
    using entity: Entity;

    speed: Vector2;
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

    damage := Takes_Damage.{
        damage_func_type = .Player,
    };
    //damage.damage_func = player_was_damaged;
}

player_reset :: (using it: *Player) {
    position = Vector2.{ 400, 280 };
    speed = Vector2.{ 0, 0 };
    can_jump = false;
}

player_has_been_damaged :: (using player: *Player) -> bool {
    return state.Time.now - damage.time < DAMAGE_TIME;
}

player_update :: (state: *State, using player: *Player, envItems: []EnvItem) {
    Time := *state.Time;

    is_being_knocked_back := player_has_been_damaged(player);
    sprite_timer += Time.delta_time;

    attacking := player_is_attacking(player);

    input_types := inp.Input_Type.ALL;
    if state.editor.play_mode == .Edit
        input_types = ~inp.Input_Type.KEYBOARD_WASD;

    // Separate because in the platformer controls we don't treat up and down as
    // movement that "steals" speed away from the X direction.
    horizontal_movement = inp.movement(input_types, .HORIZONTAL).x;

    if (attacking && player.grounded) || is_being_knocked_back
        horizontal_movement = 0;

    position.x += horizontal_movement * PLAYER_HOR_SPD * Time.delta_time;
    if Math.abs(horizontal_movement) > 0
        last_direction = cast(float)sign(horizontal_movement);
    walk_timer += Time.delta_time * Math.abs(horizontal_movement);

    gamepad :: 0;

    a_jump_input_is_present := IsKeyDown(.KEY_SPACE) ||
        (input_types & .KEYBOARD_WASD && IsKeyDown(.KEY_W)) ||
        IsKeyDown(.KEY_UP) ||
        IsGamepadButtonDown(gamepad, .GAMEPAD_BUTTON_RIGHT_FACE_DOWN);

    jump_button_this_frame := !is_being_knocked_back && a_jump_input_is_present;
    if jump_button_this_frame && !jump_button_last_frame
        jump_button_time = Time.now;
    jump_button_last_frame = jump_button_this_frame;

    time_since_marker := state.beat_timer - state.nearest_marker.time;
    allow_all_beats := true;

    if !is_being_knocked_back {
        // ATTACK
        if (IsKeyPressed(.KEY_E) || IsGamepadButtonPressed(gamepad, .GAMEPAD_BUTTON_RIGHT_FACE_LEFT)) {
            attack_offset :: Vector2.{0, -20};
            if allow_all_beats || (Math.abs(time_since_marker) < .2 && state.nearest_marker.beat_type == .Kick) {
                last_attack_time = Time.now;
                attack_did_hit = true;
                sprite_timer = 0;
            } else {
                last_attack_time = Time.now;
                attack_did_hit = false;
                sprite_timer = 0;
            }
        }

        // JUMP
        if !attacking && grounded && (Time.now - jump_button_time) < 0.15 {
            beat_match_type := state.nearest_marker.beat_type == .Snare;
            if allow_all_beats || (Math.abs(time_since_marker) < .2 && beat_match_type) {
                //logprint("player", "jump %", time_since_marker);
                speed.y = -PLAYER_JUMP_SPD;
            } else {
                early_late := ifx time_since_marker > 0 then "late" else "early";
                if !beat_match_type early_late = "wrong beat";
                //logprint("player", "MISS % jump %", early_late, time_since_marker);
                speed.y = -PLAYER_JUMP_SPD * 0.25;
            }

            grounded = false;
            can_jump = false;
            last_jump_time = Time.now;
        }
    }

    hitObstacle := false;

    // COLLISION
    for * envItems {
        p := *position;
        if it.collision & .PLATFORM &&
           it.rect.x <= p.x && it.rect.x + it.rect.width >= p.x &&
           it.rect.y >= p.y && it.rect.y < p.y + speed.y * Time.delta_time
        {
            hitObstacle = true;
            speed.y = 0.0;
            p.y = it.rect.y;
            if !grounded 
                last_grounded_time = Time.now;
            grounded = true;
        }
    }

    // GRAVITY
    if speed.x != 0 {
        if !grounded position.x += speed.x * Time.delta_time;
        if Math.abs(speed.x) > 0 {
            // TODO: some kind of lerp here
            s := sign(speed.x);
            speed.x += -s * Time.delta_time * 400;
            if s != sign(speed.x)
                speed.x = 0;
        }
    }

    if !hitObstacle {
        position.y += speed.y * Time.delta_time;
        drag := G * Time.delta_time;
        if speed.y < 0 && jump_button_this_frame
            drag = Math.pow(drag * JUMP_FLOAT, JUMP_FLOAT_POW);
        speed.y += drag;
        can_jump = false;
    } else {
        can_jump = true;
    }

    //
    // collision with enemies
    //
    attack_hitbox := player_attack_hitbox(player);
    attack_hitbox_rect := player_attack_rect(player);

    if !is_being_knocked_back || attack_hitbox {
        p_rect := player_rect(player);
        p_midpoint := midpoint(p_rect);
        for * state.enemies {
            e_rect := enemy_rect(it);
            if !is_being_knocked_back && CheckCollisionRecs(e_rect, p_rect) && !being_damaged(*it.damage) {
                // player hit
                delta := midpoint(e_rect) - p_midpoint;
                take_damage(*damage, delta);
                //screenlog.world(p_midpoint, ifx delta.x > 0 then "DMG right" else "DMG left");

                speed.y = -PLAYER_JUMP_SPD * 0.45;
                speed.x = DAMAGE_KNOCKBACK * cast(float)-sign(delta.x);
                grounded = false;
                can_jump = false;
            } else if attack_hitbox && CheckCollisionRecs(e_rect, attack_hitbox_rect) {
                //logprint("player", "hit enemy %", it);

                delta := midpoint(e_rect) - p_midpoint;
                enemy_was_hit_by_player(it, player, delta);
            }
        }
    }

    // catch player falling off the universe
    if position.y > 1000
        restart();
}

player_is_attacking :: (it: *Player) -> bool {
    using state;

    return Time.now - it.last_attack_time < cast(float)state.sprites.player.attack.count/ATTACK_FPS;
}

player_attack_hitbox :: (it: *Player) -> bool {
    using state;
    time_since_attack := Time.now - it.last_attack_time;
    return time_since_attack < 0.43 && time_since_attack > 0.1;
}

player_draw :: (using player: *Player) {
    Time := *state.Time;

    attacking := player_is_attacking(player);
    is_being_knocked_back := player_has_been_damaged(player);

    spr: []Sprite;
    fps: int;
    timer: float64 = sprite_timer;

    squish:float = 1.0;

    walking := false;
    
    {
        using state.sprites.player;
        if is_being_knocked_back {
            spr = damaged;
            fps = DAMAGE_FPS;
        } else if !grounded {
            if attacking {
                spr = attack_air;
                fps = ATTACK_FPS;
            } else {
                fps = 9;
                since_jump := Time.now - player.last_jump_time;
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
            since_land := Time.now - player.last_grounded_time;
            landing_animation_time := cast(float)state.sprites.player.jump_landing.count/fps;
            if since_land < landing_animation_time {
                spr = jump_landing;
                N:float : 0.8;
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
            #if SOUND_ENABLED
                Soloud_play(soloud, wav, 0.5);
        }
    }

    x_offset := 21 * (ifx flip_x then -1 else 1);
    dest_rect_pos := position - v2(x_offset, 38) + offset;
    dest_rect := rect(dest_rect_pos.x, dest_rect_pos.y, sprite_rect.width, sprite_rect.height);
    sprite_rect.width *= ifx flip_x then -1 else 1;

    squish_offset := dest_rect.height * (1.0 - squish);
    dest_rect.height *= squish;
    dest_rect.y += squish_offset;

    color := WHITE;
    if is_being_knocked_back
        color = Color.{255, 100, 100, 255};

    DrawTexturePro(state.textures.gino, sprite_rect, dest_rect, v2(0, 0), 0, color);

    //screenlog.world(position, "%", position);

    if state.debug_draw {
        debug_color :: RED;
        draw_point(position, 6, debug_color);
        draw_rect_outline(player_rect(player), 2, debug_color);
        if player_attack_hitbox(player)
            draw_rect_outline(player_attack_rect(player), 2, debug_color);
        
        screenlog.world(position, "(%, %)", cast(int)position.x, cast(int)position.y);
    }
}

player_rect :: (using it: *Player) -> Rectangle {
    w := 18;
    h := 30;
    outline_rect := rect(position.x - w/2, position.y - h, w, h);
    return outline_rect;
}

player_attack_rect :: (using it: *Player) -> Rectangle {
    x_off := ifx it.last_direction < 0 then -33 else 4;
    return rect(position.x + x_off, position.y - 25, 30, 20);
}