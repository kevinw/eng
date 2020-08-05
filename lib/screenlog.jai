#import "Basic";
#import "raylib";
#import "toolbelt";

context_func :: (message: string, ident: string, mode: Log_Mode, logger_data: *void) {
    assert(context.logger_data != null);
    using cast(*Logger_State)context.logger_data;

    print("LOG: %\n", message);

    entry: Entry;
    entry.time = time;
    entry.message = copy_string(message);
    array_add(*entries, entry);
}

update :: (delta_time: float64) {
    assert(context.logger_data != null);
    using cast(*Logger_State)context.logger_data;

    time += delta_time;

    for * entries {
        if time - it.time > 2.0 {
            print("removing message '%'\n", it.message);

            free(it.message);
            remove it;
        }
    }
}

draw :: () {
    assert(context.logger_data != null);
    using cast(*Logger_State)context.logger_data;

    y:s32 = 0;
    font_size:s32 = 30;
    for * entries {
        DrawText(to_temp_c_string(it.message), 0, y, font_size, WHITE);
        y += font_size;
    }
}

Logger_State :: struct {
    time: float64;
    entries: [..]Entry;
}

#scope_file

Entry :: struct {
    time: float64;
    message: string;
}
