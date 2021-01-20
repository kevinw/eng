#load "game_base.jai";

PARTICLES :: true;

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

    current_im_camera: *Camera;
    current_im_holoplay_capture: *Holoplay_Capture;

    holoplay_capture: Holoplay_Capture;
}

is_key_down       :: (ch: u8) -> bool { return (<<_local_host_state.input_button_states)[cast(int)ch] & .DOWN != 0; }
is_key_pressed    :: (ch: u8) -> bool { return is_key_pressed(cast,trunc(Key_Code)ch); }
is_key_pressed    :: (key: Key_Code) -> bool {
    return (<<_local_host_state.input_button_states)[cast(int)key] & .START != 0;
}

_draw_world :: () {
    ctx := *context.state.im_context;

    push_blend(ctx, blend=false, flush=false);

    im_set_z(ctx, 0);
    im_flush(ctx);

    world := context.state.world;
    world_draw(*world);
    im_flush(ctx);
}

update_and_draw :: (host_state: Host_State) {
    using context.state;

    set_context(*renderer);

    game_base_update(host_state);

    begin_frame(*profiler);

    // draw the main window
    im := *im_context;

    // looking glass window
    if mview_window.window != null {
        push_renderer_context(*mview_window.mview_renderer, "lkg display");

        cam: *Camera;
        game_camera := get_main_camera();
        if game_camera == null || is_key_down(#char "K") {
            cam = *context.state.editor.scene_camera;
        } else {
            cam = *game_camera.camera;
        }

        push_value(*current_im_camera, cam);
        push_value(*current_im_holoplay_capture, *context.state.holoplay_capture);
        {
            // render quilt
            push_pass(*multiview.offscreen.pass, clear_color=*Vector4.{0, 0, 0, 0});
            _draw_world();
            timestamp(*profiler, .MultiviewWorldRender);
        }

        begin_default_pass(clear_color=*Vector4.{0.0, 0, 0.0, 1});
        draw_lenticular_lightfield_to_backbuffer();
        end_pass();
        present();
        timestamp(*profiler, .LenticularBlit);
    } else {
        timestamp(*profiler, .MultiviewWorldRender);
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
                push_value(*im.track_mouse, true);
                _draw_world();
                timestamp(*profiler, .EditorWorldRender);
            }

            im_set_texture(im, null);
            wait_for_data_and_update(*profiler);
            update_profiler_text();
            editor_draw(context.state);
            im_flush(im);

            physics_2d_draw_debug();
            editor_draw_world(context.state);
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

    init(*renderer, host_state.window_handle, debug = GRAPHICS_LAYER_DEBUG);
    array_add(*all_renderers, *renderer);

    set_function_pointers();
    game_base_init(host_state);

    im_context.renderer = *renderer;
    im_init_renderer(*im_context, index_elements=4000*6, vertex_elements=4000*6, draw_elements=128);

    load_scene(1);

    multiview_framebuffer_size := framebuffer_size();

    device: *Looking_Glass_Device;
    device_present := false;
    borderless_lkg_window := true;
    if host_state.looking_glass_devices.count > 0 {
        device = *host_state.looking_glass_devices[0];
        device_present = true;
    } else {
        device = *fake_lkg_device;
        borderless_lkg_window = false;
    }

    if host_state.game_window_flags & .Show_Multiview {
        if device_present || host_state.game_window_flags & .Show_Multiview_Even_If_No_Device {
            multiview_framebuffer_size.x = cast(u16)device.width;
            multiview_framebuffer_size.y = cast(u16)device.height;
            multiview.device_params = <<device;
            print("%\n", device);
            multiview_window.create(main_renderer=*renderer, debug=GRAPHICS_LAYER_DEBUG,
                device.xpos, device.ypos, device.width, device.height, parent=host_state.window_handle,
                borderless=borderless_lkg_window);

            create_multiview_pass(multiview_framebuffer_size);

            // we tell the host about the extra window we created
            if mview_window.window != null
                array_add(*host_state.debug_extra_window_handles, mview_window.window);
        }
    }

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
    view_cone = 40,
};


set_function_pointers :: () {
    logprint("d3d_game", "setting editor_did_drag");
    context.state.editor.callbacks.did_drag = editor_did_drag;
    game_base_set_function_pointers();
}

#scope_file

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
Sort :: #import "Sort";
rl :: #import "raylib";
multiview_window :: #import "multiview_window";
