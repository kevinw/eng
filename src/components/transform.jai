Transform :: struct {
    using component: Component;

    position: Vector3    = .{0, 0, 0};
    rotation: Quaternion = .{0, 0, 0, 1};
    scale:    Vector3    = .{1, 1, 1};
}

get_lossy_scale :: (it: Entity_Handle) -> Vector3 {
    transform := get_transform(it);
    assert(transform != null);

    return transform.scale; // TODO: parents scale, etc
}

Link :: struct {
    // Note that this requires that transformations are sorted so that
    // parents are always before their children

    using component: Component;

    parent:        Entity_Handle;
    sibling_index: u32;
}

TRS :: Transform; // TODO: an alias until Raylib is entirely gone

#scope_file

rl :: #import "raylib";
