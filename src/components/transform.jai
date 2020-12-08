Transform :: struct {
    using component: Component;

    position: Vector3    = .{0, 0, 0};
    rotation: Quaternion = .{0, 0, 0, 1};
    scale:    Vector3    = .{1, 1, 1};
}

Link :: struct {
    using component: Component;

    parent: Entity_Handle;
}

TRS :: Transform; // an alias until Raylib is entirely gone

#scope_file

rl :: #import "raylib";
