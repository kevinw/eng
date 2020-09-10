#scope_file // everything in this file is "private" since we're only exporting symbols.

#load "host_common.jai";

#if HOTLOADING_ENABLED {

#import "Hotloader";

strip_dot_slash :: (path: string) -> string {
    s := path;
    if s.count >= 2 && s[0] == #char "." && s[1] == #char "/"
        advance(*s, 2);
    return s;
}

#program_export
plugin_on_resource_change :: (ctx: *Context, using change: *Asset_Change) #c_call {
    push_context << ctx {
        full_name_stripped := strip_dot_slash(full_name);
        try_reload_live_resource(full_name_stripped, extension);
    }
}

}

#program_export
plugin_init :: (ctx: *Context, old_value: *void) #c_call {
    push_context << ctx {
        if old_value != null {
            old_state := cast(*State)old_value;
            state = << old_state;
            free(old_value);
            on_host_did_reload_game_dll();
        } else {
            on_host_init();
        }
    }
}

#program_export
plugin_deinit :: (ctx: *Context, shutting_down: bool) -> *void #c_call {
    push_context << ctx {
        if shutting_down {
            on_host_shutdown();
            return null;
        }

        bytes := size_of(State) * 2;
        heap_state := cast(*State)alloc(bytes); // * 2 for adding extra things on the end
        << heap_state = state;
        return heap_state;
    }
}

_local_host_state: Host_State;

#program_export
plugin_tick :: (ctx: *Context, host_state: Host_State) #c_call {
    push_context << ctx {
        _local_host_state = host_state;
        update_and_draw();
    }
}

#scope_module
host_debug_draw :: () {
    // Draw a very visible red outline if the jai compiler failed trying to recompile the game dll.
    if _local_host_state.jai_compiler_did_error {
        rect := make_Rectangle(0, 0, GetScreenWidth(), GetScreenHeight());
        outline_width := cast(s32)(max(GetScreenWidth(), GetScreenHeight()) * 0.03);
        color := Color.{255, 40, 40, 255};
        color.a = cast(u8)(255.0 * ((Math.sin(GetTime() * 5) + 1.0) / 4.0 + 0.3));
        DrawRectangleLinesEx(rect, outline_width, color);
    }
}

