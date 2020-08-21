#placeholder state;

SpriteRenderer :: struct {
    using component: Component;

    timer: float64;
    last_timer: float64;
    fps: int = 10; // TODO: no
    color := WHITE;

    sprite: []Sprite;
    texture: Texture;
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