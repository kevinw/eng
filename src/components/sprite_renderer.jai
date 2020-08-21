#placeholder state;

SpriteRenderer :: struct {
    using component: Component;

    timer: float64;
    last_timer: float64;
    fps: int = 10; // TODO: no
    color := WHITE;


    canary := 42;

    sprite: []Sprite;
    texture: Texture;
}

on_enable :: (using it: *SpriteRenderer) {
    entity.flags |= .Has_Component_Rect;
}

get_entity_rect :: (using it: *SpriteRenderer) -> (bool, Rectangle) {
    if sprite.count > 0 {
        pos := it.entity.transform.position.xy;
        r, offset, idx := sprite_get_rect(sprite, 0, 0);
        return true, make_Rectangle(pos.x + offset.x, pos.y + offset.y, r.width, r.height);
    }

    return false, .{};
}

update :: (using it: *SpriteRenderer) {
    using it.entity;
    last_timer = timer;
    timer += state.Time.delta_time;

}

draw :: (using it: *SpriteRenderer) {
    if sprite.count == 0 return;

    position := *entity.transform.position;

    sprite_rect, offset := sprite_get_rect(sprite, timer, fps);
    dest_rect := rect(position.x + offset.x, position.y + offset.y, sprite_rect.width, sprite_rect.height);
    origin := v2(0, 0);

    DrawTexturePro(texture, sprite_rect, dest_rect, origin, 0, color);

/*
    using it.entity;

    w := cast(s32)transform.scale.x;
    h := cast(s32)transform.scale.y;

    x := cast(s32)(transform.position.x - w * 0.5);
    y := cast(s32)(transform.position.y - h * 0.5);

    DrawRectangleGradientH(
        x, 
        y,
        w,
        h, 
        BLACK,
        WHITE);
*/
}

#scope_file
#import "raylib";
#import "toolbelt";