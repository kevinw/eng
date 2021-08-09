#load "game_base.jai";

State :: struct {
    using state_base:  State_Base;
}

update_and_draw :: (host_state: Host_State) {
    game_base_default_update_and_draw(host_state);
}

on_host_did_reload_game_dll :: (host_state: Host_State) {
    using context.state;

    game_base_did_reload_dll(host_state);
    set_function_pointers();
}

on_host_shutdown :: () {
    game_base_shutdown();
}

on_host_init :: (host_state: Host_State) {
    using context.state;

    // without creating soloud's context in the host, I get crashes on reload.
    // my theory right now is that it must have thread local storage, which,
    // inside the DLL, gets unloaded. but I don't want to investigate this right now.
    // so here we just receive the soloud context from the host.
    sound_state.soloud = host_state.soloud_context;

    game_base_init(host_state);
    set_function_pointers();

    editor.show_aspect_ratio_guide = false;

    //load_scene(1);
}

set_function_pointers :: () {
    game_base_set_function_pointers();
}

#scope_file

#import "renderer";
#import "renderer_im";
#import "renderer_im_impl";
#import "Math";
Input   :: #import "Input";
Gamepad :: #import "Gamepad";
Sort :: #import "Sort";
rl :: #import "raylib";

