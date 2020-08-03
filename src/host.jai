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

panic :: (msg: string) {
    write_string(msg);
    debug_break();
}

on_asset_change :: (using asset_change: *Asset_Change) {
    print("change: % % % %\n", short_name, full_name, extension, time_of_last_change);
    if extension == "jai" {
        if short_name == "game" {
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
}

host_settings: struct {
    window_pos_x: s32;
    window_pos_y: s32;
};

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

    InitWindow(800, 450, "game");
    SetWindowPosition(win_x, win_y);
    defer CloseWindow();

    module: Plugin.Module;
    if !Plugin.load(*module, "game.dll")
        panic("Could not load game.dll\n");
    defer Plugin.unload(*module);

    hotloader_init("src", true);
    hotloader_register_callback(on_asset_change);
    defer hotloader_shutdown();

    Update_And_Draw_Func :: #type ();
    update_and_draw := cast(Update_And_Draw_Func)GetProcAddress(module.native_module, "update_and_draw");
    if !update_and_draw panic("Could not load update_and_draw func");

    SetTargetFPS(60);
    while !WindowShouldClose() {
        hotloader_process_change();
        if Plugin.maybe_reload(*module) {
            print("plugin did reload.\n");
            assert(module.native_module != null);
            update_and_draw = cast(Update_And_Draw_Func)GetProcAddress(module.native_module, "update_and_draw");
            if !update_and_draw {
                print("no update_and_draw, exiting!\n");
                break;
            }
        }

        update_and_draw();
    }

    pos := GetWindowPosition();
    {
        builder: String_Builder;
        defer free_buffers(*builder);

        append(*builder, "[1]\n\n");
        print_to_builder(*builder, "window_pos_x %\n", cast(s32)pos.x);
        print_to_builder(*builder, "window_pos_y %\n", cast(s32)pos.y);

        output := builder_to_string(*builder);
        defer free(output);
        File.write_entire_file("game.cfg", output);
    }




}