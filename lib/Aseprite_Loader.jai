//
// Parse the Aseprite native format (.ase or .aseprite).
//
// thanks ASE docs: https://github.com/aseprite/aseprite/blob/master/docs/ase-file-specs.md
// and NoelFB's gist:  https://gist.github.com/NoelFB/778d190e5d17f1b86ebf39325346fcc5
//
// note this will create RGBA textures even for grayscale or paletted aseprite images.
//

// TODO: cleanup memory management

Special_Layer_Names :: struct {
    _pivot :: "_pivot";
}

Color_Mode :: enum u16 { // color depth (bits per pixel)
    Indexed   :: 8;
    Grayscale :: 16;
    RGBA      :: 32;
}

Header :: struct {
    // size_of(Header) is not correct--jai's packing rules don't work for
    // us here, so below we read the fields manually.
    size: u32;
    magic_number: u16;
    num_frames: u16;
    width: u16;
    height: u16;
    bits_per_pixel: Color_Mode;
    flags: u32;
    speed: u16;
    pad_1: u32;
    pad_2: u32;
    transparent_color_index: u8;
    ignore: [3]u8;
    num_colors: u16;
    pixel_width: u8;
    pixel_height: u8;

    grid_x_pos: s16;
    grid_y_pos: s16;

    grid_width: u16;
    grid_height: u16;

    future: [84]u8;
}

Chunk_Type :: enum u16 {
    OLD_PALETTE_1   :: 0x0004;
    OLD_PALETTE_2   :: 0x0011;
    LAYER           :: 0x2004;
    CEL             :: 0x2005;
    CEL_EXTRA       :: 0x2006;
    COLOR_PROFILE   :: 0x2007;
    MASK_DEPRECATED :: 0x2016;
    PATH_NEVER_USED :: 0x2017;
    FRAME_TAGS      :: 0x2018;
    PALETTE         :: 0x2019;
    USER_DATA       :: 0x2020;
    SLICE           :: 0x2022;
}

Old_Palette_1 :: struct {}
Old_Palette_2 :: struct {}

Layer_Type :: enum u16 {
    Normal :: 0;
    Group  :: 1;
}

Layer :: struct {
    Flags :: enum u16 {
        Visible             :: 1;
        Editable            :: 2;
        Lock_Movement       :: 4;
        Background          :: 8;
        Prefer_Linked_Cells :: 16;
        Group_Collapsed     :: 32;
        Reference_Layer     :: 64;
    }

    flags: Flags;
    type: Layer_Type;
    child_level: u16;
    blend_mode: u16;
    opacity: u8;        // only valid if file header flags field has bit 1 set
    name: string;
}

Palette :: struct {
    num_entries: u32;
    first_change_index: u32;
    last_change_index: u32;
    future: [8]u8;
}

Palette_Entry :: struct {
    flags: u16;
    red: u8;
    green: u8;
    blue: u8;
    alpha: u8;
}

Cel_Type :: enum u16 {
    Raw        :: 0;
    Linked     :: 1;
    Compressed :: 2;
}

Cel :: struct {
    layer_index: u16;
    x: s16;
    y: s16;
    opacity: u8;

    width: u16;
    height: u16;

    pixels: []Color;
}

Frame_Header :: struct {
    bytes_in_frame: u32;
    magic_number: u16;
    num_chunks_old: u16; //Old field which specifies the number of "chunks" in this frame. If this value is 0xFFFF, we might have more chunks to read in this frame (so we have to use the new field)
    duration_ms: u16;
    future: [2]u8;
    num_chunks: u32; //New field which specifies the number of "chunks" in this frame (if this is 0, use the old field)
}


Buffer :: struct { 
    bytes: []u8;
    offset: int; // TODO: Lose the offset and just advance the slice as we parse.
}

Color :: struct {
    r, g, b, a: u8;
    #place r; int_val: u32;
}

Frame :: struct {
    width: s32;
    height: s32;
    pixels: []Color; // rgba

    duration_ms: u16;

    cels: [..]Cel;
}

sprite_width  :: (frame: *Frame) -> int { return frame.width; }
sprite_height :: (frame: *Frame) -> int { return frame.height; }

