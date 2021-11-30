#load "game_base.jai";

State :: struct {
    using state_base:  State_Base;
}

update_and_draw :: (host_state: Host_State) {
    game_base_update_and_draw(host_state, multiview=false);

    using context.state;
    Soloud_setPause(sound_state.soloud, sound_state.bgm_voice, cast(s32)(editor.play_mode != .Play)); 
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
    editor.scene_camera.position = .{500, 300, -300};
    set_function_pointers();

    add_material("pbr", "resources/shaders/unlit_texture.hlsl");

    // tests
    {
        scoped_test_world();
        assert(find_component(Player) == null);
        entity1, entity1_handle := create_entity(name="Test1");
        player := add_component(entity1_handle, Player);
        assert(find_component(Player) == player);
        assert(player.editor_rect != null, "Player.on_enable should have set the player's editor_rect pointer--was on_enable called?");

        did_remove := remove_component(player);
        assert(did_remove);

        did_remove_again := remove_component(player);
        assert(!did_remove_again);
    }

    // music init
    {
        #import "soloud";
        sound_state.bgm_voice = Soloud_play(sound_state.soloud, sound_state.bgm);
    }

    //load_scene(1);
    new_scene();
}

set_function_pointers :: () {
    context.state.editor.callbacks.did_drag = editor_did_drag;
    game_base_set_function_pointers();
}

#scope_file

editor_did_drag :: (rect: rl.Rectangle) {
    using context.state;

    color := rl.RED;
    color.b = cast(u8)random_get_within_range(100, 255);
    block, block_h := make_platform(world,
        rect.x, rect.y, rect.width, rect.height,
        .PLATFORM, color, is_editor=true);

    Undo.push_array(*editor.undo_state, *editor.selected);
    set_selected(block_h);
    Undo.commit(*editor.undo_state);
}

make_platform :: (world: *World, x: float, y: float, width: float, height: float, collision: Collision_Type, color: rl.Color, is_editor: bool = false) -> (*Entity, Entity_Handle) {
    undo: *Undo.Impl;
    if is_editor undo = *context.state.editor.undo_state;

    entity, entity_handle := create_entity(world, "box", undo=undo);
    assert(entity != null);

    transform := get_component(entity, TRS);
    assert(transform != null);
    transform.position.xy = v2(x, y);
    transform.scale = make_vector3(width, height, 1);

    box := add_component(entity_handle, BoxCollider, undo=undo);
    box.collision = .PLATFORM;

    renderer := add_component(entity_handle, RectRenderer, undo=undo);
    renderer.color = color;


    return entity, entity_handle;
}

#import "renderer";
#import "renderer_im";
#import "renderer_im_impl";
#import "multiview";
#import "Math";
Input   :: #import "Input";
Gamepad :: #import "Gamepad";
Sort :: #import "Sort";
rl :: #import "raylib";
multiview_window :: #import "multiview_window";

