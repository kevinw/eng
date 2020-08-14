#import "Basic";
#import "raylib";
#import "toolbelt";

//
// TODO: consolidate the copy_strings in this file and use a version that 
// appends the null byte, so that we don't need a further temp copy on the other end!
//

TIME_ON_SCREEN :: 2.0;

Logger_State :: struct {
    time: float64;
    entries: [..]Entry;
    this_frame_entries: [..]Entry;
}

Entry :: struct {
    time: float64;
    message: string;

    use_world_pos := false;
    world_pos: Vector2;
}

context_func :: (message: string, ident: string, mode: Log_Mode, logger_data: *void) {
    assert(context.logger_data != null);
    using cast(*Logger_State)context.logger_data;

    entry := array_add(*entries);
    entry.time = time;
    entry.message = copy_string(message);
}

sticky :: (message: string, args: ..Any) {
    assert(context.logger_data != null);
    using cast(*Logger_State)context.logger_data;

    entry := array_add(*this_frame_entries);
    entry.message = copy_string(tprint(message, ..args));
}

world :: (world_pos: Vector2, message: string, args: ..Any) {
    assert(context.logger_data != null);
    using cast(*Logger_State)context.logger_data;

    entry := array_add(*this_frame_entries);
    entry.use_world_pos = true;
    entry.world_pos = world_pos;
    entry.message = copy_string(tprint(message, ..args));
}

update :: (delta_time: float64) {
    assert(context.logger_data != null);
    using cast(*Logger_State)context.logger_data;
    time += delta_time;
    for * entries {
        if time - it.time > TIME_ON_SCREEN {
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

    x := cast(s32)500;
    font_size = 15;
    y = 0;
    for * this_frame_entries {
        if it.use_world_pos continue;
        DrawText(to_temp_c_string(it.message), x, y, font_size, WHITE);
        y += font_size;
        free(it.message);
    }
    array_reset(*this_frame_entries);
}

draw_world :: () {
    assert(context.logger_data != null);
    using cast(*Logger_State)context.logger_data;

    font_size :s32 = 15;

    for * this_frame_entries {
        if !it.use_world_pos continue;
        DrawText(to_temp_c_string(it.message), xx it.world_pos.x, xx it.world_pos.y, font_size, WHITE);
    }

}
