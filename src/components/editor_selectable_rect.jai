Editor_Selectable_Rect :: struct {
    using component: Component;

    rect: Rectangle;
}

on_enable :: (using it: *Editor_Selectable_Rect, parent_entity: *Entity) {
    parent_entity.flags |= .Has_Component_Rect;
}

