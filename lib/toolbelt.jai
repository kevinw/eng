#placeholder state;

#import "Basic";
#import "Text_File_Handler";
#import "config";
#import "String";
#import "raylib";
#import "raymath";
Math :: #import "Math";
platform :: #import "platform";

window_rect: Rectangle;

ToggleFakeFullscreen :: () {
    WINDOW_WIDTH :: 1200;
    WINDOW_HEIGHT :: 675;

    // raylib only does exclusive fullscreen, so here's a windowed fullscreen
    // implementation.
    monitor := 0;
    monitor_w := GetMonitorWidth(0);
    monitor_h := GetMonitorHeight(0);

    pos := GetWindowPosition();
    w, h := platform.GetWindowSize(GetWindowHandle());

    if platform.IsWindowBorderless(GetWindowHandle()) {
        platform.SetWindowBorderless(GetWindowHandle(), false);
        if window_rect.x <= 0 window_rect.x = 50;
        if window_rect.y <= 0 window_rect.y = 50;
        if window_rect.width == 0 window_rect.width = WINDOW_WIDTH;
        if window_rect.height == 0 window_rect.height = WINDOW_HEIGHT;


        SetWindowPosition(xx window_rect.x, xx window_rect.y);
        SetWindowSize(xx window_rect.width, xx window_rect.height);
    } else {
        platform.SetWindowBorderless(GetWindowHandle(), true);
        window_rect = make_Rectangle(pos.x, pos.y, w, h);

        SetWindowPosition(0, 0);
        SetWindowSize(monitor_w, monitor_h);
    }


}

overlaps :: inline (point: Vector2, rect: Rectangle) -> bool #symmetric {
    return CheckCollisionPointRec(point, rect);
}

constant_or_temp_cstring :: inline ($$text: string) -> *u8 {
    c_str: *u8;
    #if is_constant(text)
        if text.data.count > 0
            return text.data;

    return to_temp_c_string(text);
}

to_temp_c_string :: (s: string) -> *u8 {
    result : *u8 = talloc(s.count + 1);
    memcpy(result, s.data, s.count);
    result[s.count] = 0;
    return result;
}

draw_point :: inline (pt: Vector2, size: float, color: Color) {
    DrawRectangleV(pt - v2(size/2.0, size/2.0), v2(size, size), RED);
}

draw_rect_outline :: inline (a: Vector2, b: Vector2, thickness :s32 = 3, color := RED) {
    draw_rect_outline(rect_from_points(a, b), thickness, color);
}

draw_rect_outline :: inline (rect: Rectangle, thickness :s32 = 3, color := RED) {
    DrawRectangleLinesEx(rect, thickness, color);
}

normalize :: Vector2Normalize;

default_font: *Font; // TODO: this is dumb, because when game.dll gets reloaded it needs to reset this pointer back to its new state's default_font value. I wonder if we can put the data segment somewhere manually?

set_default_font :: (font_ptr: *Font) {
    default_font = font_ptr;
}

set_default_font :: (font_ptr: *Font, filename: string) {
    default_font = font_ptr;
    print("loading font...");
    now := GetTime();
    <<default_font = LoadFontEx(constant_or_temp_cstring(filename), xx 40, xx 0, xx 200);
    print("took %\n", GetTime() - now);
}

draw_text :: (msg: string, x: $X, y: $Y, size: $S, color := WHITE) {
    msg_z := constant_or_temp_cstring(msg);
    DrawTextEx(<<default_font, msg_z, make_Vector2(x, y), xx size, -2, color);
}

midpoint :: inline (rect: Rectangle) -> Vector2 {
    v: Vector2 = ---;
    v.x = rect.x + rect.width * 0.5;
    v.y = rect.y + rect.height * 0.5;
    return v;
}

set_shader_val :: (shader: Shader, name: string, val: $T) {
    location := GetShaderLocation(shader, to_temp_c_string(name));
    if location == -1 return; // TODO: should we warn here?

    uniform_type: ShaderUniformDataType;
    #if T == Vector2 || T == [2]float32
        uniform_type = .UNIFORM_VEC2;
    else if T == Vector3 || T == [3]float32
        uniform_type = .UNIFORM_VEC3;
    else if T == Vector4 || T == [4]float32
        uniform_type = .UNIFORM_VEC4;
    else if T == float
        uniform_type = .UNIFORM_FLOAT;
    else
        print("unknown type %", T);

    SetShaderValue(shader, location, *val, uniform_type);
}

Vector2_Scale :: inline (a: Vector2, b: Vector2) -> Vector2 {
    v: Vector2 = ---;
    v.x = a.x * b.x;
    v.y = a.y * b.y;
    return v;
}

Int2 :: struct {
    x: s16;
    y: s16;
}

Sprite :: struct {
    name: string;
    rotate: bool;
    xy: Int2;
    size: Int2;
    orig: Int2;
    offset: Int2;
    index: s16;
}

parse_int2 :: (s: string) -> Int2 {
    i := index_of_string(s, ", ");
    assert(i != -1, tprint("expected a comma-space in '%'", s));
    x_str := slice(s, 0, i);
    y_str := slice(s, i + 2, s.count);
    
    result: Int2;
    result.x = cast(s16)string_to_int(x_str);
    result.y = cast(s16)string_to_int(y_str);
    return result;
}

