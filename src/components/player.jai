#scope_file

ATTACK_FPS :: 13;
DAMAGE_FPS :: 6;
PLAYER_JUMP_SPD :: 350;
DAMAGE_KNOCKBACK :: 250;
PLAYER_HOR_SPD :: 220;
DAMAGE_TIME :: 0.9;
HORIZONTAL_DRAG :: 0.1;
G :: 1150;
JUMP_FLOAT :: 0.39;
JUMP_FLOAT_POW :: 1.1;

player_was_damaged :: (damage: *Takes_Damage) -> bool { return false; }

// TODO: get rid of these. use LiveTextures, LiveSprites. something.
gino: LiveTexture;
gino_sprites: struct {
    idle: []Sprite;
    run: []Sprite;
    jump_start: []Sprite;
    jump_mid: []Sprite;
    jump_landing: []Sprite;
    attack: []Sprite;
    attack_miss: []Sprite;
    attack_air: []Sprite;
    damaged: []Sprite;
};

ensure_sprites_loaded :: () {
    // @Speed don't call this every frame for every entity!!
    if !has_value(gino)
        gino = LoadLiveTexture("resources/sprites/gino.png");

    if gino_sprites.idle.count == 0 {
        using gino_sprites;
        all := parse_spriter_atlas("resources/sprites/gino.atlas");
        idle         = sprites_with_prefix(all, "Idle/");
        run          = sprites_with_prefix(all, "Run/");
        jump_start   = sprites_with_prefix(all, "Jump/start/");
        jump_mid     = sprites_with_prefix(all, "Jump/mid/");
        jump_landing = sprites_with_prefix(all, "Jump/landing/");
        attack       = sprites_with_prefix(all, "Attacks/A/");
        attack_miss  = sprites_with_prefix(all, "Throw/Throw Attack/");
        attack_air   = sprites_with_prefix(all, "Attack in jump/");
        damaged      = sprites_with_prefix(all, "Damage/");
    }
    // @Leak
}

#scope_export

On_Damage_Func :: #type (takes_damage: *Takes_Damage) -> bool;

    /*
patch_function_pointers :: () {
    this assumes that functions will be linked in the same order
    
    offset = NEW_DLL_BASE - OLD_DLL_BASE

    for all objects we care about
        for member in type
            if member is a function pointer
                func_ptr += add the offset
}
    */

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
    using context.state;

    return Time.now - damage.time < damage.damage_time;
}

try_take_damage :: (it: *Takes_Damage, delta: Vector2) -> bool {
    if being_damaged(it) return false;

    take_damage(it, delta);
    return true;
}

take_damage :: (using it: *Takes_Damage, in_delta: Vector2) {
    using context.state;

    amount := 1.0;

    health -= amount;
    time = Time.now;
    delta = in_delta;

    invoke_damage_func(it);
}

Player :: struct {
    using component: Component;

    speed: Vector2;
    grounded: bool;
    jump_count: u8;

    jump_button_last_frame: bool;

    horizontal_movement: float;
    last_direction: float; @noui

    sprite_timer: float64;
    walk_timer: float64;

    last_walk_sprite_idx: s16 = -1; @noui

    damage := Takes_Damage.{
        damage_func_type = .Player
    }; @noui

    using transient: struct {
        last_jump_time:float64 = -10000;
        last_attack_time:float64 = -10000;
        attack_did_hit: bool;
        last_grounded_time:float64 = -10000;
        nearest_marker: *reaper.Marker;
        beat_timer: float64; // TODO: duplicated and set from game.jai
    }; @noserialize @noui

    editor_rect: *Editor_Selectable_Rect; @noserialize @noui
}

player_reset :: (using it: *Player) {
    get_transform(it).position.xy = Vector2.{ 400, 280 };
    speed = Vector2.{ 0, 0 };
}

player_has_been_damaged :: (using player: *Player) -> bool {
    return context.state.Time.now - damage.time < DAMAGE_TIME;
}

on_enable :: (using it: *Player, in_entity: *Entity) {
    entity_handle: Entity_Handle = it.entity;
    editor_rect = add_or_get_component(cast(Entity_Handle)entity_handle, Editor_Selectable_Rect);
}

