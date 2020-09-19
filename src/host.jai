#import "Basic";
#import "raylib";
#import "Windows";
#import "Hotloader";
#import "String";
#import "config";
#import "Process";
#import "System";
#import "toolbelt";
File :: #import "File";
String :: #import "String";
Debug :: #import "Debug";
Plugin :: #import "plugin";
platform :: #import "platform";
screenlog :: #import "screenlog";
//assets :: #import "assets";
#import "soloud";

cmdline_args: struct {
    topmost_window := true;
    live_reload := true;
    game_name := "game";
};

GUARD_ALLOCATOR :: true;

WINDOW_WIDTH :: 1200;
WINDOW_HEIGHT :: 675;
ALWAYS_ON_TOP :: true;

#add_context state: *void;
#load "host_common.jai";

host_state: Host_State;
needs_recompile_timer:float = 0;
reload_new_dll_filename: string;
needs_complete_reload := false;
_recompile_thread: *Thread;
host_settings: struct {
    window_pos_x: s32;
    window_pos_y: s32;
};
all_games := string.[
    "game.dll",
    "pong.dll"
];


//
// plugin functions
//
Plugin_Init_Func               :: #type (old_value: *void, host_state: Host_State);
Plugin_Deinit_Func             :: #type (shutting_down: bool) -> *void;
Plugin_Tick_Func               :: #type (host_state: Host_State);
Plugin_On_Resource_Change_Func :: #type (change: *Asset_Change);
Plugin_Sanity_Checks_Func      :: #type (sanity_check_info: Sanity_Check_Info);

plugin_init:        Plugin_Init_Func;
plugin_deinit:      Plugin_Deinit_Func;
plugin_tick:        Plugin_Tick_Func;
plugin_on_resource_change: Plugin_On_Resource_Change_Func;
plugin_sanity_checks: Plugin_Sanity_Checks_Func;

do_recompile :: () {
    _recompile_thread := thread_create(_do_recompile);
    thread_start(_recompile_thread);
}

_do_recompile :: (t: *Thread) -> s64 {
    defer _recompile_thread = null;

    arguments: [..]string;
    array_add(*arguments, "jai", "-x64", "first.jai", "--", "reload", cmdline_args.game_name);

    cmd_string := concatenate(..arguments, " ");
    defer free(cmd_string);
    print("Running jai compiler: %\n", cmd_string);

    success, exit_code, output_string, error_string := os_run_command(..arguments, capture_and_return_output=true);

    if !success {
        print("success: %\n");
        print("exit code: %\n", exit_code);
        print("output_string: %\n", output_string);
        print("error string: %\n", error_string);
    } else {
        // HACK: the jai compiler is not returning an error value on the console??
        if String.contains(output_string, " Error: ") {
            success = false;
        }

        print("%", output_string);
        if error_string && error_string.count {
            print("[stderr] %", error_string);
        }
    }
    host_state.jai_compiler_did_error = !success;

    return ifx success 0 else -1;
}

on_asset_change :: (using asset_change: *Asset_Change) {
    //print("%\n", <<asset_change);
    //print("change: % % % %\n", short_name, full_name, extension, time_of_last_change);
    if extension == "jai" && short_name != "host" && !String.begins_with(full_name, "./.") {
        #import "Thread";
        do_recompile();
    } else if extension == "dll" && begins_with(short_name, tprint("%_reloaded_", cmdline_args.game_name)) {
        reload_new_dll_filename = full_name;
        if begins_with(reload_new_dll_filename, "./")
            advance(*reload_new_dll_filename, 2);
        reload_new_dll_filename = copy_string(reload_new_dll_filename);
    } else {
        // all other changes go to the plugin, which may want to live reload
        // textures, etc.
        if plugin_on_resource_change != null
            plugin_on_resource_change(asset_change);
    }
}

get_func_ptrs_from_dll :: (module: *Plugin.Module) {
    // these functions are implemented plugin-side in plugin_exports.jai

    // required functions

    plugin_tick = cast(Plugin_Tick_Func)GetProcAddress(module.native_module, "plugin_tick");
    if !plugin_tick panic("Could not load plugin_tick func");

    plugin_init = cast(Plugin_Init_Func)GetProcAddress(module.native_module, "plugin_init");
    if !plugin_init panic("Could not load plugin_init func");

    plugin_deinit = cast(Plugin_Deinit_Func)GetProcAddress(module.native_module, "plugin_deinit");
    if !plugin_deinit panic("Could not load plugin_deinit func");

    plugin_sanity_checks = cast(Plugin_Sanity_Checks_Func)GetProcAddress(module.native_module, "plugin_sanity_checks");
    if !plugin_sanity_checks panic("Could not load plugin_sanity_checks func");

    // optional

    plugin_on_resource_change = cast(Plugin_On_Resource_Change_Func)GetProcAddress(module.native_module, "plugin_on_resource_change");
    // ^optional

}

panic :: (msg: string) {
    write_string(msg);
    debug_break();
}

