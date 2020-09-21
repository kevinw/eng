RectRenderer :: struct {
    using component: Component;
    color: Color;
}

draw :: (it: *RectRenderer) {
    color2 := it.color;
    color2.r -= 100; color2.g -= 100; color2.b -= 100;
    DrawRectangleGradientEx(entity_rect(it.entity), it.color, color2, color2, it.color);
}
