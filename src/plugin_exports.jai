#scope_file // everything in this file is "private" since we're only exporting symbols.

#import "Basic";
#import "live_raylib";
Math :: #import "Math";
#import "raylib";

#load "host_common.jai";

#if HOTLOADING_ENABLED {

#import "Hotloader";

strip_dot_slash :: (path: string) -> string @substring {
    s := path;
    if s.count >= 2 && s[0] == #char "." && s[1] == #char "/"
        advance(*s, 2);
    return s;
}

#program_export
plugin_on_resource_change :: (ctx: *Context, using change: *Asset_Change) #c_call {
    push_context << ctx {
        assert(ctx.state != null);
        full_name_stripped := strip_dot_slash(full_name);
        try_reload_live_resource(full_name_stripped, extension);
    }
}

}

#program_export
plugin_init :: (ctx: *Context, old_value: *void, host_state: Host_State) #c_call {
    push_context << ctx {
        if old_value != null {
            ctx.state = cast(*State)old_value;
            on_host_did_reload_game_dll();
        } else {
            ctx.state = New(State);
            assert(ctx.state != null);

            // without creating soloud's context in the host, I get crashes on reload.
            // my theory right now is that it must have thread local storage, which,
            // inside the DLL, gets unloaded. but I don't want to investigate this right now.
            // so here we just receive the soloud context from the host.
            ctx.state.sound_state.soloud = host_state.soloud_context;

            on_host_init();
        }
    }
}

#program_export
plugin_deinit :: (ctx: *Context, shutting_down: bool) -> *void #c_call {
    push_context << ctx {
        assert(ctx.state != null);
        if shutting_down {
            on_host_shutdown();
            return null;
        }

        return ctx.state;
    }
}

_local_host_state: Host_State;

#program_export
plugin_tick :: (ctx: *Context, host_state: Host_State) #c_call {
    push_context << ctx {
        assert(ctx.state != null);
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
        color := make_Color(255, 40, 40, cast(u8)(255.0 * ((Math.sin(GetTime() * 5) + 1.0) / 4.0 + 0.3)));
        DrawRectangleLinesEx(rect, outline_width, color);
    }
}