blend_normal :: (dest: *Color, src: Color, opacity: u8) {
    r, g, b, a: s32;

    if dest.a == 0 {
        r = src.r;
        g = src.g;
        b = src.b;
        a = src.a;
    } else if src.a == 0 {
        r = dest.r;
        g = dest.g;
        b = dest.b;
        a = dest.a;
    } else {
        // TODO: this is all hacked together from wikipedia and very inefficient
        // and probably wrong.
        src_a:float = cast(float)src.a / 255.0 * (cast(float)opacity / 255.0);
        dest_a:float = cast(float)dest.a / 255.0;

        a_f:float = src_a + dest_a * (1.0 - src_a);

        r = cast(s16)((src.r * src_a + dest.r * dest_a * (1 - src_a)) / a_f);
        g = cast(s16)((src.g * src_a + dest.g * dest_a * (1 - src_a)) / a_f);
        b = cast(s16)((src.b * src_a + dest.b * dest_a * (1 - src_a)) / a_f);

        a = cast(s16)(a_f * 255);
    }

    if a == 0 {
        r = 0;
        g = 0;
        b = 0;
    }

    dest.r = cast(u8)r;
    dest.g = cast(u8)g;
    dest.b = cast(u8)b;
    dest.a = cast(u8)a;

    //print("rgba: % % % %\n", r, g, b, a);
}

// Apply a cel's pixels to the frame, using its layer's blendmode and alpha.
cel_to_frame :: (frame: *Frame, cel: *Cel, layer: *Layer) {
    opacity := cast(u8)((cel.opacity / 255.0) * (layer.opacity / 255.0) * 255.0);
    blend := layer.blend_mode;
    sprite_w := cast(s16)sprite_width(frame);

    for sx: cast(s64)0..cast(s64)cel.width - 1 {
        dx :s64 = cast(s64)cel.x + cast(s64)sx;
        dy :s64 = cast(s64)cel.y * cast(s64)sprite_w;

        sy := 0;
        for i: 0..cel.height - 1 {
            dest := *frame.pixels[dx + dy];
            src  := cel.pixels[sx + sy];
            blend_normal(dest, src, opacity);
            sy += cast(s64)cel.width;
            dy += sprite_w;
        }
    }
}

// Convert a byte array into a Color array, using the specified Aseprite mode and palette.
bytes_to_pixels :: (bytes: []u8, pixels: []Color, mode: Color_Mode, palette: []Color) {
    len := pixels.count;
    if #complete mode == {
        case .RGBA;
            p := 0;
            b := 0;
            while p < len {
                pixels[p].r = cast(u8)(cast(float)bytes[b + 0] * bytes[b + 3] / 255.0);
                pixels[p].g = cast(u8)(cast(float)bytes[b + 1] * bytes[b + 3] / 255.0);
                pixels[p].b = cast(u8)(cast(float)bytes[b + 2] * bytes[b + 3] / 255.0);
                pixels[p].a = bytes[b + 3];
                p += 1;
                b += 4;
            }
        case .Grayscale;
            p := 0;
            b := 0;
            while p < len {
                pixels[p].r = cast(u8)(cast(float)bytes[b + 0] * bytes[b + 1] / 255.0);
                pixels[p].g = pixels[p].r;
                pixels[p].b = pixels[p].r;
                pixels[p].a = bytes[b + 1];

                p += 1;
                b += 2;
            }
        case .Indexed;
            for p: 0..len - 1
                pixels[p] = palette[p];
    }
}

Tag :: struct {
    Loop_Type :: enum u8 {
        Forward   :: 0;
        Reverse   :: 1;
        Ping_Pong :: 2;
    }

    from_frame: u16;
    to_frame:   u16;
    loop_type:  Loop_Type;
    color:      Color;
    name:       string;
}

Sprite_Info :: struct {
    ok: bool;
    pivot_x: s16 = -1;
    pivot_y: s16 = -1;
    tags: [..]Tag;
}

