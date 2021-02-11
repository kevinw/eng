Component :: struct {}
Entity :: struct {}
Component_Bit :: enum_flags {}
State :: struct {}
World :: struct {}
#load "plugin_exports.jai";
#load "host_common.jai";

on_host_did_reload_game_dll :: (host_state: Host_State) {}
on_host_shutdown            :: () {
    print("on_host_shutdown\n");
}
on_host_init                :: (host_state: Host_State) {
    init_synchronization :: () -> *void #runtime_support;
    init_synchronization();
    print("on_host_init\n");
}
update_and_draw             :: (host_state: Host_State) {
}
game_base_draw_compile_error :: () {
}
get_entity :: (component: *Component) -> (bool, *Entity) {
    return false, null;
}
try_reload_live_resource :: (name: string, ext: string) {}
