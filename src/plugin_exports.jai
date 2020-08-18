#scope_file // everything in this file is "private" since we're only exporting symbols.

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
        if extension == "png" {
            TryReloadLiveTexturePath(full_name_stripped);
        } else if extension == "fs" || extension == "vs" {
            TryReloadLiveShaderPath(full_name_stripped);
        }
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

#program_export
plugin_tick :: (ctx: *Context) #c_call {
    push_context << ctx {
        update_and_draw();
    }
}