sprites_with_prefix :: (sprites: []Sprite, prefix: string) -> []Sprite {
    i := -1;
    j := -1;

    for * it, n: sprites {
        if i == -1 && begins_with(it.name, prefix) {
            i = n;
        }
        if i != -1 && !begins_with(it.name, prefix) {
            j = n;
            break;
        }
    }
    if j == -1
        j = sprites.count;

    assert(i != -1, tprint("no sprites with prefix '%' found!", prefix));
    assert(j != -1);

    // TODO: this assumes sprites are sorted alphabetically
    new_slice: []Sprite;
    new_slice.data = *sprites[i];
    new_slice.count = j - i;
    //print("sprites_with_prefix of % total w prefix '%': %\n", sprites.count, prefix, new_slice.count);
    return new_slice;
}

blit_render_texture_to_screen :: (rt: RenderTexture) {
    source_rect := make_Rectangle(0, 0, rt.texture.width, -rt.texture.height);
    dest_rect   := make_Rectangle(0, 0, GetScreenWidth(), GetScreenHeight());
    DrawTexturePro(rt.texture, source_rect, dest_rect, Vector2.{0, 0}, 0, WHITE);
}

parse_spriter_atlas :: (filename: string) -> []Sprite {
    handler: Text_File_Handler;
    handler.do_version_number = false;
    handler.strip_comments_from_ends_of_lines;
    defer deinit(*handler);

    start_file(*handler, "atlas", filename, "atlas parsing", optional=false);
    if handler.failed {
        Log.error();
        Log.print("could not open '%' for parsing\n", filename);
        return .[];
    }

    atlas_image_filename:string;

    sprites: [..]Sprite;
    current_entry: Sprite;
    empty_entry: Sprite;
    for line: *handler {
        if atlas_image_filename.count == 0 {
            atlas_image_filename = line;

            while true {
                line, found := consume_next_line(*handler);
                assert(found);
                if begins_with(line, "repeat: ")
                    break;
            }

            continue;
        }

        if current_entry.name.count == 0 {
            current_entry.name = copy_string(line);
            //print("name: %\n", current_entry.name);
        } else {
            index := index_of_string(line, ": ");
            assert(index != -1, tprint("expected a colon space in '%'", line));

            key := slice(line, 0, index);
            val := slice(line, index + 2, line.count);

            if key == {
                case "rotate"; current_entry.rotate = val == "true";
                case "xy";     current_entry.xy = parse_int2(val);
                case "size";   current_entry.size = parse_int2(val);
                case "orig";   current_entry.orig = parse_int2(val);
                case "offset"; current_entry.offset = parse_int2(val);
                case "index";
                    current_entry.index = cast(s16)string_to_int(val);
                    array_add(*sprites, current_entry);
                    current_entry = empty_entry;
                case;
                    assert(false); // unknown key
            }
        }
    }

    return sprites;
}

sprite_get_rect :: (spr: []Sprite, timer: float64, fps: int, flip_x := false) ->
    (rect: Rectangle, offset: Vector2, sprite_index: int)
{
    sprite_index := cast(int)(timer * fps);
    while sprite_index >= spr.count sprite_index -= spr.count;
    s := *spr[sprite_index];
    offset := v2(s.offset.x, s.offset.y);
    if flip_x
        offset.x = cast(float)(-s.size.x - s.offset.x);
    return rect(s.xy.x, s.xy.y, s.size.x, s.size.y), offset, sprite_index;
}

sign :: inline (x: $T) -> int {
    if x < cast(T)0 return -1;
    return 1;
}

v2 :: make_Vector2;
rect :: make_Rectangle;

rect_from_points :: (p1: Vector2, p2: Vector2) -> Rectangle {
    x := min(p1.x, p2.x);
    y := min(p1.y, p2.y);

    width := Math.abs(p2.x - p1.x);
    height := Math.abs(p2.y - p1.y);

    return rect(x, y, width, height);
}

get_mouse_world_pos :: (camera: Camera2D, screen_texture: RenderTexture) -> Vector2 {
    rt_multiplier := v2(cast(float)screen_texture.texture.width / GetScreenWidth(),
                        cast(float)screen_texture.texture.height / GetScreenHeight());

    mouse_pos := GetMousePosition();
    mouse_pos = v2(rt_multiplier.x * mouse_pos.x, rt_multiplier.y * mouse_pos.y);
    world_pos := GetScreenToWorld2D(mouse_pos, camera);
    return world_pos;
}

get_parent_struct :: ($P: Type, child_ptr: *$C) -> *P {
    // Given parent struct P which embeds a child struct C once directly, and a
    // pointer to the child struct, returns a pointer to the parent.

    offset :: #run get_offset(P, type_info(C));
    return cast(*P)((cast(*void)child_ptr) - offset);

    get_offset :: ($P: Type, child_ti: *Type_Info) -> s64 {
        ti := type_info(P);
        assert(ti.type == .STRUCT, tprint("%", <<ti));
        ti_struct := cast(*Type_Info_Struct)ti;

        offset: s64 = -1;
        found := false;
        for * ti_struct.members {
            if it.type == child_ti {
                assert(!found, "more than one of this type found");
                found = true;
                offset = it.offset_in_bytes;
            }
        }
        assert(offset != -1, "no child pointer found");
        return offset;
    }
}

test_parent_struct :: () {
    Parent :: struct {
        some_data: int;
        child: Child;
    }

    Child :: struct {
        val: int;
    }

    p: Parent;
    p.some_data = 30;
    p.child.val = 42;

    child_ptr := *p.child;
    parent_ptr := get_parent_struct(Parent, child_ptr);

    assert(*p == parent_ptr);
}

Time: struct {
    now: float64;
    delta_time: float;
};