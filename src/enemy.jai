#scope_file
DAMAGE_TIME :: 0.9;
#scope_module

Enemy :: struct {
    using entity: Entity;

    sprite_timer: float64;

    damage: Takes_Damage;
}


enemy_was_hit_by_player :: (using it: *Enemy, now: float64, player: *Player, delta: Vector2) {
    if !being_damaged(now, *damage, DAMAGE_TIME) {
        damage.time = now;
        damage.delta = delta;
    }
}

enemy_damage_time :: (using it: *Enemy) -> float { return DAMAGE_TIME; }

enemy_rect :: (using it: *Enemy) -> Rectangle {
    w:float = 17;
    h:float = 35;
    return rect_from_points(position + v2(-w*0.5, 0), position + v2(w*0.5, -h));
}

enemy_draw :: (using it: *Enemy) {
    using state;

    now := GetTime();

    fps := 10;
    sprite_rect, offset := sprite_get_rect(sprites.evilplant.idle, it.sprite_timer, fps);
    
    OFF := v2(32, 37);

    dest_rect_pos := position - OFF + offset;

    dest_rect := rect(dest_rect_pos.x, dest_rect_pos.y, sprite_rect.width, sprite_rect.height);

    color := WHITE;
    if being_damaged(now, *damage, DAMAGE_TIME) {
        color = RED;
    }
    DrawTexturePro(textures.evilplant, sprite_rect, dest_rect, v2(0, 0), 0, color);

    if debug_draw {
        draw_point(position, 4, RED);
        r := enemy_rect(it);
        draw_rect_outline(r, 2, RED);
    }
}

enemy_update_all :: (delta_time: float) {
    for * state.enemies
        it.sprite_timer += delta_time;
}