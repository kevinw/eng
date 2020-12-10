free_entry :: (using entry: *Entry) {
    free(message);
    free(ident);
}

Logger_State :: struct {
    //time: float64;
    entries: [..]Entry;
    this_frame_entries: [..]Entry;
}

context_func :: (message: string, ident: string, mode: Log_Mode, logger_data: *void) {
    assert(message.count < MAX_COUNT);
    assert(context.logger_data != null);
    using cast(*Logger_State)context.logger_data;

    if ident.count == 0 || ident[0] != #char "="
        print("[%] %\n", ident, message);

    new_ident := sprint("%\0", ident);
    new_message := sprint("%\0", message);

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

    entry.time = TIME_ON_SCREEN;
    entry.ident = new_ident;
    entry.message = new_message;
}

sticky :: (message: string, args: ..Any) {
    assert(message.count < MAX_COUNT);
    assert(context.logger_data != null);
    using cast(*Logger_State)context.logger_data;

    entry := array_add(*this_frame_entries);
    entry.message = sprint("%\0", tprint(message, ..args));
}

world :: (pos: Vector3, message: string, time_to_show := TIME_ON_SCREEN) {
    assert(context.logger_data != null);
    using cast(*Logger_State)context.logger_data;

    entry := array_add(*entries);
    entry.time = time_to_show;
    entry.ident = "msg from world func\0";
    entry.message = sprint("%\0", message);
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

#import "Math";
#import "Basic";

TIME_ON_SCREEN :: 2.0;
MAX_COUNT :: 2000;

Entry :: struct {
    time: float64;
    message: string;
    ident: string;

    use_world_pos := false;
    world_pos: Vector2;
}