load :: (filename: string, raw_frames: *[]Frame) -> Sprite_Info {
    info: Sprite_Info;

    bytes, ok := File.read_entire_file(filename);
    if !ok {
        print("cannot read: %\n", filename);
        return info;
    }

    buf: Buffer;
    buf.bytes = cast([]u8)bytes;
    buf.offset = 0;

    b := *buf;

    header: Header;
    {
        using header;

        size = read_DWORD(b); // file size
        magic_number = read_WORD(b);
        if magic_number != 0xA5E0 {
            print("invalid ASE Header magic number");
            return info;
        }
        num_frames     = read_WORD(b);
        width          = read_WORD(b);
        height         = read_WORD(b);
        bits_per_pixel = read_or_panic(b, Color_Mode);
        flags          = read_DWORD(b);
        speed          = read_WORD(b); // deprecated
        pad_1          = read_DWORD(b);
        pad_2          = read_DWORD(b);
        transparent_color_index = read_BYTE(b);
        read(b, [3]u8); // ignore
        num_colors     = read_WORD(b);
        pixel_width    = read_BYTE(b);
        pixel_height   = read_BYTE(b);
        grid_x_pos     = read_SHORT(b);
        grid_y_pos     = read_SHORT(b);
        grid_width     = read_WORD(b);
        grid_height    = read_WORD(b);
        read(b, [84]u8); // future
    }

    assert(header.bits_per_pixel == .RGBA || header.bits_per_pixel == .Grayscale || header.bits_per_pixel == .Indexed);

    bytes_per_pixel := cast(u64)header.bits_per_pixel / 8;
    assert(bytes_per_pixel == 4 || bytes_per_pixel == 2 || bytes_per_pixel == 1);
    assert(bytes_per_pixel == 4, "TODO: implement other bpp");

    (<<raw_frames) = NewArray(header.num_frames, Frame);

    // We keep a fake Frame around to stamp cels in the '_pivot' layer to.
    pivot_frame: *Frame; 
    defer {
        if pivot_frame != null {
            deinit_Frame(pivot_frame);
            free(pivot_frame);
        }
    }

    palette: [256]Color;
    layers: [..]Layer;

    for frame_i: 0..header.num_frames-1 {
        #assert(size_of(Frame_Header) == 16);
        frame_header, frame_header_ok := read(*buf, Frame_Header);

        if !frame_header_ok {
            print("not enough bytes for frame header\n");
            return info;
        }

        if frame_header.magic_number != 0xF1FA {
            print("Frame_Header invalid magic number, got %\n", frame_header.magic_number);
            return info;
        }

        num_chunks := frame_header.num_chunks;
        if num_chunks == 0 num_chunks = cast(u32)frame_header.num_chunks_old;
        assert(num_chunks > 0);

        frame := *((<<raw_frames)[frame_i]);
        {
            init_Frame(frame, header.width, header.height);
            frame.duration_ms = frame_header.duration_ms;
        }

        for _: 0..num_chunks-1 {
            chunk_start := buf.offset;
            chunk_size := read_DWORD(b);
            chunk_type := read_or_panic(*buf, Chunk_Type);
            chunk_end := chunk_start + cast(int)chunk_size;
            if chunk_type == {
                case .LAYER;
                    last_layer := array_add(*layers);
                    {
                        using last_layer;
                        flags       = read(b, Layer.Flags);
                        type        = read(b, Layer_Type);
                        child_level = read_WORD(b);
                        read_WORD(b); // unused width
                        read_WORD(b); // unused height
                        blend_mode  = read_WORD(b);
                        opacity     = read_BYTE(b);
                        read(b, [3]u8); // future
                        name        = read_string(b);
                    }
                case .OLD_PALETTE_1;
                    num_packets := read_or_panic(*buf, u16);
                    for _: 0..num_packets-1 {
                        num_entries_to_skip := read_or_panic(*buf, u8);
                        num_colors := read_or_panic(*buf, u8);
                        num_colors_int :int = cast(int)num_colors;
                        if num_colors == 0 num_colors_int = 256;
                        for _: 0..num_colors_int-1 {
                            color_r := read_BYTE(b);
                            color_g := read_BYTE(b);
                            color_b := read_BYTE(b);
                        }
                    }
                case .PALETTE;
                    palette := read_or_panic(*buf, Palette);
                    for _: 0..palette.num_entries-1 {
                        entry := read_or_panic(*buf, Palette_Entry);
                        if entry.flags & 1 != 0 {
                            entry_name := read_string(*buf);
                        }
                    }
                case .COLOR_PROFILE;
                    Color_Profile_Type :: enum u16 {
                        No_Color_Profile     :: 0;
                        sRGB                 :: 1;
                        Embedded_ICC_Profile :: 2;
                    }
                    Color_Profile_Flags :: enum_flags u16 {
                        Special_Fixed_Gamma :: 1;
                    }
                    profile_type := read(b, Color_Profile_Type);
                    flags        := read(b, Color_Profile_Flags);
                    gamma        := read(b, float);
                    read(b, [8]u8); // future
                    if profile_type == .Embedded_ICC_Profile {
                        profile_data := read_string(b, u32);
                        print("read icc profile: %\n", profile_data);
                    }
                    // TODO: actually handle and do something with the color profile here.
                case .FRAME_TAGS;
                    n_tags := read_WORD(b);
                    read(b, [8]u8);
                    for it_index: 0..n_tags - 1 {
                        tag := array_add(*info.tags);
                        using tag;

                        from_frame     = read_WORD(b);
                        to_frame       = read_WORD(b);
                        loop_type      = read(b, Tag.Loop_Type);
                        read(b, [8]u8); // future
                        color.r        = read_BYTE(b);
                        color.g        = read_BYTE(b);
                        color.b        = read_BYTE(b);
                        read_BYTE(b);   // extra byte (zero)
                        name           = read_string(b);
                    }

                case .CEL;
                    cel: Cel;
                    cel_type: Cel_Type;
                    {
                        using cel;
                        layer_index = read_WORD(b);
                        x           = read_SHORT(b);
                        y           = read_SHORT(b);
                        opacity     = read_BYTE(b);
                        cel_type    = read(b, Cel_Type);
                        read(b, [7]u8); // future padding
                    }

                    if cel_type == .Raw || cel_type == .Compressed {
                        cel.width  = read_WORD(b);
                        cel.height = read_WORD(b);
                        count := cast(s64)cel.width * cast(s64)cel.height * cast(s64)bytes_per_pixel;

                        bytes := NewArray(count, u8);
                        defer array_free(bytes);

                        if cel_type == .Raw {
                            // TODO: @Speed we don't actually need a copy here
                            memcpy(bytes.data, buf.bytes.data + buf.offset, count);
                        } else if cel_type == .Compressed {
                            num_compressed_bytes := chunk_end - buf.offset;

                            compressed: []u8;
                            compressed.data = buf.bytes.data + buf.offset;
                            compressed.count = num_compressed_bytes;

                            buf.offset += num_compressed_bytes;

                            //print("decompressing a % x % x % image from % bytes...\n", cel.width, cel.height, bytes_per_pixel, num_compressed_bytes);
                            ok := uncompress(compressed, bytes);
                            if !ok {
                                print("error uncompressing cel data\n");
                                return info;
                            }
                        } else {
                            assert(false);
                        }

                        cel.pixels = NewArray(cast(s64)cel.width * cast(s64)cel.height, Color);
                        bytes_to_pixels(bytes, cel.pixels, header.bits_per_pixel, palette);

                        // TODO: @Speed don't allocate and call bytes_to_pixels for
                        // invisible or ignored layers.

                        cel_layer := *layers[cel.layer_index];
                        if cel_layer.name == Special_Layer_Names._pivot {
                            if pivot_frame == null {
                                // Lazily create the pivot frame only if we need to.
                                pivot_frame = New(Frame);
                                init_Frame(pivot_frame, header.width, header.height);
                            }
                            cel_to_frame(pivot_frame, *cel, cel_layer);
                        } else if cel_layer.flags & .Visible {
                            cel_to_frame(frame, *cel, cel_layer);
                        }
                    } else {
                        assert(false, "unsupported cel type %", cel_type);
                    }
                    
                    array_add(*frame.cels, cel);
                case;
                    assert(false, "TODO: implement chunk type %", chunk_type);
                    print("ignored chunk type %\n", chunk_type);
                    buf.offset = chunk_start + cast(int)chunk_size;
            }

            actually_read_size := buf.offset - cast(int)chunk_start;
            assert(actually_read_size == cast(int)chunk_size,
                tprint("expected to read % bytes for chunk, but actually read %", chunk_size, actually_read_size));
        }
    }

    // If we had a "_pivot" layer, find the middle point of all its pixels
    // and save that as the sprite's "pivot". (passed as 'offset' in raylib).
    if pivot_frame != null {
        c := 0;
        total := 0;
        min_pt: [2]s32 = .[9999999, 9999999];
        max_pt: [2]s32 = .[0, 0];
        for y: 0..pivot_frame.height-1 {
            for x: 0..pivot_frame.width-1 {
                color := pivot_frame.pixels[c];
                c += 1;

                if color.a > 0 {
                    total += 1;
                    min_pt[0] = min(min_pt[0], x);
                    min_pt[1] = min(min_pt[1], y);

                    max_pt[0] = max(max_pt[0], x);
                    max_pt[1] = max(max_pt[1], y);
                }
            }
        }

        if total > 0 {
            info.pivot_x = cast(s16)(cast(float)(min_pt[0] + max_pt[0]) / 2.0);
            info.pivot_y = cast(s16)(cast(float)(min_pt[1] + max_pt[1]) / 2.0);
        }
    }

    info.ok = true;
    return info;
}

