#import "Basic";
#import "Windows";
#import "Hotloader";
#import "String";
#import "config";
#import "Process";
#import "System";
#import "util";

File :: #import "File";
String :: #import "String";
Debug :: #import "Debug";
Plugin :: #import "plugin";
platform :: #import "platform";
screenlog :: #import "screenlog";
#import "soloud";


cmdline_args: struct {
    topmost_window := false;
    live_reload    := true;
    game_name      := DEFAULT_SRC_PLUGIN;
};

WINDOW_WIDTH  :: 1280;
WINDOW_HEIGHT :: 720;

#load "host_common.jai";

the_window: Window_Type;
host_state: Host_State;
transparent_while_not_focused := true;
host_settings: struct {
    window_pos_x: s32;
    window_pos_y: s32;
};

//#add_context state: *void;

#if BUILDING_DLLS {
    #load "metaprogram_common.jai";
    #load "host_live_reload.jai";
}

panic :: (msg: string) {
    write_string(msg);
    debug_break();
}

///
//
//

#import "Math";
#import "Window_Creation";
#import "Input";

is_key_pressed :: (key: Key_Code) -> bool {
    return input_button_states[cast(int)key] & .START != 0;
}
is_key_down    :: (key: Key_Code) -> bool {
    return input_button_states[cast(int)key] & .DOWN != 0;
}
is_window_fullscreen :: () -> bool {
    // Raylib had "true fullscreen" but we haven't reimplemented it yet.
    return false;
}

window_rect: [4]s32;

toggle_borderless_fullscreen :: () {
    using platform;

    handle := the_window;
    
    if is_window_borderless(handle) {
        set_window_borderless(handle, false);
        set_window_always_on_top(handle, true);
        if window_rect[0] <= 0 window_rect[0] = 50;
        if window_rect[1] <= 0 window_rect[1] = 50;
        if window_rect[2] == 0 window_rect[2] = 1200;
        if window_rect[3] == 0 window_rect[3] = 675;
        set_window_rect(handle, window_rect[0], window_rect[1], window_rect[2], window_rect[3]);
    } else {
        x, y := get_window_position(handle);
        w, h := get_window_size(handle);

        set_window_borderless(handle, true);
        window_rect[0] = x;
        window_rect[1] = y;
        window_rect[2] = w;
        window_rect[3] = h;
        set_window_always_on_top(handle, false);
        {
            #import "Windows";
            w := GetSystemMetrics(SM_CXSCREEN);
            h := GetSystemMetrics(SM_CYSCREEN);
            SetWindowPos(handle, HWND_TOP, 0, 0, w, h, SWP_FRAMECHANGED);
        }
    }


}


//

