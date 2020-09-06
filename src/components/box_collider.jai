Collision_Type :: enum_flags u8 {
    NONE     :: 0;
    PLATFORM :: 1;
}

BoxCollider :: struct {
    using component: Component;
    collision: Collision_Type;
}

on_enable :: (using it: *BoxCollider, parent_entity: *Entity) {
}