#import "Basic";
#import "raylib";
#import "toolbelt";

// TODO: logs should use the camera's zoom to maintain its size on screen

#scope_file
TIME_ON_SCREEN :: 2.0;
MAX_COUNT :: 2000;


free_entry :: (using entry: *Entry) {
    free(message);
    free(ident);
}

Entry :: struct {
    time: float64;
    message: string;
    ident: string;

    use_world_pos := false;
    world_pos: Vector2;
}

#scope_module

Logger_State :: struct {
    time: float64;
    entries: [..]Entry;
    this_frame_entries: [..]Entry;
}

context_func :: (message: string, ident: string, mode: Log_Mode, logger_data: *void) {
    assert(message.count < MAX_COUNT);
    assert(context.logger_data != null);
    using cast(*Logger_State)context.logger_data;

    if ident.count == 0 || ident[0] != #char "="
        print("%: %\n", ident, message);

    new_ident := copy_string_z(ident);
    new_message := copy_string_z(message);

    entry: *Entry;
    if new_ident.count > 1 && new_ident[0] == #char "=" {
        for * entries {
            if it.ident == new_ident {
                entry = it;
                free_entry(entry);
                break;
            }
        }
    }

    if entry == null
        entry = array_add(*entries);

    entry.time = time;
    entry.ident = new_ident;
    entry.message = new_message;
}

sticky :: (message: string, args: ..Any) {
    assert(message.count < MAX_COUNT);
    assert(context.logger_data != null);
    using cast(*Logger_State)context.logger_data;

    entry := array_add(*this_frame_entries);
    entry.message = copy_string_z(tprint(message, ..args));
}

world :: (world_pos: Vector2, message: string, args: ..Any) {
    assert(message.count < MAX_COUNT);
    assert(context.logger_data != null);
    using cast(*Logger_State)context.logger_data;

    assert(this_frame_entries.count < 1000);

    entry := array_add(*this_frame_entries);
    entry.use_world_pos = true;
    entry.world_pos = world_pos;
    entry.message = copy_string_z(tprint(message, ..args));
}

update :: (delta_time: float64) {
    assert(context.logger_data != null);
    using cast(*Logger_State)context.logger_data;
    time += delta_time;
    for * entries {
        if time - it.time > TIME_ON_SCREEN {
            free_entry(it);
            remove it;
        }
    }
}

draw :: () {
    assert(context.logger_data != null);
    using cast(*Logger_State)context.logger_data;

    y:s32 = 0;
    font_size:s32 = 27;
    for * entries {
        DrawText(it.message, 0, y, font_size, WHITE);
        y += font_size;
    }

    x := cast(s32)500;
    font_size = 15;
    y = 0;
    for * this_frame_entries {
        if it.use_world_pos continue;
        DrawText(it.message, x, y, font_size, WHITE);
        y += font_size;
    }

    for * this_frame_entries free_entry(it);
    array_reset(*this_frame_entries);
}

draw_world :: () {
    assert(context.logger_data != null);
    using cast(*Logger_State)context.logger_data;

    font_size :s32 = 15;

    for * this_frame_entries
        if it.use_world_pos
            DrawText(it.message, xx it.world_pos.x, xx it.world_pos.y, font_size, WHITE);

}
