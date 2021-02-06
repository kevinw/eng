#import "Basic";
#import "Windows";
#import "Hotloader";
#import "config";
#import "Process";
#import "System";
#import "util";
#import "Math";
#import "Input";
#import "DPI";

File            :: #import "File";
String          :: #import "String";
Debug           :: #import "Debug";
Plugin          :: #import "plugin";
Window_Creation :: #import "Window_Creation";
Compiler        :: #import "Compiler";
platform        :: #import "platform";
screenlog       :: #import "screenlog";
#import "soloud";

#import "host_common";
#load "host_lookingglass.jai";

WINDOW_WIDTH  :: 1280;
WINDOW_HEIGHT :: 720;

cmdline_args: struct {
    topmost_window := true;
    live_reload    := true;
    game_name      := DEFAULT_SRC_PLUGIN;
    allocator      := Allocator_Mode.Default;
};

Allocator_Mode :: enum {
    Default;
    Page_Guard;
}

the_window: Window_Type; // the application main window
host_state: Host_State;
transparent_while_not_focused := false;
plugin_requested_reload := false;
host_settings: struct { // gets serialized to disk to remember the window position
    window_pos_x: s32;
    window_pos_y: s32;
    window_width: s32;
    window_height: s32;
};
windowed_state: platform.Windowed_State;
window_was_borderless: bool; // we store this because by the time the window
                             // is closed, we can not query to see if it is (was) borderless or not
#if BUILDING_DLLS {
    #load "metaprogram_common.jai";
    #load "host_live_reload.jai";
}

panic :: (msg: string) {
    write_string(msg);
    write_string("\n");
    debug_break();
}

change_window_state :: (window_state_operation: Window_State_Operation) {
    if window_state_operation == {
        case .Toggle_Borderless_Fullscreen;
            fullscreen := toggle_borderless_fullscreen(the_window);
            logprint("host", ifx fullscreen then  "window borderless fullscreen" else "windowed mode");
        case .Toggle_Always_On_Top;
            top := platform.toggle_always_on_top(the_window);
            logprint("host", ifx top then "window always on top" else "window not topmost");
        case .Toggle_Transparent_When_Out_Of_Focus;
            transparent_while_not_focused = !transparent_while_not_focused;
            logprint("host", ifx transparent_while_not_focused then "transparent on focus lost ON" else "transparent on focus lost OFF");
        case .Force_Plugin_DLL_Reload;
            plugin_requested_reload = true;
    }
}

toggle_borderless_fullscreen :: (handle: Window_Type) -> bool {
    using platform;
    
    if is_window_borderless(handle) {
        window_was_borderless = false;
        set_window_always_on_top(handle, true);
        reset_if_empty(*windowed_state, 50, 50, 1200, 675);
        set_window_borderless(handle, false, *windowed_state);
        return false;
    } else {
        windowed_state = set_window_borderless_fullscreen(handle);
        window_was_borderless = true;
        set_window_always_on_top(handle, false);
        return true;
    }
}

parse_commandline_arguments :: () {
    args := get_command_line_arguments();
    defer array_free(args);

    did_set_plugin_dll := false;
    for args if it == {
        case "--page-guard";
            cmdline_args.allocator = .Page_Guard;
        case "--no-topmost";
            print("skipping topmost window\n");
            cmdline_args.topmost_window = false;
        case "--no-live-reload";
            print("no live reload\n");
            cmdline_args.live_reload = false;
        case;
            if it.count >= 1 && it[0] == #char "-" {
                print("[host] ERROR: invalid argument '%'\n", it);
                exit(1);
            }
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

#if OS == .WINDOWS {
    set_window_NOT_always_on_top :: (window: *void) #c_call {
        SetWindowPos(window, HWND_NOTOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
    }

    old_exception_filter: #type (i: *EXCEPTION_POINTERS) -> s32 #c_call;

    _host_handle_exception :: (pExceptionInfo: *EXCEPTION_POINTERS) -> s32 #c_call {
        // make our windows not always on top if we crash, so the debugger
        // doesn't get obscured
        set_window_NOT_always_on_top(the_window);
        for host_state.debug_extra_window_handles
            set_window_NOT_always_on_top(it);

        if old_exception_filter == null return 0;
        return old_exception_filter(pExceptionInfo);
    }

}