#scope_file

#import "Basic";
File :: #import "File";

miniz :: #import "miniz";

read_or_panic :: inline (buf: *Buffer, $T: Type) -> T {
    val, ok := read(buf, T);
    assert(ok, "not enough bytes to read % bytes", size_of(T));
    return val;
}

read_bytes :: (buf: *Buffer, num_bytes: int) -> []u8 {
    assert(num_bytes > 0);
    assert(buf.offset + num_bytes < buf.bytes.count);

    slice: []u8;
    slice.data = buf.bytes.data + buf.offset;
    slice.count = num_bytes;

    buf.offset += num_bytes;

    return slice;
}

read_string :: (buf: *Buffer, $count_type := u16) -> string {
    length := cast(int)read_or_panic(buf, count_type);
    assert(length < 1000, "string of length more than 'sane' value 1000");

    s: string;
    s.data = buf.bytes.data + buf.offset;
    s.count = length;

    buf.offset += length;
    return s;
}

read :: (buf: *Buffer, $T: Type) -> (value:T, ok:bool) {
    total := buf.bytes.count;
    to_read := size_of(T);
    value: T;

    //print("---> read(%, %)\n", to_read, T);
    //defer print("<-- %\n", value);

    ok: bool;
    if buf.offset + to_read > total {
        ok = false;
    } else {
        ok = true;
        value = <<(cast(*T)(*buf.bytes[buf.offset]));
        buf.offset += to_read;
    }

    return value, ok;
}

