Background :: struct {
    using component: Component;

    timer: float64;
    texture: LiveTexture;
    shader: LiveShader;

    speed := 0.2;
}

update :: (using it: *Background) {
    using context.state;

    timer += Time.delta_time * speed;

    if has_value(shader) {
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
    logprint("=wat", "wat");

    if has_value(shader)
        rl.BeginShaderMode(shader.resource);

    if has_value(texture) {
        rl.DrawTexture(texture.resource, 0, 0, rl.WHITE);
        rl.DrawTexture(texture.resource, texture.width, 0, rl.WHITE);
        rl.DrawTexture(texture.resource, 0, texture.height, rl.WHITE);
        rl.DrawTexture(texture.resource, texture.width, texture.height, rl.WHITE);
    }

    if has_value(shader)
        rl.EndShaderMode();
}

#scope_file

rl :: #import "raylib";
