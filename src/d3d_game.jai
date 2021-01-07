#load "game_base.jai";

Profiler_Timestamps :: enum {
	BeginFrame;

    MultiviewWorldRender;
    LenticularBlit;

    EditorWorldRender;
    EditorUI;

	EndFrame;
}

State :: struct {
    using state_base:  State_Base;

    renderer:      Renderer;
    im_context:    Im_Context_R;
    multiview:     Multiview_State;
    mview_window:  multiview_window.State;

    current_im_camera: *Camera;
}

update_and_draw :: () {
    using context.state;

    set_context(*renderer);

    host_state := _local_host_state;

    Gamepad.update_gamepad();
    handle_input_module_renderer_resize(host_state.window_handle, host_state.pending_resizes);
    ImGui_Impl_ProcessInputEvents(*ui, host_state.events_this_frame);
    game_base_update(host_state);

    begin_frame(*profiler);

    // draw the main window
    im := *im_context;

    // looking glass window
    {
        push_renderer_context(*mview_window.mview_renderer, "lkg display");

        cam: *Camera;
        game_camera := get_main_camera();
        if game_camera == null {
            cam = *context.state.editor.scene_camera;
        } else {
            cam = *game_camera.camera;
        }

        push_value(*current_im_camera, cam);
        {
            // render quilt
            push_pass(*multiview.offscreen.pass, clear_color=*Vector4.{0, 0, 0, 0});
            world_draw(*world);
            draw_all_drawables(*world);
            im_flush(im);
            timestamp(*profiler, .MultiviewWorldRender);
        }

        begin_default_pass(clear_color=*Vector4.{0.0, 0, 0.0, 1});
        draw_lenticular_lightfield_to_backbuffer();
        end_pass();
        present();
        timestamp(*profiler, .LenticularBlit);
    }

    // default pass for main monitor
    {
        push_renderer_context(*context.state.renderer, "main monitor");
        push_value(*current_im_camera, *editor.scene_camera);
        begin_default_pass(clear_color=*Vector4.{0.0, 0, 0.0, 1});
        main_monitor_aspect := framebuffer_aspect();
        {
            // the im draw stuff here (And probably?) should only render 1 view.
            multiview.num_views_this_frame = multiview.num_views; // just to visualize in the editor
            push_value(*multiview.num_views, 1); 

            {
                im.track_mouse = true;
                defer im.track_mouse = false;

                world_draw(*world);
                draw_all_drawables(*world);
                im_flush(im);
                timestamp(*profiler, .EditorWorldRender);
            }

            im_set_texture(im, null);
            wait_for_data_and_update(*profiler);
            update_profiler_text();
            editor_draw(context.state);
            im_flush(im);

            physics_2d_draw_debug();
            editor_draw_world(context.state);
            screenlog_draw.draw_world();
            im_flush(im);
            timestamp(*profiler, .EditorUI);
        }


        imgui_render(*ui);
        end_pass();
        present();
    }

    end_frame(*profiler);
}

update_profiler_text :: () {
    using context.state;

    dTDrawTotal:float = 0.0;

    for event_idx: 0..profiler.query.count - 1
        dTDrawTotal += profiler.averaged_timings[event_idx];

    fmt :: #bake_arguments formatFloat(trailing_width = 2);
    profiler_text = tprint(#string END
Draw time: % ms
END,
/*
  Multiview World Render: % ms
  Lenticular Blit: % ms
  Editor World Render: % ms
  Editor UI: % ms
GPU frame time: % ms
END,
*/
        fmt(1000.0 * dTDrawTotal),
/*
        fmt(1000.0 * profiler.averaged_timings[profiler.Event.MultiviewWorldRender]),
        fmt(1000.0 * profiler.averaged_timings[profiler.Event.LenticularBlit]),
        fmt(1000.0 * profiler.averaged_timings[profiler.Event.EditorWorldRender]),
        fmt(1000.0 * profiler.averaged_timings[profiler.Event.EditorUI]),
        fmt(1000.0 * (dTDrawTotal + profiler.averaged_timings[profiler.Event.EndFrame]))
*/
    );
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
    set_global_renderer_ptr(*renderer);
    set_context_funcs();

    context.state.im_context.draw_callback = renderer_Im_Draw_Callback;

    setup_gamepad(host_state);

    _update_raylib_temp(host_state);
    game_base_did_reload_dll();
}

on_host_shutdown :: () {
    // TODO: the notion of some kind of "hard exit" so that we can do leak
    // tracking, but keep exiting fast when we don't care about the details.
    using context.state;
    shutdown_profiler(*profiler);
    game_base_shutdown();
    multiview_window.close();
}

