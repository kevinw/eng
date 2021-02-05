Transform :: struct {
    using component: Component;

    position: Vector3    = .{0, 0, 0};
    rotation: Quaternion = .{0, 0, 0, 1};
    scale:    Vector3    = .{1, 1, 1};
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
