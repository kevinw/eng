#import "Basic";
#import "raylib";
#import "raymath";
#import "toolbelt";
screenlog :: #import "screenlog";
inp :: #import "inp";
#import "live_raylib";
Sloppy_Math :: #import "Sloppy_Math";
#import "Live_Types";
#import "entity"(GAME_NAME);
#import "game_sound_soloud";

#load "../lib/ui.jai";
#load "plugin_exports.jai";
#load "editor.jai";

HOTLOADING_ENABLED :: true;

#add_context state: *State;

State_Base :: struct {
    check_canaries :: (state: *State_Base) {
        assert(state.canary1 == 9999, "State_Base canary check failed");
        assert(state.canary2 == 4000, "State_Base canary check failed");
        assert(state.canary3 == -99, "State_Base canary check failed");
    }

    canary1 := 9999;

    gameWidth  :: 640;
    gameHeight :: 360;
    ui: UI_State;
    Time: struct {
        now: float64;
        unscaled_now: float64;
        unscaled_delta_time: float;
        delta_time: float;
        frame_count: u64;
    };
    global_time_scale:float = 1.0;

    // TODO: this is a kind of weird inversion of control. other files we import
    // provide the structs that we use here. is that badly designed, or using a
    // jai feature in a way that is actually fine?

    editor: Editor;
    sound_state: Sound_State;
    live: Live_Asset_Database;
    debug_draw := false;
    world: World;
    canary2 := 4000;

    screen: struct {
        shader: Shader;
        texture: RenderTexture;
    };

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

    imgui_raylib_new_frame(*ui);

    absolute_delta_time := GetFrameTime();

    {
        // update the context's Time struct
        Time.delta_time = global_time_scale * absolute_delta_time;
        Time.unscaled_delta_time = absolute_delta_time;
        Time.now += Time.delta_time;
        Time.unscaled_now = GetTime();
        Time.frame_count += 1;
    }

    editor_update(context.state);
    screenlog.update(Time.delta_time);
    sound_update(*sound_state);

    if !editor.wants_keyboard {
        shift := IsKeyDown(.KEY_LEFT_SHIFT) || IsKeyDown(.KEY_RIGHT_SHIFT);
        if IsKeyPressed(.KEY_TAB) || IsGamepadButtonPressed(0, .GAMEPAD_BUTTON_MIDDLE_RIGHT)
            editor_toggle(context.state);
        if IsKeyPressed(.KEY_R) && !shift && restart != null restart();
        if IsKeyPressed(.KEY_MINUS) change_global_time_scale(-1);
        if IsKeyPressed(.KEY_EQUAL)  change_global_time_scale(+1);
        if IsKeyPressed(.KEY_D) && shift {
            debug_draw = !debug_draw;
            logprint("=debug_draw", "debug_draw is now %\n", debug_draw);
        }
        if IsKeyPressed(.KEY_F) || IsGamepadButtonPressed(0, .GAMEPAD_BUTTON_MIDDLE_LEFT) {
            USE_REAL_FULLSCREEN :: false;
            if USE_REAL_FULLSCREEN {
                ToggleFullscreen();
            } else {
                ToggleFakeFullscreen();
            }
        }
    }

    context.state.check_canaries(context.state);
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
    BeginDrawing();
    `defer {
        rlglDraw();
        imgui_render(*context.state.ui);
        screenlog.draw();
        host_debug_draw();
        EndDrawing();
    }
    // TODO: @Speed the EndDrawing implied by PushDrawing is calling
    // rlglDraw() again, but rlglDraw() above ImGui.Render() is necessary
    // for us to be able to overlay IMGUI onto raylib
    // https://github.com/raysan5/raylib/issues/1216
}

game_base_init :: () {
    using context.state;
    init_world(*world);
    imgui_init(*ui);
    sound_init(*sound_state);
    editor_init(*editor);
}

game_base_did_reload_dll :: () {
    ImGui_Impl_DLL_Was_Reloaded(*context.state.ui);
    logprint("game", "game dll reloaded at % secs", cast(int)GetTime());
}
