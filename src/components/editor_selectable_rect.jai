Editor_Selectable_Rect :: struct {
    using component: Component;

    rect: rl.Rectangle; // right now this is relative to 0 defined by the transform's position. could probably be made more usable
}

on_enable :: (using it: *Editor_Selectable_Rect, parent_entity: *Entity) {
    parent_entity.flags |= .Has_Component_Rect;
}

/*
draw :: (using it: *Editor_Selectable_Rect) {
    rl.DrawRectangleLinesEx(it.rect, 2, rl.RED);
}
*/

#scope_file
rl :: #import "raylib";
