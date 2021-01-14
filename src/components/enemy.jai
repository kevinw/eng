#scope_file
ATTACK_FPS :: 13;
ATTACK_COOLDOWN :: 1.2;
ATTACK_CHOMP_TIME :: 0.295;
DYING_FPS :: 9;
#import "raymath";
#import "game_sound_soloud";
#import "Sprite_Anim";
rl :: #import "raylib";

evilplant: LiveTexture;
evilplant_sprite: struct {
    idle:          []Sprite;
    hit:           []Sprite;
    attack_left:   []Sprite;
    attack_right:  []Sprite;
};

ensure_sprites_loaded :: () {
    if !has_value(evilplant)
        evilplant = LoadLiveTexture("resources/sprites/evilplant.png");
    if evilplant_sprite.idle.count == 0 {
        using evilplant_sprite;

        all := parse_spriter_atlas("resources/sprites/evilplant.atlas");
        idle = sprites_with_prefix(all, "Idle/");
        hit  = sprites_with_prefix(all, "Hit/");
        attack_left = sprites_with_prefix(all, "Attack_Left/");
        attack_right = sprites_with_prefix(all, "Attack_Right/");
        // @Leak
    }
}

#scope_export

enemy_was_damaged :: (using it: *Takes_Damage) -> bool {
    play_sfx("whack");

    if it.health == 0 {
        enemy := get_parent_struct(Enemy, it);
        enemy.dying_timer = cast(float)evilplant_sprite.hit.count/DYING_FPS;
        enemy.sprite_timer = 0;
    }

    return false;
}

Enemy :: struct {
    using component: Component;

    sprite_timer: float64;
    last_sprite_timer: float64;

    damage := Takes_Damage.{
        health = 1,
        damage_time = 0.9,
        damage_func_type = .Enemy,
    };

    attack_timer: float = 0;
    last_attack_direction_right: bool;

    dying_timer: float;

    attack_cooldown: float;

    padding: [30]u8; @noserialize

    editor_rect: *Editor_Selectable_Rect; @noserialize
}

on_enable :: (using it: *Enemy, parent_entity: *Entity) {
    editor_rect = add_component(it.entity, Editor_Selectable_Rect);
}

enemy_was_hit_by_player :: (using it: *Enemy, player: *Player, delta: Vector2) {
    if try_take_damage(*damage, delta) {
        attack_timer = 0;
        attack_cooldown = ATTACK_COOLDOWN;
    }
}

enemy_rect :: (using it: *Enemy, transform: *Transform=null) -> rl.Rectangle {
    using context.state;

    if transform == null
        transform = get_transform(it);

    since_attack := get_attack_time(it) - attack_timer;
    position := *transform.position;

    if since_attack > 0.38 && since_attack < 0.60 { // when attacking, enemy rect changes
        w:float = 40;
        if !last_attack_direction_right w *= -1;
        return rect_from_points(position.xy + v2(w, 0), position.xy + v2(0, -35));
    }

    w:float = 17;
    h:float = 35;
    return rect_from_points(position.xy + v2(-w*0.5, 0), position.xy + v2(w*0.5, -h));
}

enemy_trigger_rect :: (using it: *Enemy, transform: *Transform) -> rl.Rectangle {
    position := *transform.position;
    w:float: 90;
    h:float = 25;
    return rect_from_points(position.xy + v2(-w*0.5, 0), position.xy + v2(w*0.5, -h));
}

get_attack_time :: (using it: *Enemy) -> float {
    return cast(float)evilplant_sprite.attack_left.count/cast(float)ATTACK_FPS;
}

enemy_is_attacking :: (using it: *Enemy) -> bool {
    return attack_timer > 0;
}

draw :: (using it: *Enemy, transform: *Transform) {
    ensure_sprites_loaded(); // @Speed

    using context.state;

    position := *transform.position;

    fps := 10;

    spr := evilplant_sprite.idle;
    if dying_timer > 0 {
        spr = evilplant_sprite.hit;
        fps = DYING_FPS;
    } else if enemy_is_attacking(it) {
        if last_attack_direction_right
            spr = evilplant_sprite.attack_right;
        else
            spr = evilplant_sprite.attack_left;
    }
    sprite_rect, offset := sprite_get_rect(spr, it.sprite_timer, fps);
    
    OFF := v2(32, 37);

    dest_rect_pos := position.xy - OFF + offset;
    dest_rect := rect(dest_rect_pos.x, dest_rect_pos.y, sprite_rect.width, sprite_rect.height);

    color: Vector4 = ---;
    if being_damaged(*damage)
        color = Vector4.{1, .5, .5, 1};
    else
        color = Vector4.{1, 1, 1, 1};

    {
        im_push_entity_handle(it.entity);
        DrawTexturePro(*evilplant, sprite_rect, dest_rect, v2(0, 0), 0, color);
    }

    if debug_draw {
        draw_point(position.xy, 4, rl.RED);
        r := enemy_rect(it, transform);
        draw_rect_outline(r, 2, rl.RED);
        draw_rect_outline(enemy_trigger_rect(it, transform), 2, rl.RED);
    }
}

// TODO: implement an "update_all" hook

enemy_update_all :: () {
    using context.state;

    p_rect: rl.Rectangle;
    player_midpoint: Vector2;

    all_players := get_components(Player);
    assert(all_players.count < 2, "right now only coded for one player, but there are: %", all_players.count);
    if all_players.count > 0 {
        p_rect = player_rect(all_players[0]); // TODO: remove state's reference to *Player (so there could be more than one!)
        player_midpoint = midpoint(p_rect);
    }

    for * context.state.world._Enemy {
    //for * state.enemies {
        transform := get_transform(it);
        it.editor_rect.rect = enemy_rect(it, get_transform(it));

        using it;
        if dying_timer > 0 {
            dying_timer -= Time.delta_time;
            if dying_timer <= 0 {
                destroy_entity(entity);
                continue;
            }
        }
        sprite_timer += Time.delta_time;
        timer_decrement(*attack_timer);
        if enemy_is_attacking(it)
            if last_sprite_timer < ATTACK_CHOMP_TIME && sprite_timer > ATTACK_CHOMP_TIME
                play_sfx("chomp");
        last_sprite_timer = sprite_timer;
        attack_cooldown -= Time.delta_time;

        if attack_cooldown > 0 continue;

        if all_players.count > 0 {
            e_rect := enemy_trigger_rect(it, transform);
            if rl.CheckCollisionRecs(p_rect, e_rect) {
                // ENEMY ATTACKING!
                attack_cooldown = ATTACK_COOLDOWN;

                e_midpoint := midpoint(e_rect);
                delta := e_midpoint - player_midpoint;

                attack_timer = get_attack_time(it);
                last_attack_direction_right = delta.x < 0;
                sprite_timer = 0;
            }
        }

    }
}
