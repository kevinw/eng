GAME_NAME :: "d3d_game";
#load "game_base.jai";


State :: struct {
    using state_base: State_Base;
    renderer: Renderer;
    im_context: Im_Context_R;
}

update_and_draw :: () {
    using context.state;

    ImGui_Impl_ProcessInputEvent(*ui, _local_host_state.host_events_this_frame);
    game_base_update();

    // draw
    defer present();
    push_default_pass(clear_color=*Vector4.{1, 0, 1, 1});

    editor_draw(context.state);

    ImGui.Render();
    ok := ImGui_Impl_RenderDrawData(*ui, ImGui.GetDrawData());
    assert(ok);

    im_draw_rect(*im_context,
        p0=v2(30, 30), p1=v2(200, 250),
        t0=v2(0, 0),   t1=v2(1, 1),
        c =v4(1, .5, .5, 1));

    im_flush(*im_context);
}


on_host_did_reload_game_dll :: (host_state: Host_State) {
    using context.state;
    set_global_renderer_ptr(*renderer);

    rl._XXX_SetRenderer(*renderer);
    rl._XXX_SetNativeWindow(host_state.window_handle);
    game_base_did_reload_dll();
}

on_host_shutdown :: () {
    using context.state;
    game_base_shutdown();
}

on_host_init :: (host_state: Host_State) {
    using context.state;
    set_context_funcs();

    init(*renderer, host_state.window_handle);
    rl._XXX_SetRenderer(*renderer);
    rl._XXX_SetNativeWindow(host_state.window_handle);
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

#scope_file
#import "renderer";
#import "renderer_im";
#import "renderer_im_impl";
rl :: #import "raylib";
