#import "Basic";
#import "raylib";
#import "toolbelt";

#scope_file
TIME_ON_SCREEN :: 2.0;
MAX_COUNT :: 2000;
#scope_module

Logger_State :: struct {
    time: float64;
    entries: [..]Entry;
    this_frame_entries: [..]Entry;
}

Entry :: struct {
    time: float64;
    message: *u8;

    use_world_pos := false;
    world_pos: Vector2;
}

set_enabled :: (enabled: bool) {
    screenlog_is_installed = enabled;
}

context_func :: (message: string, ident: string, mode: Log_Mode, logger_data: *void) {
    assert(message.count < MAX_COUNT);
    assert(context.logger_data != null);
    using cast(*Logger_State)context.logger_data;

    entry := array_add(*entries);
    entry.time = time;
    entry.message = to_c_string(message);
}

sticky :: (message: string, args: ..Any) {
    if !screenlog_is_installed return;

    assert(message.count < MAX_COUNT);
    assert(context.logger_data != null);
    using cast(*Logger_State)context.logger_data;

    entry := array_add(*this_frame_entries);
    entry.message = to_c_string(tprint(message, ..args));
}

world :: (world_pos: Vector2, message: string, args: ..Any) {
    if !screenlog_is_installed return;

    assert(message.count < MAX_COUNT);
    assert(context.logger_data != null);
    using cast(*Logger_State)context.logger_data;

    assert(this_frame_entries.count < 1000);

    entry := array_add(*this_frame_entries);
    entry.use_world_pos = true;
    entry.world_pos = world_pos;
    entry.message = to_c_string(tprint(message, ..args));
}

update :: (delta_time: float64) {
    if !screenlog_is_installed return;

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
    if !screenlog_is_installed return;

    assert(context.logger_data != null);
    using cast(*Logger_State)context.logger_data;

    y:s32 = 0;
    font_size:s32 = 30;
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

    for this_frame_entries free(it.message);
    array_reset(*this_frame_entries);
}

draw_world :: () {
    if !screenlog_is_installed return;

    assert(context.logger_data != null);
    using cast(*Logger_State)context.logger_data;

    font_size :s32 = 15;

    for * this_frame_entries
        if it.use_world_pos
            DrawText(it.message, xx it.world_pos.x, xx it.world_pos.y, font_size, WHITE);

}

#scope_file

screenlog_is_installed := false;