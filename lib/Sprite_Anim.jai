Sprite_Anim :: struct {
    MAX_FRAME_COUNT :: 500;

    Frame :: struct {
        texture: Texture;
        rect: Rectangle;
        offset: Vector2;
        duration_secs: float;
    }

    Tag :: struct {
        name: string;
        frames: []Frame; @Weak
        tag_duration_secs: float;
    }

    frames: [..]Frame;
    total_duration_secs: float;
    tags: [..]Tag;
}

deinit :: (using sprite_anim: *Sprite_Anim) {
    array_free(frames);
    for tags free(it.name);
    array_free(tags);
}

get_frame :: (using sprite_anim: *Sprite_Anim, timer: float64, tag_name := "") -> (bool, Sprite_Anim.Frame, frame_index: int) {
    assert(total_duration_secs > 0);

    frames_to_iterate:[]Frame = frames;

    duration := total_duration_secs;

    if tag_name.count > 0 {
        found := false;
        for * tags if it.name == tag_name {
            frames_to_iterate = it.frames;
            duration = it.tag_duration_secs;
            found = true;
        }

        if !found {
            assert(false, tprint("no tag named %", tag_name));
            //logprint("=Sprite_Anim", "no tag named '%'", tag_name);
        }
    }

    timer_mod := Math.fmod(timer, duration);

    t := 0.0;
    for * frames_to_iterate {
        t += it.duration_secs;
        if t > timer_mod
            return true, << it, it_index;
    }

    assert(false, "couldn't get a Sprite_Anim rect");
    return false, .{}, -1;
}

draw :: (using sprite_anim: *Sprite_Anim, time: float64, pos: Vector2, tag_name := "") {
    assert(sprite_anim != null);
    assert(frames.count > 0);
    assert(frames.count < MAX_FRAME_COUNT);
    ok, frame := get_frame(sprite_anim, time, tag_name);
    if ok
        draw_frame(frame, pos);
    else
        logprint("warning", "couldn't get frame");
}

draw_frame :: (frame: Sprite_Anim.Frame, pos: Vector2) {
    dest_rect := make_Rectangle(pos.x, pos.y, frame.rect.width, frame.rect.height);
    toolbelt.draw_texture(frame.texture, frame.rect, dest_rect, frame.offset);
}

load_from_aseprite :: (sprite_anim: *Sprite_Anim, filename: string) -> bool {
    assert(sprite_anim.frames.count == 0);

    Aseprite_Loader :: #import "Aseprite_Loader";
    imgs: []Aseprite_Loader.Frame;
    sprite_info := Aseprite_Loader.load(filename, *imgs);
    if !sprite_info.ok return false;

    total_width:s32 = 0;
    total_height:s32 = 0;
    for imgs {
        total_width += it.width;
        total_height = max(total_height, it.height);
    }

    atlas_img := GenImageColor(total_width, total_height, Color.{0, 0, 0, 0});
    toolbelt.print_time("generating atlas (% x %) for '%'", total_width, total_height, filename);
    
    dest_rect: Rectangle;
    for imgs {
        src_img := LoadImageEx(cast(*Color)it.pixels.data, it.width, it.height);
        defer UnloadImage(src_img);

        src_rect := make_Rectangle(0, 0, it.width, it.height);
        dest_rect.width = cast(float)it.width;
        dest_rect.height = cast(float)it.height;
        ImageDraw(*atlas_img, src_img, src_rect, dest_rect, WHITE);

        frame := array_add(*sprite_anim.frames);
        frame.rect = dest_rect;
        frame.duration_secs = cast(float)it.duration_ms / 1000.0;
        if sprite_info.pivot_x != -1
            frame.offset.x = cast(float)sprite_info.pivot_x;
        if sprite_info.pivot_y != -1
            frame.offset.y = cast(float)sprite_info.pivot_y;
        sprite_anim.total_duration_secs += frame.duration_secs;

        dest_rect.x += dest_rect.width;
    }

    tex := LoadTextureFromImage(atlas_img);

    for imgs
        sprite_anim.frames[it_index].texture = tex;
    
    for sprite_info.tags {
        entry := array_add(*sprite_anim.tags);
        entry.name = copy_string(it.name);

        // TODO: make or find a subslice function 
        entry.frames.data = sprite_anim.frames.data + it.from_frame;
        entry.frames.count = it.to_frame - it.from_frame + 1;

        for * tag_frame: entry.frames
            entry.tag_duration_secs += tag_frame.duration_secs;
    }

    return true;
}

#scope_file
#import "raylib";
#import "Basic";
toolbelt :: #import "toolbelt";
Math :: #import "Math";