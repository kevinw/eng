#import "Thread";

_recompile_thread: *Thread;
needs_complete_reload := false;
reload_new_dll_filename: string;

//
// plugin functions
//
Plugin_Init_Func               :: #type (old_value: *void, host_state: Host_State);
Plugin_Deinit_Func             :: #type (shutting_down: bool) -> *void;
Plugin_Tick_Func               :: #type (host_state: Host_State);
Plugin_On_Resource_Change_Func :: #type (full_name: string, extension: string);
Plugin_Sanity_Checks_Func      :: #type (host_state: Host_State, host_context_size: int);

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

    cmd_string := String.concatenate(..arguments, " ");
    defer free(cmd_string);
    print("Running jai compiler: %\n", cmd_string);

    successfully_launched, exit_code, output_string, error_string := os_run_command(..arguments, capture_and_return_output=true);
    // @Leak

    print("[exit_code] %\n", exit_code);
    print("%\n", output_string);
    if error_string.count > 0 print("[stderr] %", error_string);

    host_state.jai_compiler_did_error = !successfully_launched || exit_code != 0;

    //free(host_state.jai_compiler_error_string);
    host_state.jai_compiler_error_string = sprint("% %", output_string, error_string);

    File.write_entire_file(".compiler_errors", output_string);

    return exit_code;
}

on_asset_change :: (using asset_change: *Asset_Change) {
    if extension == "pdb" return;
    if extension == "ini" && short_name == "imgui" return;

    //print("%\n", <<asset_change);
    //print("change: % % % %\n", short_name, full_name, extension, time_of_last_change);
    if extension == "jai" && !String.begins_with(short_name, "host") && 
        !String.begins_with(full_name, "./.") && 
        !String.begins_with(full_name, "./generated/") &&
        !String.begins_with(full_name, ".build/")
    {
        // Source changes mean we recompile the game DLL.
        log("host is recompiling for %", full_name);
        do_recompile();
    } else if extension == "dll" && String.begins_with(short_name, tprint("%_reloaded_", cmdline_args.game_name)) {
        // If we notice that the compiler has built a new game dll for us, we
        // unload the old plugin and load this new one!
        reload_new_dll_filename = full_name;
        if String.begins_with(reload_new_dll_filename, "./")
            advance(*reload_new_dll_filename, 2);
        reload_new_dll_filename = copy_string(reload_new_dll_filename);
    } else {
        // All other changes go to the plugin, which may want to live reload
        // textures, etc.
        if plugin_on_resource_change != null {
            plugin_on_resource_change(asset_change.full_name, asset_change.extension);
        }
    }
}

get_func_ptrs_from_dll :: (module: *Plugin.Module) {
    // these functions are implemented plugin-side in plugin_exports.jai

    // required functions

    // TODO: just use GetProcAddress which returns a struct full of function pointers?

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

