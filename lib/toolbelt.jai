screenp :: (msg: string, args: ..Any, ident := "", loc := #caller_location) {
    screenlog.screen_print(tprint(msg, ..args), loc=loc);
}

screenp :: (var: Code, ident := "", loc := #caller_location) #expand {
    get_variable_name :: (code : Code) -> string {
        root := compiler_get_nodes(code);
        assert(root.kind == .IDENT, "expected #code root not to be of kind IDENT, but got %", root.kind);
        ident := cast(*Code_Ident) root;
        return ident.name;
    }

    screenp("% = %\n", #run get_variable_name(var), #insert var, ident=ident, loc=loc);
}

sin_min_max :: (val: float, min: float, max: float) -> float {
    sin01 := (sin(val) * 0.5) + 1.0;
    return min + sin01 * (max - min);
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


print_time :: (ident: string, msg: string, args: ..Any) #expand {
    // Measure the time from now until the end of the current scope,
    // printing a message now and then, showing the time it took to
    // get there.

    s := ifx args.count > 0 tprint(msg, ..args) else msg;
    logprint(ident, "%...", s);
    `__print_time_now := GetTime();
    `defer print("took %\n", GetTime() - __print_time_now);
}

draw_texture :: (tex: *Texture, source_rect: Rectangle, dest_rect: Rectangle, origin: Vector2 = .{0, 0}, rotation: float = 0, tint:Color = WHITE) {
    DrawTexturePro(tex, source_rect, dest_rect, origin, rotation, tint);
}

draw_text :: (msg: string, x: $X, y: $Y, size: $S, color := WHITE) {
    msg_z := constant_or_temp_cstring(msg);
    DrawTextEx(GetFontDefault(), msg_z, make_Vector2(x, y), xx size, -2, color);
}

midpoint :: inline (rect: Rectangle) -> Vector2 {
    v: Vector2 = ---;
    v.x = rect.x + rect.width * 0.5;
    v.y = rect.y + rect.height * 0.5;
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
    assert(i != -1, "expected a comma-space in '%'", s);
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

    assert(i != -1, "no sprites with prefix '%' found!", prefix);
    assert(j != -1);

    // TODO: this assumes sprites are sorted alphabetically
    new_slice: []Sprite;
    new_slice.data = *sprites[i];
    new_slice.count = j - i;
    //print("sprites_with_prefix of % total w prefix '%': %\n", sprites.count, prefix, new_slice.count);
    return new_slice;
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
            assert(index != -1, "expected a colon space in '%'", line);

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
    assert(spr.data != null && spr.count > 0);
    assert(spr.count < 500);

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
v3 :: inline (x: float, y: float, z: float) -> Vector3 { return make_vector3(x, y, z); }
v3 :: inline (xy: Vector2, z: float=0) -> Vector3 { return make_vector3(xy.x, xy.y, z); }
v4 :: make_vector4;

rect :: make_Rectangle;

rect_from_points :: (p1: Vector2, p2: Vector2) -> Rectangle {
    x := min(p1.x, p2.x);
    y := min(p1.y, p2.y);

    width := abs(p2.x - p1.x);
    height := abs(p2.y - p1.y);

    return rect(x, y, width, height);
}

get_field_value :: (parent_struct: *$T, $field_name: string, $Field_Type: Type, loc := #caller_location) -> Field_Type {
    // TODO: with better metaprogramming, the caller wouldn't have to specify the Field_Type

    offset :: #run (() -> int {
        ti := type_info(T);
        assert(ti.type == .STRUCT);
        ti_struct := cast(*Type_Info_Struct)ti;
        field := get_field(ti_struct, field_name);
        if field == null {
            #import "Compiler";
            compiler_report(tprint("Error: no field named '%' in %", field_name, T));
        }
        return field.offset_in_bytes;
    }());

    assert(parent_struct != null);
    base_ptr := cast(*u8)parent_struct;
    return <<cast(*Field_Type)(base_ptr + offset);
}

