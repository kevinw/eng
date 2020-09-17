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
GWP :: #import "gwpasan";
Plugin :: #import "plugin";
platform :: #import "platform";
screenlog :: #import "screenlog";
assets :: #import "assets";
#import "soloud";

panic :: (msg: string) {
    write_string(msg);
    debug_break();
}

cmdline_args: struct {
    topmost_window := true;
    live_reload := true;
    game_name := "game";
};

WINDOW_WIDTH :: 1200;
WINDOW_HEIGHT :: 675;
ALWAYS_ON_TOP :: true;
USE_SCREENLOG :: true;

#load "host_common.jai";

host_state: Host_State;

on_asset_change :: (using asset_change: *Asset_Change) {
    //print("change: % % % %\n", short_name, full_name, extension, time_of_last_change);
    if extension == "jai" && short_name != "host" && !String.begins_with(full_name, "./.") {
        arguments: [..]string;
        array_add(*arguments, "jai", "-x64", "first.jai", "--", cmdline_args.game_name);

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
    } else {
        // all other changes go to the plugin, which may want to live reload
        // textures, etc.
        if plugin_on_resource_change != null {
            plugin_on_resource_change(*plugin_context, asset_change);
        }
    }
}

host_settings: struct {
    window_pos_x: s32;
    window_pos_y: s32;
};

// plugin functions
Plugin_Init_Func        :: #type (ctx: *Context, old_value: *void, host_state: Host_State) #c_call;
Plugin_Deinit_Func      :: #type (ctx: *Context, shutting_down: bool) -> *void #c_call;
Plugin_Tick_Func        :: #type (ctx: *Context, host_state: Host_State) #c_call;
Plugin_On_Resource_Change_Func :: #type (ctx: *Context, change: *Asset_Change) #c_call;

plugin_init:        Plugin_Init_Func;
plugin_deinit:      Plugin_Deinit_Func;
plugin_tick:        Plugin_Tick_Func;
plugin_on_resource_change: Plugin_On_Resource_Change_Func;

update_plugin_functions :: (module: *Plugin.Module) {
    plugin_tick = cast(Plugin_Tick_Func)GetProcAddress(module.native_module, "plugin_tick");
    if !plugin_tick panic("Could not load plugin_tick func");

    plugin_init = cast(Plugin_Init_Func)GetProcAddress(module.native_module, "plugin_init");
    if !plugin_init panic("Could not load plugin_init func");

    plugin_deinit = cast(Plugin_Deinit_Func)GetProcAddress(module.native_module, "plugin_deinit");
    if !plugin_deinit panic("Could not load plugin_deinit func");

    plugin_on_resource_change = cast(Plugin_On_Resource_Change_Func)GetProcAddress(module.native_module, "plugin_on_resource_change");
    // ^optional
}

Math :: #import "Math";

plugin_context: Context;

main :: () {

    Debug.init();
    GWP.init();
    context.allocator = GWP.allocator;

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

    SetTraceLogLevel(.LOG_WARNING); // raylib
    //SetTraceLogLevel(.LOG_ALL); // raylib

    host_config_name :: "setup.cfg";

    parse_config_file(*host_settings, tprint("%/%", exe_path, host_config_name));
    win_x:= host_settings.window_pos_x;
    win_y:= host_settings.window_pos_y;

    assets.start_thread();
    defer assets.stop_thread();

    InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "");
    SetWindowPosition(win_x, win_y);
    defer CloseWindow();

    #if USE_SCREENLOG {
        context.logger_data = New(screenlog.Logger_State);
        context.logger = screenlog.context_func;
        defer free(context.logger_data);
    }

    InitAudioDevice();
    defer CloseAudioDevice();

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
    update_plugin_functions(*module);

    plugin_context = context;
    plugin_init(*plugin_context, null, host_state);
    defer {
        plugin_deinit(*plugin_context, shutting_down = true);
    }

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

            force_reload := IsKeyPressed(.KEY_R) && (IsKeyDown(.KEY_LEFT_SHIFT) || IsKeyDown(.KEY_RIGHT_SHIFT));

            if force_reload || (frame_count % 2 == 0 && Plugin.should_reload(*module)) {
                old_state := plugin_deinit(*plugin_context, shutting_down = false);

                if !Plugin.reload(*module, force_reload) // TODO: this calls file_modtime for a second time and doesn't need to.
                    panic("couldn't reload module");
                assert(module.native_module != null);

                update_plugin_functions(*module);
                assert(plugin_tick != null);

                plugin_init(*plugin_context, old_state, host_state);
            }
        }

        plugin_tick(*plugin_context, host_state);
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
