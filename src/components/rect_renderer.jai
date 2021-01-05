RectRenderer :: struct {
    using component: Component;
    color: rl.Color;
    sorting_layer: Sorting_Layer;
}

_draw :: (it: *RectRenderer) {
    rect := entity_rect(it.entity);

    transform := get_transform(it);
    depth_z := ifx transform != null then transform.position.z else 0;

    //rl.DrawRectangleRec(rect, it.color);

    color2 := it.color;
    color2.r -= 100; color2.g -= 100; color2.b -= 100;

    im_push_entity_handle(it.entity);
    rl.DrawRectangleGradientEx(rect, it.color, color2, color2, it.color, depth_z = depth_z);
    //im_draw_rect(*context.state.im_context, rect.position, rect.size + rect.position);
}

queue_all_drawable :: (sprites: *Array_With_Holes(RectRenderer), by_layer: [256]Drawable_Layer) -> (highest_layer: Sorting_Layer) {
    highest_layer: Sorting_Layer;
    for * sprites {
        array_add(*by_layer[it.sorting_layer].rectrenderers, it);
        highest_layer = max(highest_layer, it.sorting_layer);
    }
    return highest_layer;
}

#scope_file
rl :: #import "raylib";