// to match ASE docs
read_DWORD :: #bake_arguments read_or_panic(T = u32);
read_WORD  :: #bake_arguments read_or_panic(T = u16);
read_SHORT :: #bake_arguments read_or_panic(T = s16);
read_BYTE  :: #bake_arguments read_or_panic(T = u8);

uncompress :: (compressed_bytes: []u8, dest: []u8) -> bool {
    //print("uncompress dest: %", dest.count);

    // we assume dest has exactly enough space for the uncompresesd data here.
    // see the assert
    asked_for_len := dest.count;
    dest_len: u64 = cast(u64)dest.count;

    DEBUG_COMPRESSION :: false;

    if DEBUG_COMPRESSION {
        to_print: []u8;
        to_print.data = compressed_bytes.data;
        to_print.count = 256;
        toolbelt::#import "toolbelt";
        print("---- % bytes total, first %:\n", compressed_bytes.count, to_print.count);

        File.write_entire_file("test_compressed_data.dat", compressed_bytes.data, compressed_bytes.count);

        toolbelt.print_hex_bytes(to_print);
    }

    ret_code := miniz.uncompress(dest.data, *dest_len, compressed_bytes.data, cast(u64)compressed_bytes.count);
    if ret_code == .BUF_ERROR {
        print("dest.count is %, dest_len is %\n", dest.count, dest_len);
    }

    assert(dest_len == cast(u64)asked_for_len);
    if ret_code != .OK
        print("error from miniz: %\n", ret_code);

    return ret_code == .OK;
}

init_Frame :: (frame: *Frame, width: s32, height: s32) {
    assert(width > 0 && height > 0);
    assert(width < 10000 && height < 10000);
    frame.width = width;
    frame.height = height;
    frame.pixels = NewArray(width * height, Color);
}

deinit_Frame :: (frame: *Frame) {
    array_free(frame.pixels);
}
