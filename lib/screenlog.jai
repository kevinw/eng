Logger_State :: struct {
    EXPECTED_CANARY_VALUE :: 555;
    canary := EXPECTED_CANARY_VALUE;

    entries: [..]Entry;
    this_frame_entries: [..]Entry;

    Entry :: struct {
        time: float64;
        message: string;
        ident: string;

        use_world_pos := false;
        world_pos: Vector2;
        mode: Log_Mode;
    }
}

free_entry :: (using entry: *Logger_State.Entry) {
    free(message);
    free(ident);
}

get_context_state :: () -> *Logger_State {
    logger_state := cast(*Logger_State)context.logger_data;
    assert(logger_state.canary == Logger_State.EXPECTED_CANARY_VALUE,
        "invalid canary value for context.logger_state -- either it is not a screenlog.Logger_State, or the memory is corrupted");
    return logger_state;
}


context_func :: (message: string, ident: string, mode: Log_Mode, logger_data: *void) {
    assert(message.count < MAX_COUNT, tprint("expected a screenlog message with a reasonable count, got %", message.count));
    assert(context.logger_data != null);
    using cast(*Logger_State)context.logger_data;
    
    time_on_screen := TIME_ON_SCREEN;
    if mode == .MINIMAL {
        time_on_screen = 100;
    }

    if ident.count > 0
        print_color("[%] ", ident, color=FOREGROUND_BLUE | FOREGROUND_GREEN);
    if mode == .MINIMAL {
        print_color("%\n", message, color=FOREGROUND_RED | FOREGROUND_INTENSITY);
    } else {
        print("%\n", message);
    }

    new_ident := copy_string(ident);
    new_message := copy_string(message);

    entry: *Logger_State.Entry;
    if new_ident.count > 1 && new_ident[0] == #char "=" {
        for * entries if it.ident == new_ident {
            entry = it;
            free_entry(entry);
            break;
        }
    }

    if entry == null
        entry = array_add(*entries);

    entry.mode = mode;
    entry.time = time_on_screen;
    entry.ident = new_ident;
    entry.message = new_message;
}

sticky :: (message: string, args: ..Any) {
    assert(message.count < MAX_COUNT);
    assert(context.logger_data != null);
    using cast(*Logger_State)context.logger_data;

    entry := array_add(*this_frame_entries);
    entry.message = sprint("%\0", tprint(message, ..args));
    entry.message.count -= 1;
}

world :: (pos: Vector3, message: string, time_to_show := TIME_ON_SCREEN) {
    assert(context.logger_data != null);
    using cast(*Logger_State)context.logger_data;

    entry := array_add(*entries);
    entry.time = time_to_show;
    entry.ident = "msg from world func\0";
    entry.message = sprint("%\0", message);
    entry.message.count -= 1;
    entry.use_world_pos = true;
    entry.world_pos = pos.xy;
}

world :: (world_pos: Vector2, message: string, args: ..Any) {
    assert(message.count < MAX_COUNT);
    assert(context.logger_data != null);
    using cast(*Logger_State)context.logger_data;

    assert(this_frame_entries.count < 1000);

    entry := array_add(*this_frame_entries);
    entry.use_world_pos = true;
    entry.world_pos = world_pos;
    entry.message = sprint("%\0", tprint(message, ..args));
    entry.message.count -= 1;
}

update :: (delta_time: float64) {
    assert(context.logger_data != null);
    using cast(*Logger_State)context.logger_data;
    //time += delta_time;
    for * entries {
        it.time -= delta_time;
        if it.time < 0 {
            free_entry(it);
            remove it;
        }
    }
}

#scope_file

#import "Print_Color";
#import "Math";
#import "Basic";

TIME_ON_SCREEN :: 2.0;
MAX_COUNT :: 200000;

