HOTLOADING_ENABLED :: true;

State_Base :: struct {
    check_canaries :: (state: *State_Base) {
        assert(state.canary1 == 9999, "State_Base canary check failed");
        assert(state.canary2 == 4000, "State_Base canary check failed");
        assert(state.canary3 == -99, "State_Base canary check failed");
    }

    canary1 := 9999;

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
    canary2 := 4000;
    restart: ();
    canary3 := -99;
}

game_base_shutdown :: () {
    using context.state;

    World.deinit(*world);
    sound_deinit(*sound_state);
}

game_base_update :: () {
    using context.state;

    ImGui_Impl_NewFrame(*ui, rl.GetWindowHandle(), rl.GetScreenWidth(), rl.GetScreenHeight());

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

    editor_update(context.state);
    screenlog.update(Time.delta_time);
    sound_update(*sound_state);

    if !editor.wants_keyboard {
        shift := rl.IsKeyDown(.KEY_LEFT_SHIFT) || rl.IsKeyDown(.KEY_RIGHT_SHIFT);
        if rl.IsKeyPressed(.KEY_TAB) || rl.IsGamepadButtonPressed(0, .GAMEPAD_BUTTON_MIDDLE_RIGHT)
            editor_toggle(context.state);
        if rl.IsKeyPressed(.KEY_R) && !shift && restart != null
            restart();
        if rl.IsKeyPressed(.KEY_MINUS)  change_global_time_scale(-1);
        if rl.IsKeyPressed(.KEY_EQUAL)  change_global_time_scale(+1);
        if rl.IsKeyPressed(.KEY_D) && shift {
            debug_draw = !debug_draw;
            logprint("=debug_draw", "debug_draw is now %\n", debug_draw);
        }
        if _local_host_state.change_window_state != null {
            if rl.IsKeyPressed(.KEY_F) || rl.IsGamepadButtonPressed(0, .GAMEPAD_BUTTON_MIDDLE_LEFT)
                _local_host_state.change_window_state(.Toggle_Borderless_Fullscreen);
            if rl.IsKeyPressed(.KEY_ZERO)
                _local_host_state.change_window_state(.Toggle_Always_On_Top);
            if rl.IsKeyPressed(.KEY_NINE)
                _local_host_state.change_window_state(.Toggle_Transparent_When_Out_Of_Focus);
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

game_base_push_drawing :: () #expand {
    rl.BeginDrawing();
    `defer {
        rl.rlglDraw();

        ImGui.Render();
        ok := ImGui_Impl_RenderDrawData(ui, ImGui.GetDrawData());
        assert(ok);

        screenlog.draw();
        host_debug_draw();
        rl.EndDrawing();
    }
    // TODO: @Speed the EndDrawing implied by PushDrawing is calling
    // rlglDraw() again, but rlglDraw() above ImGui.Render() is necessary
    // for us to be able to overlay IMGUI onto raylib
    // https://github.com/raysan5/raylib/issues/1216
}

game_base_draw_compile_error :: () {
    rect := rl.make_Rectangle(0, 0, rl.GetScreenWidth(), rl.GetScreenHeight());
    outline_width := cast(s32)(max(rl.GetScreenWidth(), rl.GetScreenHeight()) * 0.03);
    color := rl.make_Color(255, 40, 40, cast(u8)(255.0 * ((sin(rl.GetTime() * 5) + 1.0) / 4.0 + 0.3)));
    rl.DrawRectangleLinesEx(rect, outline_width, color);
}

game_base_init :: (host_state: Host_State) {
    using context.state;

    init_world(*world);
    imgui_init(*ui, host_state.window_handle);
    sound_init(*sound_state);
    editor_init(*editor);
}

game_base_did_reload_dll :: () {
    using context.state;

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

#scope_file

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
#load "host_common.jai";
}
#load "plugin_exports.jai";
#load "editor.jai";

