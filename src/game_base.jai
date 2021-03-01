UI_CFG_PATH :: "gui.cfg";

State_Base :: struct {
    check_canaries :: (state: *State_Base) {
        assert(state.canary1 == 9999, "State_Base canary check failed");
        assert(state.canary2 == 4000, "State_Base canary check failed");
        assert(state.canary3 == -99, "State_Base canary check failed");
    }

    canary1 := 9999;

    renderer:      Renderer;
    im_context:    Im_Context_R;
    multiview:     Multiview_State;
    mview_window:  multiview_window.State;

    physics_2d_state: Physics_2D_State;

    gameWidth  :: 640;
    gameHeight :: 360;
    ui: UI_State;
    _last_system_now: float64;
    Time: struct {
        now: float64;
        unscaled_now: float64;
        unscaled_delta_time: float;
        delta_time: float;
        frame_count: u64;
    };
    global_time_scale:float = 1.0;

    editor: Editor;
    sound_state: Sound_State;
    live: Live_Asset_Database;
    debug_draw := false;
    main_world: World;
    world: *World;

    // TODO: this is a hack until we have multiple swapchains, not multiple renderers
    all_renderers: [..]*Renderer;

    profiler_text: string;
    profiler:      Profiler(Profiler_Timestamps);
    first_update:    bool;

    current_im_camera: *Camera;
    current_im_holoplay_capture: *Holoplay_Capture;

    holoplay_capture: Holoplay_Capture;

    canary2 := 4000;
    canary3 := -99;
}

game_base_shutdown :: () {
    using context.state;

    { // save config
        sb: String_Builder;
        sb.allocator = __temporary_allocator;
        config.to_builder(*sb, *ui.config);
        File.write_entire_file(UI_CFG_PATH, builder_to_string(*sb, __temporary_allocator));
    }

    // TODO: the notion of some kind of "hard exit" so that we can do leak
    // tracking, but keep exiting fast when we don't care about the details.
    shutdown_profiler(*profiler);
    world_deinit(world);
    sound_deinit(*sound_state);
    multiview_window.close();
}

game_base_update :: (host_state: Host_State) {
    using context.state;

    if !first_update {
        first_update = true;
        log("first update at %", formatFloat(host_state.time, trailing_width=6, width=6));
    }

    Gamepad.update_gamepad();
    handle_input_module_renderer_resize(host_state.window_handle, host_state.pending_resizes);
    ImGui_Impl_ProcessInputEvents(*ui, host_state.events_this_frame);

    ImGui_Impl_NewFrame(*ui, host_state.window_handle, rl.GetScreenWidth(), rl.GetScreenHeight());

    system_now := get_time();
    absolute_delta_time: float64;
    if _last_system_now > 0 absolute_delta_time = system_now - _last_system_now;
    if absolute_delta_time < 0 absolute_delta_time = 0;
    _last_system_now = system_now;

    {
        // update the context's Time struct
        Time.delta_time = cast(float)(global_time_scale * absolute_delta_time);
        Time.unscaled_delta_time = cast(float)absolute_delta_time;
        Time.now += Time.delta_time;
        Time.unscaled_now = system_now;
        Time.frame_count += 1;
    }

    {
        push_renderer_context(*context.state.renderer, "main monitor");
        editor_update(context.state);
        screenlog.update(Time.delta_time);
    }
    sound_update(*sound_state);

    if !editor.wants_keyboard {
        shift := rl.IsKeyDown(.KEY_LEFT_SHIFT) || rl.IsKeyDown(.KEY_RIGHT_SHIFT);
        ctrl := is_key_down(.CTRL);
        if rl.IsKeyPressed(.KEY_TAB) || rl.IsGamepadButtonPressed(0, .GAMEPAD_BUTTON_MIDDLE_RIGHT)
            editor_toggle(context.state);
        if is_key_pressed(#char "-") {
            if ctrl ui_change_scale(*ui, -1);
            else change_global_time_scale(-1);
        }
        if is_key_pressed(#char "+") {
            if ctrl ui_change_scale(*ui, +1);
            else change_global_time_scale(+1);
        }
        if rl.IsKeyPressed(.KEY_D) && shift {
            debug_draw = !debug_draw;
            log("debug_draw is now %\n", debug_draw);
        }

        change_window_state := _local_host_state.change_window_state;
        if change_window_state != null {
            if rl.IsKeyPressed(.KEY_F) || rl.IsGamepadButtonPressed(0, .GAMEPAD_BUTTON_MIDDLE_LEFT)
                                          change_window_state(.Toggle_Borderless_Fullscreen);
            if rl.IsKeyPressed(.KEY_ZERO) change_window_state(.Toggle_Always_On_Top);
            if rl.IsKeyPressed(.KEY_NINE) change_window_state(.Toggle_Transparent_When_Out_Of_Focus);
            if rl.IsKeyPressed(.KEY_R)    change_window_state(.Force_Plugin_DLL_Reload);
        }
    }

    check_canaries(context.state);
    world_update(world, Time.delta_time);
}

change_global_time_scale :: (delta: float) {
    using context.state;

    STEP :: 0.2;

    global_time_scale = clamp(global_time_scale + delta * STEP, 0.1, 4.0);
    if Sloppy_Math.values_are_close(global_time_scale, 1.0)
        global_time_scale = 1;

    log("time scale %", global_time_scale);
}

