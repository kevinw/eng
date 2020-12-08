GAME_NAME :: "d3d_game";
#load "game_base.jai";

State :: struct {
    using state_base: State_Base;
    renderer: Renderer;
    im_context: Im_Context_R;
}

update_and_draw :: () {
    using context.state;

    host_state := _local_host_state;

    Gamepad.update_gamepad();
    handle_input_module_renderer_resize(host_state.window_handle, host_state.pending_resizes);
    ImGui_Impl_ProcessInputEvents(*ui, host_state.events_this_frame);
    game_base_update();

    // draw
    defer present();
    push_default_pass(clear_color=*Vector4.{0.2, 0, 0.2, 1});

    editor_draw(context.state);

    {
        world_draw(*world);
        draw_all_drawables(*world);
        physics_2d_draw_debug();
        editor_draw_world(context.state);
        screenlog_draw.draw_world();
    }

    imgui_render(*ui);
    im_finish(*im_context);
}

_update_raylib_temp :: (host_state: Host_State) {
    using context.state;

    // These go away once we remove the fake raylib module entirely.
    rl._XXX_SetRenderer(*renderer);
    rl._XXX_SetNativeWindow(host_state.window_handle);
    rl._XXX_SetHostInputButtonStates(host_state.input_button_states);
}

on_host_did_reload_game_dll :: (host_state: Host_State) {
    using context.state;

    Gamepad.init_gamepad();

    set_global_renderer_ptr(*renderer);
    _update_raylib_temp(host_state);
    game_base_did_reload_dll();
}

on_host_shutdown :: () {
    using context.state;
    game_base_shutdown();
}

on_host_init :: (host_state: Host_State) {
    using context.state;
    set_context_funcs();

    Gamepad.init_gamepad();
    print("Called init_gamepad: %\n", Gamepad.gamepad);

    init(*renderer, host_state.window_handle);
    _update_raylib_temp(host_state);
    ui.d3dDevice = xx renderer.device;
    ui.d3dDeviceContext = xx renderer.device_context1;
    game_base_init(host_state);

    im_context.renderer = *renderer;
    im_init_renderer(*im_context);
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

handle_input_module_renderer_resize :: (window_handle: Window_Type, pending_resizes: *[..]Window_Resize_Record) {
    // the jai input module queues up records for window resizes...
    // here we resize the swapchain for the newest size.
    did_resize: bool;
    w, h: int;
    for * <<pending_resizes if it.window == window_handle {
        did_resize = true;
        w = it.width;
        h = it.height;
        remove it;
    }

    if did_resize
        resize_swapchain(xx w, xx h);
}

#scope_file
#import "renderer";
#import "renderer_im";
#import "renderer_im_impl";
Gamepad :: #import "Gamepad";
rl :: #import "raylib";
screenlog_draw :: #import "screenlog_draw";
