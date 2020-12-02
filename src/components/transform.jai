Transform :: struct {
    using component: Component;

    position: rl.Vector3    = .{0, 0, 0};
    rotation: rl.Quaternion = .{0, 0, 0, 1};
    scale:    rl.Vector3    = .{1, 1, 1};
}

Link :: struct {
    using component: Component;

    parent: Entity_Handle;
}

TRS :: Transform; // an alias until Raylib is entirely gone

#scope_file

rl :: #import "raylib";