main :: () {
    Debug.init();
    if GUARD_ALLOCATOR {
        GWP :: #import "gwpasan";
        print("[Perf] Using slow guard allocator.\n");
        GWP.init(max_allocation = 100000, sample_rate = 1);
        context.allocator = GWP.allocator;
    }

    found, exe_path, exe_name := split_by_character_from_right(get_path_of_running_executable(), #char "/");
    if !found {
        print("Error: unable to find my own exe\n");
        return;
    }

    {
        args := get_command_line_arguments();
        defer array_free(args);

        did_set_plugin_dll := false;
        for args {
            if it == {
                case "--no-topmost";
                    print("skipping topmost window\n");
                    cmdline_args.topmost_window = false;
                case "--no-live-reload";
                    print("no live reload\n");
                    cmdline_args.live_reload = false;
                case;
                    if it_index > 0 {
                        if did_set_plugin_dll {
                            print("error: more than one dll argument specified.\n");
                            exit(1);
                        }

                        cmdline_args.game_name = copy_string(it);
                        did_set_plugin_dll = true;
                    }
                    
            }
        }
    }

    game_index := 0;
    {
        found_game_name, idx := array_find(all_games, cmdline_args.game_name);
        if found_game_name
            game_index = idx;
    }

    SetTraceLogLevel(.LOG_WARNING); // raylib (.LOG_ALL for everything)

    host_config_name :: "setup.cfg";
    parse_config_file(*host_settings, tprint("%/%", exe_path, host_config_name));
    win_x:= host_settings.window_pos_x;
    win_y:= host_settings.window_pos_y;

    //assets.start_thread();
    //defer assets.stop_thread();

    InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "");
    SetWindowPosition(win_x, win_y);
    defer CloseWindow();

    context.logger_data = New(screenlog.Logger_State);
    context.logger = screenlog.context_func;
    defer free(context.logger_data);

    #if ALWAYS_ON_TOP
        if cmdline_args.topmost_window
            platform.set_window_always_on_top(GetWindowHandle());

    if cmdline_args.live_reload {
        hotloader_init(".", _DEBUG_LOGGING=false);
        hotloader_register_callback(on_asset_change);
    }
    defer if cmdline_args.live_reload hotloader_shutdown();

    module: Plugin.Module;

    plugin_dll_filename := copy_string_z(tprint("%.dll", cmdline_args.game_name));

    soloud := Soloud_create();
    assert(soloud != null);
    Soloud_init(soloud, SOLOUD_CLIP_ROUNDOFF);
    defer {
        Soloud_deinit(soloud);
        Soloud_destroy(soloud);
    }
    host_state.soloud_context = soloud;

    if !Plugin.load(*module, plugin_dll_filename, COPY_TO_TEMP_PATH = cmdline_args.live_reload)
        panic(tprint("Could not load DLL '%'\n", plugin_dll_filename));
    defer Plugin.unload(*module);
    get_func_ptrs_from_dll(*module);

    plugin_sanity_checks(Sanity_Check_Info.{size_of_context = size_of(Context)});
    plugin_init(null, host_state);
    assert(context.state != null, "plugin_init did not allocate a state");
    defer plugin_deinit(shutting_down = true);

    native_window_handle := GetWindowHandle();
    window_was_active := platform.is_window_active(native_window_handle);

    SetTargetFPS(60);
    frame_count := 0;

    while !WindowShouldClose() {
        auto_release_temp();
        frame_count += 1;

        // Set the window to be a little transparent when it's not in focus, if we're always on top.
        {
            win_active := platform.is_window_active(native_window_handle);
            if !win_active && window_was_active && platform.is_window_always_on_top(native_window_handle)
                platform.set_window_opacity(native_window_handle, 0.63);
            else if win_active && !window_was_active
                platform.set_window_opacity(native_window_handle, 1.0);
            window_was_active = win_active;
        }


        if IsKeyPressed(.KEY_ZERO) {
            top := platform.toggle_always_on_top(native_window_handle);
            logprint("host", ifx top then "window always on top" else "window not topmost");
        }

        if cmdline_args.live_reload {
            if frame_count % 4 == 0 hotloader_process_change();

            recompile_requested := IsKeyPressed(.KEY_R) && (IsKeyDown(.KEY_LEFT_SHIFT) || IsKeyDown(.KEY_RIGHT_SHIFT));
            if recompile_requested {
                do_recompile();
            }

            game_delta := 0;
            if IsKeyPressed(.KEY_LEFT_BRACKET) game_delta -= 1;
            if IsKeyPressed(.KEY_RIGHT_BRACKET) game_delta += 1;
            if game_delta != 0 {
                game_index += game_delta;
                if game_index < 0 game_index = all_games.count - 1;
                if game_index >= all_games.count game_index = 0;
                reload_new_dll_filename = all_games[game_index];
                logprint("game switch", "loading new game from '%'", reload_new_dll_filename);
                needs_complete_reload = true;
            }

            if _recompile_thread == null && frame_count % 2 == 0 && (Plugin.should_reload(*module) || reload_new_dll_filename.count > 0) {
                old_state := plugin_deinit(shutting_down = false);

                force_reload := false;
                if reload_new_dll_filename.count > 0 {
                    force_reload = true;
                    module.filename = reload_new_dll_filename; // @Leak
                    reload_new_dll_filename.count = 0; // @Leak?
                }
                if !Plugin.reload(*module, force_reload) // TODO: this calls file_modtime for a second time and doesn't need to.
                    panic("couldn't reload module");
                assert(module.native_module != null);

                get_func_ptrs_from_dll(*module);

                plugin_sanity_checks(.{size_of_context = size_of(Context)});

                if needs_complete_reload {
                    // when switching games, we deallocate the old game state
                    // and pass a null pointer to plugin_init, which indicates
                    // that it should start from scratch
                    needs_complete_reload = true;
                    free(old_state);
                    old_state = null;
                }

                plugin_init(old_state, host_state);
            }
        }

        plugin_tick(host_state);
    }

    if !IsWindowFullscreen() && !platform.is_window_borderless(native_window_handle) {
        builder: String_Builder;
        defer free_buffers(*builder);

        append(*builder, "[1]\n\n");
        pos := GetWindowPosition();
        print_to_builder(*builder, "window_pos_x %\nwindow_pos_y %\n", cast(s32)pos.x, cast(s32)pos.y);

        output := builder_to_string(*builder);
        defer free(output);
        File.write_entire_file(host_config_name, output);
    }
}