update :: (using player: *Player) {
    ensure_sprites_loaded();

    Time := *context.state.Time;

    is_being_knocked_back := player_has_been_damaged(player);
    sprite_timer += Time.delta_time;

    attacking := player_is_attacking(player);

    input_types := inp.Input_Type.ALL;
    if context.state.editor.play_mode == .Edit
        input_types = ~inp.Input_Type.KEYBOARD_WASD;

    // Separate because in the platformer controls we don't treat up and down as
    // movement that "steals" speed away from the X direction.
    horizontal_movement = inp.movement(input_types, .HORIZONTAL).x;

    if (attacking && player.grounded) || is_being_knocked_back
        horizontal_movement = 0;

    transform := get_transform(player);
    position := *transform.position;

    if editor_rect {
        editor_rect.rect = player_rect(player, transform);
        editor_rect.rect.position -= position.xy;
    }

    position.x += horizontal_movement * PLAYER_HOR_SPD * Time.delta_time;
    if Math.abs(horizontal_movement) > 0
        last_direction = cast(float)sign(horizontal_movement);
    walk_timer += Time.delta_time * Math.abs(horizontal_movement);

    gamepad :: 0;

    a_jump_input_is_present := rl.IsKeyDown(.KEY_SPACE) ||
        (input_types & .KEYBOARD_WASD && rl.IsKeyDown(.KEY_W)) ||
        rl.IsKeyDown(.KEY_UP) ||
        rl.IsGamepadButtonDown(gamepad, .GAMEPAD_BUTTON_RIGHT_FACE_DOWN);

    jump_button_this_frame := !is_being_knocked_back && a_jump_input_is_present;
    jump_button_pressed_this_frame := jump_button_this_frame && !jump_button_last_frame;
    jump_button_last_frame = jump_button_this_frame;

    state := context.state;

    time_since_marker := ifx nearest_marker then beat_timer - nearest_marker.time else 0;
    allow_all_beats := true;

    if !is_being_knocked_back {
        // ATTACK
        if (rl.IsKeyPressed(.KEY_E) || rl.IsGamepadButtonPressed(gamepad, .GAMEPAD_BUTTON_RIGHT_FACE_LEFT)) {
            attack_did_hit = allow_all_beats || (nearest_marker && (Math.abs(time_since_marker) < .2 && nearest_marker.beat_type == .Kick));
            sprite_timer = 0;
            last_attack_time = Time.now;
            play_sfx("sword_swing");
        }

        // JUMP
        if !attacking && jump_button_pressed_this_frame {
            beat_match_type := nearest_marker; // && nearest_marker.beat_type == .Snare;
            matched_beat := allow_all_beats || (Math.abs(time_since_marker) < .2 && beat_match_type);
            max_jump_count := ifx allow_all_beats then 1 else 2;
            did_jump := false;
            if matched_beat && jump_count < max_jump_count {
                if !grounded && !allow_all_beats
                    screenlog.world(<<position, "double jump!");
                //logprint("player", "jump % count=%", time_since_marker, jump_count);
                speed.y = -PLAYER_JUMP_SPD;
                jump_count += 1;
                did_jump = true;
            } else if grounded {
                early_late := ifx time_since_marker > 0 then "late" else "early";
                if !beat_match_type early_late = "wrong beat";
                //logprint("player", "MISS % jump %", early_late, time_since_marker);
                speed.y = -PLAYER_JUMP_SPD * 0.25;
                jump_count = 0;
                did_jump = true;
            }

            grounded = false;

            if did_jump {
                spawn_prefab("player_dust_small", <<position);
                last_jump_time = Time.now;
            }
        }

    }

    hitObstacle := false;
    any_ground_at_feet := false;
    ground_scan_rect := player_ground_scan_rect(player, transform);

    // COLLISION
    p := position;
    for * state.world._BoxCollider {
        rect := entity_rect(it.entity);
        if it.collision & .PLATFORM && (
            (rect.x <= p.x && rect.x + rect.width >= p.x &&
             rect.y >= p.y && rect.y < p.y + speed.y * Time.delta_time))
        {
            hitObstacle = true;
            speed.y = 0.0;
            p.y = rect.y;
            if !grounded {
                if Time.now - last_grounded_time > 0.2 {
                    // landed
                    last_grounded_time = Time.now;
                    spawn_prefab("player_dust", <<position);
                    play_sfx("landing");
                }
            }

            //logprint("player", "grounded");
            grounded = true;
            jump_count = 0;
        }

        if !any_ground_at_feet && rl.CheckCollisionRecs(ground_scan_rect, rect)
            any_ground_at_feet = true;
    }

    if grounded && !any_ground_at_feet {
        grounded = false;
        //logprint("player", "fell");
        jump_count = 1;
    }

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

    // GRAVITY
    if !hitObstacle {
        position.y += speed.y * Time.delta_time;
        MAX_Y :: 5000;
        if position.y > MAX_Y {
            logprint("player", "reseting player position");
            position.y = 0;
            position.x = 50;
            speed.y = 0;
        }


        drag := G * Time.delta_time;
        if speed.y < 0 && jump_button_this_frame
            drag = Math.pow(drag * JUMP_FLOAT, JUMP_FLOAT_POW);
        speed.y += drag;
    }

    //
    // collision with enemies
    //
    attack_hitbox := player_attack_hitbox(player);
    attack_hitbox_rect := player_attack_rect(player, transform);

    if !is_being_knocked_back || attack_hitbox {
        p_rect := player_rect(player, transform);
        p_midpoint := midpoint(p_rect);
        for * state.world._Enemy {
            ok, entity := get_entity(it.entity);
            assert(ok);

            e_transform := get_transform(entity);
            e_rect := enemy_rect(it, e_transform);
            if !is_being_knocked_back && rl.CheckCollisionRecs(e_rect, p_rect) && !being_damaged(*it.damage) {
                // player hit
                delta := midpoint(e_rect) - p_midpoint;
                take_damage(*damage, delta);
                //screenlog.world(p_midpoint, ifx delta.x > 0 then "DMG right" else "DMG left");

                speed.y = -PLAYER_JUMP_SPD * 0.45;
                speed.x = DAMAGE_KNOCKBACK * cast(float)-sign(delta.x);
                grounded = false;
            } else if attack_hitbox && rl.CheckCollisionRecs(e_rect, attack_hitbox_rect) {
                //logprint("player", "hit enemy %", it);

                delta := midpoint(e_rect) - p_midpoint;
                enemy_was_hit_by_player(it, player, delta);
            }
        }
    }

    // catch player falling off the universe
    if position.y > 1000
        context.state.restart();
}

