#load "game_base.jai";

State :: struct {
    using state_base: State_Base;

}

update_and_draw :: (host_state: Host_State) {
    using context.state;
}

on_host_shutdown :: () {
    game_base_shutdown();
}

on_host_did_reload_game_dll :: (host_state: Host_State) {
    using context.state;

    game_base_did_reload_dll(host_state);
    //set_function_pointers();
}

#scope_file

set_function_pointers :: () {
}
