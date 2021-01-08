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

        loc: Source_Code_Location;
    }
}

copy_loc :: (loc: Source_Code_Location) -> Source_Code_Location {
    res := loc;
    res.fully_pathed_filename = copy_string(res.fully_pathed_filename);
    return res;
}

free_entry :: (using entry: *Logger_State.Entry) {
    free(message);
    if ident.count > 0 free(ident);

    free(loc.fully_pathed_filename);
    loc.fully_pathed_filename = "";
    loc.line_number = 0;
    loc.character_number = 0;
}

get_context_state :: () -> *Logger_State {
    logger_state := cast(*Logger_State)context.logger_data;
    assert(logger_state.canary == Logger_State.EXPECTED_CANARY_VALUE,
        "invalid canary value for context.logger_state -- either it is not a screenlog.Logger_State, or the memory is corrupted");
    return logger_state;
}

locations_equal :: inline (a: Source_Code_Location, b: Source_Code_Location) -> bool {
    return a.fully_pathed_filename == b.fully_pathed_filename &&
        a.line_number == b.line_number &&
        a.character_number == b.character_number;
}

screen_print :: (message: string, ident := "", loc := #caller_location) {
    using ctx := get_context_state();

    for * entries if locations_equal(loc, it.loc) && it.ident == ident {
        if it.message != message {
            free_entry(it);
            it.message = copy_string(message);
            it.loc     = copy_loc(loc);
            it.ident = ifx ident.count > 0 then copy_string(ident) else "";
        }
        it.time = TIME_ON_SCREEN;
        return;
    }

    entry := array_add(*entries);
    entry.loc     = copy_loc(loc);
    entry.mode    = .EVERYDAY;
    entry.time    = TIME_ON_SCREEN;
    entry.ident   = ifx ident.count > 0 then copy_string(ident) else "";
    entry.message = copy_string(message);
}

context_func :: (message: string, ident_in: string, mode: Log_Mode, logger_data: *void) {
    ident := ident_in;
    assert(message.count < MAX_COUNT, "expected a screenlog message with a reasonable count, got %", message.count);
    assert(context.logger_data != null);
    using cast(*Logger_State)context.logger_data;
    
    time_on_screen := TIME_ON_SCREEN;
    if mode == .MINIMAL {
        time_on_screen = 100;
    }

    if ident.count > 0 {
        print_color("[%] ", ident, color=FOREGROUND_BLUE | FOREGROUND_GREEN);
        if mode == .MINIMAL {
            print_color("%\n", message, color=FOREGROUND_RED | FOREGROUND_INTENSITY);
        } else {
            print("%\n", message);
        }
    }

    // TODO: @Perf avoid the string copies here if the incoming strings are identical.

    new_ident := ifx ident.count > 0 then copy_string(ident) else "";
    new_message := ifx message.count > 0 then copy_string(message) else "";

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
String :: #import "String";

TIME_ON_SCREEN :: 2.0;
MAX_COUNT :: 200000;