main :: () {
    #if DEBUG_MODULE {
        Debug.init();
    }
    
    #if GUARD_ALLOCATOR {
        GWP :: #import "gwpasan";
        print("[host] Using slow guard allocator\n");
        GWP.init(max_allocation = 100000, sample_rate = 1);
        context.allocator = GWP.allocator;
    }

    found, exe_path, exe_name := split_by_character_from_right(get_path_of_running_executable(), #char "/");
    if !found {
        print("Error: unable to find my own exe\n");
        exit(1);
    }

    {
        args := get_command_line_arguments();
        defer array_free(args);

        did_set_plugin_dll := false;
        for args if it == {
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

    #if BUILDING_DLLS {
        game_index := 0;
        {
            found_game_name, idx := array_find(all_games, cmdline_args.game_name);
            if found_game_name
                game_index = idx;
        }
    }

    context.logger_data = New(screenlog.Logger_State);
    context.logger = screenlog.context_func;
    defer free(context.logger_data);

    host_config_name :: "setup.cfg";
    parse_config_file(*host_settings, tprint("%/%", exe_path, host_config_name));
    win_x:= host_settings.window_pos_x;
    win_y:= host_settings.window_pos_y;

    the_window = create_window(WINDOW_WIDTH, WINDOW_HEIGHT, "", window_x=win_x, window_y=win_y);
    host_state.window_handle                = the_window;
    host_state.input_button_states          = *input_button_states;
    host_state.toggle_borderless_fullscreen = toggle_borderless_fullscreen;
    host_state.pending_resizes              = *pending_resizes;

    if cmdline_args.topmost_window
        platform.set_window_always_on_top(the_window);

    #if BUILDING_DLLS {
        if cmdline_args.live_reload {
            hotloader_init(".", _DEBUG_LOGGING=false);
            hotloader_register_callback(on_asset_change);
        }
        defer if cmdline_args.live_reload hotloader_shutdown();

        module: Plugin.Module;
        plugin_dll_filename := copy_string_z(tprint("%.dll", cmdline_args.game_name));

        if !Plugin.load(*module, plugin_dll_filename, COPY_TO_TEMP_PATH = cmdline_args.live_reload)
            panic(tprint("Could not load DLL '%'\n", plugin_dll_filename));
        defer Plugin.unload(*module);
        get_func_ptrs_from_dll(*module);
    }

    soloud := Soloud_create();
    assert(soloud != null);
    Soloud_init(soloud, SOLOUD_CLIP_ROUNDOFF);
    defer {
        Soloud_deinit(soloud);
        Soloud_destroy(soloud);
    }
    host_state.soloud_context = soloud;

    plugin_sanity_checks(Sanity_Check_Info.{size_of_context = size_of(Context)});
    plugin_init(null, host_state);
    assert(context.state != null, "plugin_init did not allocate a state");
    defer plugin_deinit(shutting_down = true);

    window_was_active := platform.is_window_active(the_window);

    // set_target_fps(30);
    frame_count := 0;

    window_did_move: bool;
    window_move_record: Window_Move_Record;

    window_has_been_closed: bool;
    while true {
        auto_release_temp();
        update_window_events();
        for events_this_frame if it.type == {
            case .QUIT;
                window_has_been_closed = true;
            case .KEYBOARD;
                if it.key_pressed && it.key_code == cast(Key_Code)#char "Q" && it.alt_pressed && it.ctrl_pressed
                    platform.request_window_close(the_window);
        }
        if window_has_been_closed break;

        // pass a copy of all events down into the plugin
        host_state.events_this_frame.count = 0;
        for events_this_frame array_add(*host_state.events_this_frame, it);

        for pending_moves if it.window == the_window {
            window_move_record = it;
            window_did_move = true;
            remove it;
        }

        frame_count += 1;

        // Set the window to be a little transparent when it's not in focus, if we're always on top.
        {
            win_active := platform.is_window_active(the_window);
            if (!win_active && window_was_active && platform.is_window_always_on_top(the_window)) && transparent_while_not_focused
                platform.set_window_opacity(the_window, 0.63);
            else if (win_active && !window_was_active) || !transparent_while_not_focused
                platform.set_window_opacity(the_window, 1.0);

            window_was_active = win_active;
        }

        if is_key_pressed(cast(Key_Code)#char "0") {
            top := platform.toggle_always_on_top(the_window);
            logprint("host", ifx top then "window always on top" else "window not topmost");
        }

        if is_key_pressed(cast(Key_Code)#char "9") {
            transparent_while_not_focused = !transparent_while_not_focused;
            logprint("host", ifx transparent_while_not_focused then "transparent on focus lost ON" else "transparent on focus lost OFF");
        }

        #if BUILDING_DLLS {
        if cmdline_args.live_reload {
            if frame_count % 4 == 0 hotloader_process_change();

            recompile_requested := is_key_pressed(cast(Key_Code)#char "r") && is_key_down(.SHIFT);
            if recompile_requested
                do_recompile();

            game_delta := 0;
            if is_key_pressed(cast(Key_Code)#char "[") game_delta -= 1;
            if is_key_pressed(cast(Key_Code)#char "]") game_delta += 1;
            if game_delta != 0 {
                game_index += game_delta;
                if game_index < 0 game_index = all_games.count - 1;
                if game_index >= all_games.count game_index = 0;
                reload_new_dll_filename = all_games[game_index];
                logprint("game switch", "loading new game from '%'", reload_new_dll_filename);
                needs_complete_reload = true;
            }

            if _recompile_thread == null && (frame_count % 2 == 0) && (
                Plugin.should_reload(*module) || reload_new_dll_filename.count > 0
            ) {
                if Plugin.should_reload(*module) logprint("host", "Plugin.should_reload(*module) was true");
                if reload_new_dll_filename.count > 0 logprint("host", "reload_new_dll_filename was %", reload_new_dll_filename);

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
                assert(!Plugin.should_reload(*module));

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

                logprint("host", "calling plugin_init");
                plugin_init(old_state, host_state);
            }
        }
        } // BUILDING_DLLS

        plugin_tick(host_state);
    }

    if window_did_move && !platform.is_window_borderless(the_window) {
        builder: String_Builder;
        builder.allocator = __temporary_allocator;

        append(*builder, "[1]\n\n");
        print_to_builder(*builder, "window_pos_x %\nwindow_pos_y %\n",
            window_move_record.x, window_move_record.y);

        File.write_entire_file(host_config_name, builder_to_string(*builder));
    }

    logprint("host", "exit OK.");
}
