RectRenderer :: struct {
    using component: Component;
    color: rl.Color;
}

draw :: (it: *RectRenderer) {
    rect := entity_rect(it.entity);

    //rl.DrawRectangleRec(rect, it.color);

    color2 := it.color;
    color2.r -= 100; color2.g -= 100; color2.b -= 100;
    rl.DrawRectangleGradientEx(rect, it.color, color2, color2, it.color);
}

#scope_file
rl :: #import "raylib";

