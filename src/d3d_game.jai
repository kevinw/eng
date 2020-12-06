GAME_NAME :: "d3d_game";
#load "game_base.jai";

State :: struct {
    using state_base: State_Base;
    renderer: Renderer;
}

update_and_draw :: () {
    // update
    game_base_update();

    // draw
    defer present();
    push_default_pass(clear_color=*Vector4.{1, 0, 1, 1});
}

on_host_did_reload_game_dll :: () {
}

on_host_shutdown :: () {
    using context.state;

    game_base_shutdown();
}

on_host_init :: (host_state: Host_State) {
    using context.state;
    set_context_funcs();

    game_base_init();

    init(*renderer, host_state.window_handle);
}

set_context_funcs :: () {
    context.state.restart = restart;
    context.state.editor.callbacks.did_drag = editor_did_drag;
}

restart :: () {
    using context.state;
}

editor_did_drag :: (rect: rl.Rectangle) {
}

#scope_file
#import "renderer";
rl :: #import "raylib";
