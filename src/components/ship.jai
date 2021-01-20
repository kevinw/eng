Ship :: struct {
    using component: Component;

    speed: float : 50.0;
}

update :: (using it: *Ship, transform: *Transform) {
    using context.state;

    input_types := inp.Input_Type.ALL;
    if context.state.editor.play_mode == .Edit
        input_types = ~inp.Input_Type.KEYBOARD_WASD;

    move := inp.movement(input_types);
    transform.position.xy += move * Time.delta_time * speed;

    screenp(#code move);
}

#scope_file
inp :: #import "inp";
