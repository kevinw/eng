SpriteRenderer :: struct {
    using component: Component;

    timer: float64;
    last_timer: float64;
    fps: int = 10; // TODO: no
    color := WHITE;

    sprite: []Sprite;
    texture: Texture;

    canary := 42;

    sprite_anim: LiveSprite;
    anim_tag: string;
    
    _current_frame: Sprite_Anim.Sprite_Anim.Frame; @noserialize
    _last_frame_index: int;

    mode: Mode;

    Mode :: enum u8 {
        Play_Forever      :: 0;
        Play_Once_And_Die :: 1;
    }
}

on_enable :: (using it: *SpriteRenderer, parent_entity: *Entity) {
    parent_entity.flags |= .Has_Component_Rect;
}

get_entity_rect :: (using it: *SpriteRenderer) -> (bool, Rectangle) {
    if sprite.count > 0 {
        ok, entity := get_entity(it.entity);
        if ok {
            pos := entity.transform.position.xy;
            r, offset, idx := sprite_get_rect(sprite, 0, 0);
            return true, make_Rectangle(pos.x + offset.x, pos.y + offset.y, r.width, r.height);
        }
    }

    return false, .{};
}

update :: (using it: *SpriteRenderer) {
    assert(entity.id > 0);
    assert(canary == 42);

    last_timer = timer;
    timer += context.state.Time.delta_time;

    if has_value(sprite_anim) {
        ok: bool;
        index: int = -1;
        ok, _current_frame, index = Sprite_Anim.get_frame(sprite_anim._entry, timer, anim_tag);
        if mode == .Play_Once_And_Die && _last_frame_index > 0 && index == 0  {
            destroy_entity(entity);
        }
        _last_frame_index = index;
    }
}

draw :: (using it: *SpriteRenderer, transform: *Transform) {
    assert(entity.id > 0);
    position := *transform.position;

    if sprite.count > 0 {
        sprite_rect, offset := sprite_get_rect(sprite, timer, fps);
        dest_rect := rect(position.x + offset.x, position.y + offset.y, sprite_rect.width, sprite_rect.height);
        origin := v2(0, 0);
        DrawTexturePro(texture, sprite_rect, dest_rect, origin, 0, color);
    }

    if has_value(sprite_anim)
        Sprite_Anim.draw_frame(_current_frame, position.xy);
}

draw_debug :: (using it: *SpriteRenderer, transform: *Transform) {
    
    
}

#scope_file
#import "raylib";
#import "toolbelt";
Sprite_Anim :: #import "Sprite_Anim";
#import "Live_Types";