main :: () {
    get_time(); // start the clock!

    #if DEBUG_MODULE {
        Debug.init();

        // we install our own exception handler to make our windows not always
        // on top in case of an exception
        #if OS == .WINDOWS
            old_exception_filter = SetUnhandledExceptionFilter(_host_handle_exception);
    }

    os_dpi_init(); // must be called before any window creation

    found, exe_path, exe_name := String.split_by_character_from_right(get_path_of_running_executable(), #char "/");
    if !found {
        print("Error: unable to find my own exe\n");
        exit(1);
    }

    parse_commandline_arguments();

    if cmdline_args.allocator == .Page_Guard {
        #if GUARD_ALLOCATOR {
            GWP :: #import "gwpasan";
            print("[host] Using slow guard allocator\n");
            GWP.init(max_allocation = 100000, sample_rate = 1);
            context.allocator = GWP.allocator;
        } else {
            print("[host] WARNING: requested Page_Guard allocator, but host was not built with it included.\n");
        }
    }

    context.logger_data = New(screenlog.Logger_State);
    context.logger = screenlog.context_func;
    defer free(context.logger_data);

    host_config_name :: "setup.cfg";
    parse_config_file(*host_settings, tprint("%/%", exe_path, host_config_name));
    win_x:= host_settings.window_pos_x;
    win_y:= host_settings.window_pos_y;
    win_width  := host_settings.window_width;
    win_height := host_settings.window_height;

    if win_width < 50 win_width = WINDOW_WIDTH;
    if win_height < 50 win_height = WINDOW_HEIGHT;

    looking_glass_found, looking_glass_devices := LKG_discover_device(app_name="eng");

    the_window = Window_Creation.create_window(win_width, win_height, "", window_x=win_x, window_y=win_y);

    host_state.looking_glass_devices = looking_glass_devices;
    host_state.window_handle         = the_window;
    host_state.input_button_states   = *input_button_states;
    host_state.change_window_state   = change_window_state;
    host_state.pending_resizes       = *pending_resizes;
    host_state.built_with_backend    = #run get_compiler_codegen_backend();

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

    plugin_sanity_checks(host_state, Sanity_Check_Info.{size_of_context = size_of(Context)});
    plugin_init(null, host_state);
    assert(context.state != null, "plugin_init did not allocate a state");
    defer plugin_deinit(shutting_down = true);

    window_was_active := platform.is_window_active(the_window);

    // set_target_fps(30);
    frame_count := 0;

    window_did_move: bool;
    window_did_resize: bool;
    window_move_record: Window_Move_Record;
    window_resize_record: Window_Resize_Record;

    window_has_been_closed: bool;
    while true {
        auto_release_temp();
        update_window_events();
        for events_this_frame if it.type == {
            case .QUIT;
                DestroyWindow(the_window); // for multiview stuff
                window_has_been_closed = true;
            case .KEYBOARD;
                if it.key_pressed && it.key_code == cast(Key_Code)#char "Q" && it.alt_pressed && it.ctrl_pressed
                    platform.request_window_close(the_window);
        }
        if window_has_been_closed break;

        // pass a copy of all events down into the plugin
        host_state.events_this_frame.count = 0;
        host_state.mouse_delta.x = mouse_delta_x;
        host_state.mouse_delta.y = mouse_delta_y;
        host_state.mouse_delta.z = mouse_delta_z;
        for events_this_frame array_add(*host_state.events_this_frame, it);

        for pending_moves if it.window == the_window {
            window_move_record = it;
            window_did_move = true;
            remove it;
        }
        for pending_resizes if it.window == the_window {
            window_resize_record = it;
            window_did_resize = true;
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

        #if BUILDING_DLLS {
        if cmdline_args.live_reload {
            if frame_count % 4 == 0 hotloader_process_change();

            recompile_requested := is_key_pressed(cast(Key_Code)#char "r") && is_key_down(.SHIFT);
            if recompile_requested
                do_recompile();

            if _recompile_thread == null && (frame_count % 2 == 0) && (
                Plugin.should_reload(*module) || reload_new_dll_filename.count > 0 || plugin_requested_reload
            ) {
                //if Plugin.should_reload(*module) logprint("host", "Plugin.should_reload(*module) was true");
                //if reload_new_dll_filename.count > 0 logprint("host", "reload_new_dll_filename was %", reload_new_dll_filename);

                old_state := plugin_deinit(shutting_down = false);

                force_reload := false;
                if plugin_requested_reload {
                    force_reload = true;
                    plugin_requested_reload = false;
                }
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

                plugin_sanity_checks(host_state, .{size_of_context = size_of(Context)});

                if needs_complete_reload {
                    // when switching games, we deallocate the old game state
                    // and pass a null pointer to plugin_init, which indicates
                    // that it should start from scratch
                    needs_complete_reload = true;
                    free(old_state);
                    old_state = null;
                }

                plugin_init(old_state, host_state);
            }
        }
        } // BUILDING_DLLS

        host_state.time = get_time();
        plugin_tick(host_state);
    }

    if (window_did_move || window_did_resize) && !window_was_borderless {
        if window_move_record.x == 0
            window_move_record.x, window_move_record.y = platform.get_window_position(the_window);
        if window_resize_record.width == 0
            window_resize_record.width, window_resize_record.height = platform.get_window_size(the_window);

        builder: String_Builder;
        builder.allocator = __temporary_allocator;
        append(*builder, "[2]\n\n");
        print_to_builder(*builder, "window_pos_x %\nwindow_pos_y %\nwindow_width %\nwindow_height %\n",
            window_move_record.x, window_move_record.y,
            window_resize_record.width, window_resize_record.height);

        s := builder_to_string(*builder, __temporary_allocator);
        File.write_entire_file(host_config_name, s);
    }

    logprint("host", "exit OK.");
}

#scope_file

is_key_pressed :: (key: Key_Code) -> bool { return input_button_states[cast(int)key] & .START != 0; }
is_key_down    :: (key: Key_Code) -> bool { return input_button_states[cast(int)key] & .DOWN != 0; }