setup_gamepad :: (host_state: Host_State) {
    Gamepad.init_gamepad();

    // this bit of trickery is to support live reloading with the host/game dll
    // split.  the gamepad module does a thing where it points one of its own
    // arrays into the .data of the input_button_states in the Input module.
    //
    // but Input.input_button_states is only valid for us in the host's memory,
    // so we attempt to only accesss it through host_state.input_button_states.
    assert(host_state.input_button_states != null);
    Gamepad.gamepad.buttons.data = *(<<host_state.input_button_states)[Key_Code.GAMEPAD_0_BEGIN];
}

on_host_init :: (host_state: Host_State) {
    using context.state;

    setup_gamepad(host_state);
    init(*renderer, host_state.window_handle, debug = GRAPHICS_LAYER_DEBUG);

    profiler_ok := init_profiler(*profiler);
    assert(profiler_ok);

    set_context_funcs();
    _update_raylib_temp(host_state);
    ui.d3dDevice = xx renderer.device;
    ui.d3dDeviceContext = xx renderer.device_context1;
    game_base_init(host_state);

    im_context.renderer = *renderer;
    im_init_renderer(*im_context);

    load_scene(1);

    multiview_framebuffer_size := framebuffer_size();

    device: *Looking_Glass_Device;
    borderless_lkg_window := true;
    if host_state.looking_glass_devices.count > 0 {
        device = *host_state.looking_glass_devices[0];
    } else {
        device = *fake_lkg_device;
        borderless_lkg_window = false;
    }

    multiview_framebuffer_size.x = cast(u16)device.width;
    multiview_framebuffer_size.y = cast(u16)device.height;
    multiview.device_params = <<device;
    multiview_window.create(main_renderer=*renderer, debug=GRAPHICS_LAYER_DEBUG,
        device.xpos, device.ypos, device.width, device.height, parent=host_state.window_handle,
        borderless=borderless_lkg_window);

    create_multiview_pass(multiview_framebuffer_size);

    // we tell the host about the extra window we created
    if mview_window.window != null
        array_add(*host_state.debug_extra_window_handles, mview_window.window);
}

fake_lkg_device :: Looking_Glass_Device.{
    xpos    = 20,
    ypos    = 20,
    width   = 384,
    height  = 512,
    pitch   = 246.945389,
    tilt    = -0.185653,
    center  = -0.122283,
    invView = 0,
    subp    = 0.000217,
    fringe  = 0,
    ri      = 0,
    bi      = 2,
};

set_context_funcs :: () {
    context.state.restart = restart;
    context.state.editor.callbacks.did_drag = editor_did_drag;

    set_debug_callback(on_renderer_debug_message);
}

on_renderer_debug_message :: (debug_message: Debug_Message) {
    log_mode: Log_Mode;
    if debug_message.severity == {
        case .Info;    log_mode = .EVERYDAY;
        case .Message; log_mode = .EVERYDAY;
        case;          log_mode = .MINIMAL;
    }

    logprint("renderer", log_mode, debug_message.text);
}

restart :: () {
    using context.state;
}

editor_did_drag :: (rect: rl.Rectangle) {
    using context.state;

    color := rl.RED;
    color.b = cast(u8)random_get_within_range(100, 255);
    block, block_h := envitem(*world,
        rect.x, rect.y, rect.width, rect.height,
        .PLATFORM, color, is_editor=true);

    Undo.push_array(*editor.undo_state, *editor.selected);
    set_selected(block_h);
    Undo.commit(*editor.undo_state);
}

handle_input_module_renderer_resize :: (window_handle: Window_Type, pending_resizes: *[..]Window_Resize_Record) {
    // The Jai input module queues up records for window resizes.
    // Here we resize the swapchain for the newest size.
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

envitem :: (world: *World, x: float, y: float, width: float, height: float, collision: Collision_Type, color: rl.Color, is_editor: bool = false) -> (*Entity, Entity_Handle) {
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

push_value :: (ptr_to_value: *$T, new_value: T) #expand {
    old_val := <<ptr_to_value;
    <<ptr_to_value = new_value;
    `defer <<ptr_to_value = old_val;
}

#import "renderer";
#import "renderer_im";
#import "renderer_im_impl";
#import "multiview";
#import "Hash";
#import "Math";
#import "Window_Creation";
Input   :: #import "Input";
Gamepad :: #import "Gamepad";
rl :: #import "raylib";
screenlog_draw :: #import "screenlog_draw";
multiview_window :: #import "multiview_window";
