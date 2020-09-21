Collision_Type :: enum_flags u8 {
    NONE     :: 0;
    PLATFORM :: 1;
}

BoxCollider :: struct {
    using component: Component;
    collision: Collision_Type;

    size:   Vector2 = .{1, 1};
    offset: Vector2 = .{0, 0};
}

worldspace_rect :: (it: *BoxCollider, transform: *Transform = null) -> Rectangle {
    if transform == null
        transform = get_transform(it);

    sz := Vector2Scale(transform.scale.xy, it.size);
    p := transform.position.xy + it.offset;
    return rect_from_points( p - sz * 0.5, p + sz * 0.5);
}
