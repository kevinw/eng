Simple_Image_Renderer :: struct {
    using component: Component;

    texture: LiveTexture;
    tint: rl.Color = rl.WHITE;
}

draw :: (using it: *Simple_Image_Renderer, transform: *Transform) {
    if !has_value(texture)
        return;
    tex := texture.resource;

    source_rect := rl.make_Rectangle(0, 0, tex.width, tex.height);
    dest_rect := rl.make_Rectangle(transform.position.x, transform.position.y, source_rect.width, source_rect.height);
    origin: rl.Vector2;
    rotation := 0.0;

    rl.DrawTexturePro(tex, source_rect, dest_rect, origin, rotation, tint);
}

#scope_file

rl :: #import "raylib";
