Parallax_Background :: struct {
    using component: Component;

    texture: LiveTexture;
}

draw :: (using it: *Parallax_Background) {
    using context.state;

    if has_value(texture) {
        rl.DrawTexture(texture.resource, cast(s32)(Math.sin(Time.now) * 30), 0, rl.WHITE);
    }
}

#scope_file
rl :: #import "raylib";
Math :: #import "Math";