game_base_draw_compile_error :: () {
    rect := rl.make_Rectangle(0, 0, rl.GetScreenWidth(), rl.GetScreenHeight());
    outline_width := cast(s32)(max(rl.GetScreenWidth(), rl.GetScreenHeight()) * 0.03);
    color := rl.make_Color(255, 40, 40, cast(u8)(255.0 * ((sin(rl.GetTime() * 5) + 1.0) / 4.0 + 0.3)));
    rl.DrawRectangleLinesEx(rect, outline_width, color);
}

game_base_default_multiview_update_and_draw :: (host_state: Host_State) {
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

game_base_init :: (host_state: Host_State) {
    using context.state;

    init_synchronization :: () -> *void #runtime_support;
    init_synchronization();

    world = *main_world;

    init(*renderer, host_state.window_handle, debug = GRAPHICS_LAYER_DEBUG);
    array_add(*all_renderers, *renderer);

    profiler_ok := init_profiler(*profiler);
    assert(profiler_ok);

    setup_gamepad(host_state);
    config.parse(*ui.config, UI_CFG_PATH);

    _update_raylib_temp(host_state);
    ui.d3dDevice = xx renderer.device;
    ui.d3dDeviceContext = xx renderer.device_context1;

    world_init(world);
    imgui_init(*ui, host_state.window_handle);
    sound_init(*sound_state);
    editor_init(*editor);

    im_context.renderer = *renderer;
    im_init_renderer(*im_context, index_elements=4000*6, vertex_elements=4000*6, draw_elements=128);

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

game_base_did_reload_dll :: (host_state: Host_State) {
    using context.state;

    context.state.check_canaries(context.state);
    set_global_renderer_ptr(*renderer);
    context.state.im_context.draw_callback = renderer_Im_Draw_Callback;
    setup_gamepad(host_state);
    _update_raylib_temp(host_state);

    _SetImGuiAllocators();
    ui.Time = 0; // get_time() will return 0 when the DLL reloads...so this is to prevent a negative delta time
    ImGui_Impl_DidReloadDLL(*ui);

    assert(ui.ctx != null);
    ImGui.SetCurrentContext(ui.ctx);
    {
        // The DLL initializes these by default to strings in its data segment,
        // so when we reload we get a crash unless we make them valid again.
        // note that they can be set to null to indicate that you want to
        // handle saving/loading yourself; see the docs.
        io := ImGui.GetIO();
        io.IniFilename = "imgui.ini";
        io.LogFilename = "imgui_log.txt";
    }

    log("game dll reloaded at % secs", cast(int)rl.GetTime());
}

setup_gamepad :: (host_state: Host_State) {
    Gamepad.init_gamepad();

    // This bit of trickery is to support live reloading with the host/game dll
    // split.  the gamepad module does a thing where it points one of its own
    // arrays into the .data of the input_button_states in the Input module.
    //
    // but Input.input_button_states is only valid for us in the host's memory,
    // so we attempt to only accesss it through host_state.input_button_states.
    assert(host_state.input_button_states != null);
    Gamepad.gamepad.buttons.data = *(<<host_state.input_button_states)[Key_Code.GAMEPAD_0_BEGIN];
}


game_base_set_function_pointers :: () {
    set_debug_callback(on_renderer_debug_message);
}

#scope_file

Profiler_Timestamps :: enum {
	BeginFrame;

    MultiviewWorldRender;
    LenticularBlit;

    EditorWorldRender;
    EditorUI;

	EndFrame;
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



_update_raylib_temp :: (host_state: Host_State) {
    using context.state;

    // These go away once we remove the fake raylib module entirely.
    rl._XXX_SetRenderer(*renderer);
    rl._XXX_SetHostInputButtonStates(host_state.input_button_states);
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


_draw_world :: () {
    ctx := *context.state.im_context;

    push_blend(ctx, blend=false, flush=false);

    im_set_z(ctx, 0);
    im_flush(ctx);

    world := context.state.world;
    world_draw(world);
    im_flush(ctx);
}


on_renderer_debug_message :: (debug_message: Debug_Message) {
    log_flags: Log_Flags;
    if debug_message.severity == {
        case .Info;    log_flags = .NONE;
        case .Message; log_flags = .NONE;
        case;          log_flags = .ERROR;
    }

    log("renderer %", debug_message.text, flags=log_flags);
}


Physics_2D_State :: struct {
    space: *cp.Space;
}
is_key_down       :: (ch: u8)        -> bool { return is_key_down(cast,trunc(Key_Code)ch); }
is_key_down       :: (key: Key_Code) -> bool { return (<<_local_host_state.input_button_states)[cast(int)key] & .DOWN != 0; }
is_key_pressed    :: (ch: u8) -> bool { return is_key_pressed(cast,trunc(Key_Code)ch); }
is_key_pressed    :: (key: Key_Code) -> bool {
    return (<<_local_host_state.input_button_states)[cast(int)key] & .START != 0;
}

push_value :: (ptr_to_value: *$T, new_value: T) #expand {
    old_val := <<ptr_to_value;
    <<ptr_to_value = new_value;
    `defer <<ptr_to_value = old_val;
}


#import "entity";

rl :: #import "raylib";
cp :: #import "Chipmunk";
#import "Basic";
#import "raymath";
#import "toolbelt";
#import "multiview";
#import "renderer_im";
screenlog :: #import "screenlog";
inp :: #import "inp";
#import "live_raylib";
Sloppy_Math :: #import "Sloppy_Math";
#import "Live_Types";
#import "game_sound_soloud";

#load "../lib/ui.jai";
#if BUILDING_DLLS {
#import "host_common";
}
Gamepad :: #import "Gamepad";
#load "plugin_exports.jai";
#load "editor.jai";
File :: #import "File";
config :: #import "config";

multiview_window :: #import "multiview_window";
