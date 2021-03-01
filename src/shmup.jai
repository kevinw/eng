#load "game_base.jai";

State :: struct {
    using state_base: State_Base;

    mesh: Mesh;
}

on_host_init :: (host_state: Host_State) {
    game_base_init(host_state);
    set_function_pointers();
    load_scene(7);
    
    add_material("pbr", "resources/shaders/unlit_texture.hlsl");

    before := get_time();
    //filename := "resources/models/the-wiz-boots/wizboots_left_withfill2007_3_8_4ab_11stops-3d-textured-0524288-150k-unwrapped.obj";
    filename := "resources/models/death-row-spaceship/source/DeathRow_lowpoly.obj";
    //filename := "resources/models/flight-helmet/FlightHelmet.gltf";
    //filename := "resources/models/reference/cube/cube.obj";
    mesh_ok: bool;
    {
        print_time("mesh", "loaded %", filename);
        mesh_ok = load_mesh(*context.state.mesh, filename);
    }
    log("mesh load: % - %", mesh_ok, filename);


    mesh_renderer := find_component(Mesh_Renderer);
    if mesh_renderer != null {
        mesh_renderer.mesh = *context.state.mesh;
    }
}

update_and_draw :: (host_state: Host_State) {
    using context.state;
    game_base_default_multiview_update_and_draw(host_state);
}

on_host_shutdown :: () {
    game_base_shutdown();
}

on_host_did_reload_game_dll :: (host_state: Host_State) {
    using context.state;

    game_base_did_reload_dll(host_state);
    set_function_pointers();
}

#scope_file

set_function_pointers :: () {
}

#import "renderer";
#import "mesh";
#import "mesh_draw";
