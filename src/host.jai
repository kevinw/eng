#import "Basic";
#import "raylib";
#import "Windows";
#import "Hotloader";
#import "String";
#import "config";
#import "Process";
#import "System";
#import "Sound_Player";
#import "soloud";
File :: #import "File";
String :: #import "String";
Debug :: #import "Debug";
GWP :: #import "gwpasan";
Plugin :: #import "plugin";
platform :: #import "platform";
screenlog :: #import "screenlog";

panic :: (msg: string) {
    write_string(msg);
    debug_break();
}

WINDOW_WIDTH :: 1200;
WINDOW_HEIGHT :: 675;
ALWAYS_ON_TOP :: true;
USE_SCREENLOG :: true;

cmdline_args: struct {
    topmost_window := true;
    live_reload := true;
};

on_asset_change :: (using asset_change: *Asset_Change) {
    //print("change: % % % %\n", short_name, full_name, extension, time_of_last_change);
    if extension == "jai" && short_name != "host" && !String.begins_with(full_name, "./.") {
        arguments: [..]string;
        array_add(*arguments, "jai", "-x64", "first.jai");

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
            print("%", output_string);
            if error_string && error_string.count {
                print("[stderr] %", error_string);
            }
        }
    } else {
        // all other changes go to the plugin, which may want to live reload
        // textures, etc.
        if plugin_on_resource_change != null {
            ctx := context;
            plugin_on_resource_change(*ctx, asset_change);
        }
    }
}

host_settings: struct {
    window_pos_x: s32;
    window_pos_y: s32;
};

// plugin functions
Plugin_Init_Func        :: #type (ctx: *Context, old_value: *void) #c_call;
Plugin_Deinit_Func      :: #type (ctx: *Context, shutting_down: bool) -> *void #c_call;
Plugin_Tick_Func        :: #type (ctx: *Context) #c_call;
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

wbml :: #import "wbml";
Math :: #import "Math";

main :: () {
    main_game();
}

main_game :: () {
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

        for args {
            if it == {
                case "--no-topmost";
                    print("skipping topmost window\n");
                    cmdline_args.topmost_window = false;
                case "--no-live-reload";
                    print("no live reload\n");
                    cmdline_args.live_reload = false;
            }
        }
    }

    SetTraceLogLevel(.LOG_WARNING); // raylib

    host_config_name :: "setup.cfg";

    parse_config_file(*host_settings, tprint("%/%", exe_path, host_config_name));
    win_x:= host_settings.window_pos_x;
    win_y:= host_settings.window_pos_y;

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
            platform.SetWindowAlwaysOnTop(GetWindowHandle());

    if cmdline_args.live_reload {
        hotloader_init(".", _DEBUG_LOGGING=false);
        hotloader_register_callback(on_asset_change);
    }
    defer if cmdline_args.live_reload hotloader_shutdown();

    module: Plugin.Module;
    if !Plugin.load(*module, "game.dll", COPY_TO_TEMP_PATH = cmdline_args.live_reload)
        panic("Could not load game.dll\n");
    defer Plugin.unload(*module);
    update_plugin_functions(*module);


    plugin_context := context;

    plugin_init(*plugin_context, null);
    defer {
        ctx := context;
        plugin_deinit(*ctx, shutting_down = true);
    }

    SetTargetFPS(60);
    frame_count := 0;
    while !WindowShouldClose() {
        frame_count += 1;

        if IsKeyPressed(.KEY_ZERO) {
            top := platform.toggle(GetWindowHandle());
            logprint("host", ifx top then "window always on top" else "window not topmost");
        }

        if cmdline_args.live_reload {
            if frame_count % 4 == 0
                hotloader_process_change();

            force_reload := IsKeyPressed(.KEY_R) && (IsKeyDown(.KEY_LEFT_SHIFT) || IsKeyDown(.KEY_RIGHT_SHIFT));

            if force_reload || (frame_count % 2 == 0 && Plugin.should_reload(*module)) {
                ctx := context;
                old_state := plugin_deinit(*ctx, shutting_down = false);

                if !Plugin.reload(*module, force_reload) // TODO: this calls file_modtime for a second time and doesn't need to.
                    panic("couldn't reload module");
                assert(module.native_module != null);

                update_plugin_functions(*module);
                assert(plugin_tick != null);

                plugin_init(*ctx, old_state);
            }
        }

        ctx := context;
        plugin_tick(*ctx);
        reset_temporary_storage();
    }

    if !IsWindowFullscreen() && !platform.IsWindowBorderless(GetWindowHandle()) {
        builder: String_Builder;
        defer free_buffers(*builder);

        append(*builder, "[1]\n\n");
        pos := GetWindowPosition();
        print_to_builder(*builder, "window_pos_x %\n", cast(s32)pos.x);
        print_to_builder(*builder, "window_pos_y %\n", cast(s32)pos.y);

        output := builder_to_string(*builder);
        defer free(output);
        File.write_entire_file(host_config_name, output);
    }
}