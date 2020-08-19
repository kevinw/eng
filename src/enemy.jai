#scope_file
ATTACK_FPS :: 13;
ATTACK_COOLDOWN :: 1.2;
ATTACK_CHOMP_TIME :: 0.295;
DYING_FPS :: 3;
#scope_module

Enemy :: struct {
    using entity: Entity;

    sprite_timer: float64;
    last_sprite_timer: float64;

    damage := Takes_Damage.{
        health = 1,
        damage_time = 0.9,
        damage_func = (it: *Takes_Damage) -> bool {
            if it.health == 0 {
                enemy := get_parent_struct(Enemy, it);
                enemy.dying_timer = cast(float)state.sprites.evilplant.hit.count/DYING_FPS;
                enemy.sprite_timer = 0;
            }
            return false;
        }
    };

    last_attack_time: float64;
    last_attack_direction_right: bool;

    dying_timer: float;

    attack_cooldown: float;

    padding: [30-8-8-4]u8;
}

enemy_was_hit_by_player :: (using it: *Enemy, player: *Player, delta: Vector2) {
    if try_take_damage(*damage, delta) {
        last_attack_time = -99999;
        attack_cooldown = ATTACK_COOLDOWN;
    }
}

enemy_rect :: (using it: *Enemy) -> Rectangle {
    since_attack := Time.now - last_attack_time;

    if since_attack > 0.38 && since_attack < 0.7 { // when attacking, enemy rect changes
        w:float = 40;
        if !last_attack_direction_right w *= -1;
        return rect_from_points(position + v2(w, 0), position + v2(0, -35));
    }

    w:float = 17;
    h:float = 35;
    return rect_from_points(position + v2(-w*0.5, 0), position + v2(w*0.5, -h));
}

enemy_trigger_rect :: (using it: *Enemy) -> Rectangle {
    w:float: 90;
    h:float = 25;
    return rect_from_points(position + v2(-w*0.5, 0), position + v2(w*0.5, -h));
}

enemy_is_attacking :: (using it: *Enemy) -> bool {
    return Time.now - last_attack_time < cast(float)state.sprites.evilplant.attack_left.count/ATTACK_FPS;
}

enemy_draw :: (using it: *Enemy) {
    using state;

    fps := 10;

    spr := sprites.evilplant.idle;
    if dying_timer > 0 {
        spr = sprites.evilplant.hit;
        fps = DYING_FPS;
    } else if enemy_is_attacking(it) {
        if last_attack_direction_right
            spr = sprites.evilplant.attack_right;
        else
            spr = sprites.evilplant.attack_left;
    }
    sprite_rect, offset := sprite_get_rect(spr, it.sprite_timer, fps);
    
    OFF := v2(32, 37);

    dest_rect_pos := position - OFF + offset;

    dest_rect := rect(dest_rect_pos.x, dest_rect_pos.y, sprite_rect.width, sprite_rect.height);

    color := WHITE;
    if being_damaged(*damage) {
        color = ColorFromNormalized(Vector4.{1, .5, .5, 1});
    }
    DrawTexturePro(textures.evilplant, sprite_rect, dest_rect, v2(0, 0), 0, color);

    if debug_draw {
        draw_point(position, 4, RED);
        r := enemy_rect(it);
        draw_rect_outline(r, 2, RED);
        draw_rect_outline(enemy_trigger_rect(it), 2, RED);
    }
}

enemy_update_all :: () {
    p_rect := player_rect(*state.player);
    player_midpoint := midpoint(p_rect);

    for * state.enemies {
        using it;
        if dying_timer > 0 {
            dying_timer -= Time.delta_time;
            if dying_timer <= 0 {
                remove it;
                continue;
            }
        }
        sprite_timer += Time.delta_time;
        if enemy_is_attacking(it)
            if last_sprite_timer < ATTACK_CHOMP_TIME && sprite_timer > ATTACK_CHOMP_TIME
                Soloud_play(state.sound_state.soloud, state.sound_state.fx.chomp);
        last_sprite_timer = sprite_timer;
        attack_cooldown -= Time.delta_time;

        if attack_cooldown > 0 continue;

        e_rect := enemy_trigger_rect(it);
        if CheckCollisionRecs(p_rect, e_rect) {
            // ENEMY ATTACKING!
            attack_cooldown = ATTACK_COOLDOWN;

            e_midpoint := midpoint(e_rect);
            delta := e_midpoint - player_midpoint;

            last_attack_time = Time.now;
            last_attack_direction_right = delta.x < 0;
            sprite_timer = 0;
        }

    }
}