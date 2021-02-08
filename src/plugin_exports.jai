#import "Hotloader";

#program_export
plugin_sanity_checks :: (host_state: Host_State, host_context_size: int) {
    my_context_size := size_of(Context);
    assert(host_context_size == my_context_size, "Error: host/plugin context size mismatch - % vs %", 
        host_context_size, my_context_size);

    // At the time of this writing, building the host with LLVM and the
    // plugin with the custom X64 backend results in errors. Here we do
    // a sanity check so we get a nice error message. Hopefully in the future
    // the two backends could generate compatible code.
    plugin_codegen_backend :: #run get_compiler_codegen_backend();
    assert(plugin_codegen_backend == host_state.built_with_backend,
        "host built with % but plugin built with %",
        host_state.built_with_backend, plugin_codegen_backend);
}

#program_export
plugin_on_resource_change :: (full_name: string, extension: string) {
    assert(context.state != null);

    assert(full_name.count > 0);
    assert(extension.count > 0);

    full_name_stripped := strip_dot_slash(full_name);
    try_reload_live_resource(full_name_stripped, extension);
}

#program_export
plugin_init :: (old_value: *void, host_state: Host_State) {
    // called when our DLL first gets loaded.
    if old_value == null {
        // here, plugin_init is getting called for the first time. let's allocate
        // room for a State struct and continue with initialization.
        context.state = New(State);
        on_host_init(host_state);
    } else {
        // in this case, there is a game running, and old_value has
        // the State pointer of the old DLL's memory.
        context.state = cast(*State)old_value;
        on_host_did_reload_game_dll(host_state);
    }
}

#program_export
plugin_deinit :: (shutting_down: bool) -> *void {
    assert(context.state != null);

    if shutting_down {
        on_host_shutdown();
        return null;
    }

    return context.state;
}


#program_export
plugin_tick :: (host_state: Host_State) {
    assert(context.state != null);
    _local_host_state = host_state;
    update_and_draw(host_state);
}

#scope_module
_local_host_state: Host_State;
host_debug_draw :: () {
    // Draw a very visible red outline if the jai compiler failed trying to recompile the game dll.
    if _local_host_state.jai_compiler_did_error {
        game_base_draw_compile_error();
    }
}

get_plugin_compile_error :: () -> (bool, string) {
    return _local_host_state.jai_compiler_did_error, _local_host_state.jai_compiler_error_string;
}

#scope_file

strip_dot_slash :: (path: string) -> string @substring {
    s := path;
    if s.count >= 2 && s[0] == #char "." && s[1] == #char "/"
        advance(*s, 2);
    return s;
}

has_field :: (ti_struct: *Type_Info_Struct, field_name: string) -> bool {
    for ti_struct.members
        if it.name == field_name
            return true;
    return false;
}

#import "Basic";

