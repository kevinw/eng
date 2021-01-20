HOTLOADING_ENABLED :: true;

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
    world: World;

    // TODO: this is a hack until we have multiple swapchains, not multiple renderers
    all_renderers: [..]*Renderer;

    profiler_text: string;
    profiler:      Profiler(Profiler_Timestamps);
    first_update:    bool;

    canary2 := 4000;
    canary3 := -99;
}

game_base_shutdown :: () {
    using context.state;

    // TODO: the notion of some kind of "hard exit" so that we can do leak
    // tracking, but keep exiting fast when we don't care about the details.
    shutdown_profiler(*profiler);
    World.deinit(*world);
    sound_deinit(*sound_state);
    multiview_window.close();
}

game_base_update :: (host_state: Host_State) {
    using context.state;

    if !first_update {
        first_update = true;
        logprint("game", "first update at %", formatFloat(host_state.time, trailing_width=6, width=6));
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
        if rl.IsKeyPressed(.KEY_TAB) || rl.IsGamepadButtonPressed(0, .GAMEPAD_BUTTON_MIDDLE_RIGHT)
            editor_toggle(context.state);
        if rl.IsKeyPressed(.KEY_MINUS) change_global_time_scale(-1);
        if rl.IsKeyPressed(.KEY_EQUAL) change_global_time_scale(+1);
        if rl.IsKeyPressed(.KEY_D) && shift {
            debug_draw = !debug_draw;
            logprint("=debug_draw", "debug_draw is now %\n", debug_draw);
        }
        if _local_host_state.change_window_state != null {
            if rl.IsKeyPressed(.KEY_F) || rl.IsGamepadButtonPressed(0, .GAMEPAD_BUTTON_MIDDLE_LEFT)
                _local_host_state.change_window_state(.Toggle_Borderless_Fullscreen);
            if rl.IsKeyPressed(.KEY_ZERO) _local_host_state.change_window_state(.Toggle_Always_On_Top);
            if rl.IsKeyPressed(.KEY_NINE) _local_host_state.change_window_state(.Toggle_Transparent_When_Out_Of_Focus);
        }
    }

    check_canaries(context.state);
    world_update(*world, Time.delta_time);
}

change_global_time_scale :: (delta: float) {
    using context.state;

    STEP :: 0.2;

    global_time_scale = clamp(global_time_scale + delta * STEP, 0.1, 4.0);
    if Sloppy_Math.values_are_close(global_time_scale, 1.0)
        global_time_scale = 1;

    logprint("=time_scale", "time scale %", global_time_scale);
}

game_base_draw_compile_error :: () {
    rect := rl.make_Rectangle(0, 0, rl.GetScreenWidth(), rl.GetScreenHeight());
    outline_width := cast(s32)(max(rl.GetScreenWidth(), rl.GetScreenHeight()) * 0.03);
    color := rl.make_Color(255, 40, 40, cast(u8)(255.0 * ((sin(rl.GetTime() * 5) + 1.0) / 4.0 + 0.3)));
    rl.DrawRectangleLinesEx(rect, outline_width, color);
}

game_base_init :: (host_state: Host_State) {
    using context.state;

    profiler_ok := init_profiler(*profiler);
    assert(profiler_ok);

    setup_gamepad(host_state);

    _update_raylib_temp(host_state);
    ui.d3dDevice = xx renderer.device;
    ui.d3dDeviceContext = xx renderer.device_context1;

    init_world(*world);
    imgui_init(*ui, host_state.window_handle);
    sound_init(*sound_state);
    editor_init(*editor);
}

game_base_did_reload_dll :: (host_state: Host_State) {
    using context.state;

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

    logprint("game", "game dll reloaded at % secs", cast(int)rl.GetTime());
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


on_renderer_debug_message :: (debug_message: Debug_Message) {
    log_mode: Log_Mode;
    if debug_message.severity == {
        case .Info;    log_mode = .EVERYDAY;
        case .Message; log_mode = .EVERYDAY;
        case;          log_mode = .MINIMAL;
    }

    logprint("renderer", log_mode, debug_message.text);
}


Physics_2D_State :: struct {
    space: *cp.Space;
}

#import "entity";

rl :: #import "raylib";
cp :: #import "Chipmunk";
#import "Basic";
#import "raymath";
#import "toolbelt";
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

multiview_window :: #import "multiview_window";
