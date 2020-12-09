Background :: struct {
    using component: Component;

    timer: float64; @noui
    texture: LiveTexture;
    shader: LiveShader;

    speed := 0.2;

    mode: enum { // these should go away
        Wave;
        Swirl;
    };
}

update :: (using it: *Background) {
    using context.state;

    timer += Time.delta_time * speed;

    if has_value(shader) && mode == .Wave {
        set_shader_val(shader, "secondes", cast(float)timer);
        set_shader_val(shader, "size", rl.make_Vector2(gameWidth, gameHeight));
        set_shader_val(shader, "freqX", 25.0);
        set_shader_val(shader, "freqY", 25.0);
        set_shader_val(shader, "ampX", 5.0);
        set_shader_val(shader, "ampY", 5.0);
        set_shader_val(shader, "speedX", 8.0);
        set_shader_val(shader, "speedY", 8.0);
    }
}

pre_draw :: (using it: *Background) {
    if has_value(shader)
        rl.BeginShaderMode(shader.resource);
    defer {
        if has_value(shader)
            rl.EndShaderMode();
    }

    if has_value(texture) {
        rl.DrawTexture(*texture.resource, 0, 0, rl.WHITE);
        rl.DrawTexture(*texture.resource, texture.width, 0, rl.WHITE);
        rl.DrawTexture(*texture.resource, 0, texture.height, rl.WHITE);
        rl.DrawTexture(*texture.resource, texture.width, texture.height, rl.WHITE);
    }
}

#scope_file

rl :: #import "raylib";