get_parent_struct :: ($P: Type, child_ptr: *$C) -> *P {
    // Given parent struct P which embeds a child struct C once directly, and a
    // pointer to the child struct, returns a pointer to the parent.

    offset :: #run get_offset(P, type_info(C));
    return cast(*P)((cast(*void)child_ptr) - offset);

    get_offset :: ($P: Type, child_ti: *Type_Info) -> s64 {
        ti := type_info(P);
        assert(ti.type == .STRUCT, "%", <<ti);
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
} @test



round :: (f: float) -> float {
    frac_part := fmod(f, 1);
    res := cast(float)cast(int)f;
    if frac_part >= 0.5 res += 1;
    return res;
}

test_round :: () {
    assert(round(4.2) == 4, "%", round(4.2));
    assert(round(4.6) == 5, "%", round(4.6));
    assert(round(-1) == -1, "%", round(-1));
}

// TODO: not sure if 'Latch' is the right name for this thing.
Latch :: struct(T: Type) {
    using current: T;
    last: T;

    Value_Type :: T;
}

difference :: (using latch: $L) -> L.Value_Type {
    return current - last;
}

set_if_different :: (using latch: *Latch, val: $T) -> (different: bool, last_value: T) {
    if last != val {
        last_val := last;
        last = current;
        current = val;
        return true, last_val;
    }

    return false, last;
}

Maybe :: struct(T: Type) {
    using value: T;
    has_value: bool;
}


print_field_offsets :: ($type: Type) {
    // useful for checking if a struct's field match a serialized format

    ti := type_info(type);
    assert(ti.type == .STRUCT);
    ti_struct := cast(*Type_Info_Struct)ti;

    print("%:\n", type);
    for * ti_struct.members {
        field_size := -1;
        if it_index < ti_struct.members.count - 1 {
            next := *ti_struct.members[it_index + 1];
            field_size = next.offset_in_bytes - it.offset_in_bytes;
        }

        tabs := ifx it.name.count > 6 then "\t" else "\t\t";
        print("  % (%): % %\n", it.name, field_size, tabs, it.offset_in_bytes);
    }
}

print_hex_bytes :: (data: *void, size_in_bytes: int) {
    s: []u8;
    s.data = data;
    s.count = size_in_bytes;
    print_hex_bytes(s);
}

print_hex_bytes :: (data: []u8) {
    count := 0;
    for data {
        print("% ", formatInt(it, base=16, minimum_digits=2));
        count += 1;
        if count >= 8 {
            count = 0;
            print("\n");
        }
    }
    print("\n");
}


print_locals :: (code: Code) #expand {
    generate_print_statements :: (code: Code) -> Code {
        root, expressions := compiler_get_nodes(code);

        // Collect all the idents.
        idents: [..]string;
        for expressions
            if it.kind == .IDENT
                array_add(*idents, (cast(*Code_Ident)it).name);

        // For each one, make a print statement.
        statements := NewArray(idents.count, *Code_Node);
        for idents {
            proc_call := New(Code_Procedure_Call);
            proc_call.kind = .PROCEDURE_CALL;
            proc_call.procedure_expression = New_Ident("print");

            arguments_unsorted: [..]Code_Argument;
            array_add(*arguments_unsorted,
                make_Code_Argument(make_string_literal(tprint("%: %%\n", it))),
                make_Code_Argument(New_Ident(it, Code_Ident.HAS_SCOPE_MODIFIER))
            );
            proc_call.arguments_unsorted = arguments_unsorted;

            arguments_sorted: [..]*Code_Node;
            for arguments_unsorted
                array_add(*arguments_sorted, it.expression);
            proc_call.arguments_sorted = arguments_sorted;

            statements[it_index] = proc_call;
        }

        block := New(Code_Block);
        block.kind = .BLOCK;
        block.parent = null;
        block.statements = statements;
        block.block_type = Code_Block.Block_Type.IMPERATIVE;

        return compiler_get_code(block);
    }

    #insert_internal #run generate_print_statements(code);
}


make_Code_Argument :: (expression: *Code_Node, name: *Code_Ident = null) -> Code_Argument {
    arg: Code_Argument;
    arg.expression = expression;
    arg.name = name;
    return arg;
}

New_Ident :: (name: string, flags: u32 = 0) -> *Code_Ident {
    ident := New(Code_Ident);
    ident.kind = .IDENT;
    ident.name = name;
    ident.flags = flags;
    return ident;
}

//#run test_round();

#scope_file

#import "Basic";
#import "Text_File_Handler";
#import "config";
#import "String";
#import "raylib";
#import "raymath";
#import "Compiler";
#import "Math";
screenlog :: #import "screenlog";
platform :: #import "platform";
