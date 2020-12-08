
draw :: () {
    assert(context.logger_data != null);
    using cast(*screenlog.Logger_State)context.logger_data;

    starting_x := cast(s32)400;

    y:s32 = 0;
    font_size:s32 = 22;
    for * entries {
        rl.DrawText(it.message, starting_x, y, font_size, rl.WHITE);
        y += font_size;
    }

    x := cast(s32)500;
    font_size = 15;
    y = 0;
    for * this_frame_entries {
        if it.use_world_pos continue;
        rl.DrawText(it.message, x, y, font_size, rl.WHITE);
        y += font_size;
    }

    for * this_frame_entries screenlog.free_entry(it);
    array_reset(*this_frame_entries);
}

draw_world :: () {
    assert(context.logger_data != null);
    using cast(*screenlog.Logger_State)context.logger_data;

    font_size :: 9;

    draw :: #code { rl.DrawText(it.message, xx it.world_pos.x, xx it.world_pos.y, font_size, rl.WHITE); };

    for * this_frame_entries if it.use_world_pos
        #insert_internal draw;
            
    for * entries if it.use_world_pos
        #insert_internal draw;
}

#scope_file
screenlog :: #import "screenlog";
rl :: #import "raylib";
#import "Basic";