player_is_attacking :: (it: *Player) -> bool {
    using context.state;

    return Time.now - it.last_attack_time < cast(float)gino_sprites.attack.count/ATTACK_FPS;
}

player_attack_hitbox :: (it: *Player) -> bool {
    using context.state;
    time_since_attack := Time.now - it.last_attack_time;
    return time_since_attack < 0.43 && time_since_attack > 0.1;
}

draw :: (using player: *Player) {
    ensure_sprites_loaded();

    state := context.state;
    Time := *state.Time;

    transform := get_transform(player);

    attacking := player_is_attacking(player);
    is_being_knocked_back := player_has_been_damaged(player);

    spr: []Sprite;
    fps: int;
    timer: float64 = sprite_timer;

    squish:float = 1.0;

    walking := false;
    
    {
        using gino_sprites;
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
                launching_anim_time := cast(float)gino_sprites.jump_start.count/fps;
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
            landing_animation_time := cast(float)gino_sprites.jump_landing.count/fps;
            if since_land < landing_animation_time {
                spr = jump_landing;
                N:float : 0.82;
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
            play_sound(wav, 0.9);
        }
    }

    x_offset := 21 * (ifx flip_x then -1 else 1);
    position := *get_transform(player).position;
    dest_rect_pos := position.xy - v2(x_offset, 38) + offset;
    dest_rect := rect(dest_rect_pos.x, dest_rect_pos.y, sprite_rect.width, sprite_rect.height);
    sprite_rect.width *= ifx flip_x then -1 else 1;

    squish_offset := dest_rect.height * (1.0 - squish);
    dest_rect.height *= squish;
    dest_rect.y += squish_offset;

    color := Vector4.{1, 1, 1, 1};
    if is_being_knocked_back
        color = Vector4.{1, .4, .4, 1};

    //dest_rect.x = round(dest_rect.x);
    //dest_rect.y = round(dest_rect.y);
    //dest_rect.width = round(dest_rect.width);
    //dest_rect.height = round(dest_rect.height);

    {
        im_push_entity_handle(player.entity);
        DrawTexturePro(*gino, sprite_rect, dest_rect, v2(0, 0), 0, color);
    }

    //screenlog.world(position, "%", position);

    if state.debug_draw {
        debug_color :: rl.RED;
        draw_point(position.xy, 6, debug_color);
        draw_rect_outline(player_rect(player, transform), 2, debug_color);
        if player_attack_hitbox(player)
            draw_rect_outline(player_attack_rect(player, transform), 2, debug_color);
        
        draw_rect_outline(player_ground_scan_rect(player, transform), 1, Color.{0, 255, 0, 255});
        
        screenlog.world(position.xy, "(%, %)", cast(int)position.x, cast(int)position.y);
    }
}

player_ground_scan_rect :: (using it: *Player, transform: *Transform) -> rl.Rectangle {
    W :: 15;
    return rect(transform.position.x - W/2, transform.position.y, W, 4);
}

player_rect :: (using it: *Player, transform: *Transform=null) -> rl.Rectangle {
    if transform == null {
        // TODO: there should be systems that automatically grab the transform along with the
        // player pointer...

        transform = get_transform(it);
    }
    w := 18;
    h := 30;
    outline_rect := rect(transform.position.x - w/2, transform.position.y - h, w, h);
    return outline_rect;
}

player_attack_rect :: (using it: *Player, transform: *Transform) -> rl.Rectangle {
    x_off := ifx it.last_direction < 0 then -33 else 4;
    return rect(transform.position.x + x_off, transform.position.y - 25, 30, 20);
}

#scope_file
#import "toolbelt";
#import "game_sound_soloud";
#import "Basic";
rl :: #import "raylib";
Color :: rl.Color;
inp :: #import "inp";
Math :: #import "Math";
reaper :: #import "reaper";
screenlog :: #import "screenlog";

