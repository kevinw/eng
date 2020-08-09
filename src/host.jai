#import "Basic";
#import "raylib";
#import "Windows";
#import "Hotloader";
#import "String";
#import "config";
#import "Process";
#import "System";
File :: #import "File";
Debug :: #import "Debug";
Plugin :: #import "plugin";
Platform :: #import "platform";
screenlog :: #import "screenlog";

panic :: (msg: string) {
    write_string(msg);
    debug_break();
}

WINDOW_WIDTH :: 1200;
WINDOW_HEIGHT :: 675;
ALWAYS_ON_TOP :: true;

on_asset_change :: (using asset_change: *Asset_Change) {
    print("change: % % % %\n", short_name, full_name, extension, time_of_last_change);
    if extension == "jai" && short_name == "game" {
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
    }
}

host_settings: struct {
    window_pos_x: s32;
    window_pos_y: s32;
};

// plugin functions
Update_And_Draw_Func :: #type ();
Plugin_Init_Func     :: #type (state: *void);
Plugin_Deinit_Func   :: #type (shutting_down: bool) -> *void;

update_and_draw: Update_And_Draw_Func;
plugin_init: Plugin_Init_Func;
plugin_deinit: Plugin_Deinit_Func;

update_plugin_functions :: (module: *Plugin.Module) {
    update_and_draw = cast(Update_And_Draw_Func)GetProcAddress(module.native_module, "update_and_draw");
    if !update_and_draw panic("Could not load update_and_draw func");

    plugin_init = cast(Plugin_Init_Func)GetProcAddress(module.native_module, "plugin_init");
    if !plugin_init panic("Could not load plugin_init func");

    plugin_deinit = cast(Plugin_Deinit_Func)GetProcAddress(module.native_module, "plugin_deinit");
    if !plugin_deinit panic("Could not load plugin_deinit func");
}

wbml :: #import "wbml";
Math :: #import "Math";

main_wbml :: () {
    val: struct {
        foo:string;
        floating_point: float64;
        bool_value: bool;
        bool_value_2: bool;
        meep:int;
        baz: struct {
            blap: string;
        };
    };

    val.foo = "bar";
    val.meep = 7;
    val.bool_value = true;
    val.bool_value_2 = false;
    val.floating_point = Math.PI;
    val.baz.blap = "maaz";

    output := wbml.serialize(*val);
    print("serialized '%' as:\n%", val, output);

    new_val := wbml.deserialize_to_value(type_of(val), output);
    print("unserialized as\n%", new_val);
}

main :: () {
    Debug.init();

    found, exe_path, exe_name := split_by_character_from_right(get_path_of_running_executable(), #char "/");
    if !found {
        print("Error: unable to find my own exe\n");
        return;
    }

    SetTraceLogLevel(.LOG_WARNING);

    parse_config_file(*host_settings, tprint("%/%", exe_path, "game.cfg"));
    win_x:= host_settings.window_pos_x;
    win_y:= host_settings.window_pos_y;

    InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "");
    SetWindowPosition(win_x, win_y);
    defer CloseWindow();

    context.logger_data = New(screenlog.Logger_State);
    context.logger = screenlog.context_func;
    defer free(context.logger_data);

    InitAudioDevice();
    defer CloseAudioDevice();

    #if ALWAYS_ON_TOP
        Platform.SetWindowAlwaysOnTop(GetWindowHandle());

    hotloader_init("src", _DEBUG_LOGGING=false);
    hotloader_register_callback(on_asset_change);
    defer hotloader_shutdown();

    module: Plugin.Module;
    if !Plugin.load(*module, "game.dll")
        panic("Could not load game.dll\n");
    defer Plugin.unload(*module);
    update_plugin_functions(*module);

    plugin_init(null);
    defer plugin_deinit(shutting_down = true);

    SetTargetFPS(60);
    frame_count := 0;
    while !WindowShouldClose() {
        frame_count += 1;

        if frame_count % 4 == 0
            hotloader_process_change();

        if frame_count % 2 == 0 && Plugin.should_reload(*module) {
            old_state := plugin_deinit(shutting_down = false);

            if !Plugin.reload(*module) // TODO: this calls file_modtime for a second time and doesn't need to.
                panic("couldn't reload module");
            assert(module.native_module != null);

            update_plugin_functions(*module);
            assert(update_and_draw != null);

            plugin_init(old_state);
        }

        update_and_draw();
        reset_temporary_storage();
    }

    if !IsWindowFullscreen() {
        builder: String_Builder;
        defer free_buffers(*builder);

        append(*builder, "[1]\n\n");
        pos := GetWindowPosition();
        print_to_builder(*builder, "window_pos_x %\n", cast(s32)pos.x);
        print_to_builder(*builder, "window_pos_y %\n", cast(s32)pos.y);

        output := builder_to_string(*builder);
        defer free(output);
        File.write_entire_file("game.cfg", output);
    }
}