#scope_file
File :: #import "File";
#import "Basic";
miniz :: #import "miniz";

#scope_module

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

Layer :: struct {
    flags: u16;
    type: u16;
    child_level: u16;
    default_width: u16;
    default_height: u16;
    blend_mode: u16;
    opacity: u8;
    future: [3]u8;
    //name: cstring;
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
    type: Cel_Type;
    future: [7]u8;
}

Header :: struct {
    size: u32;
    magic_number: u16;
    num_frames: u16;
    width: u16;
    height: u16;
    bits_per_pixel: u16;
    flags: u32;
    speed: u16;
    pad_1: u32;
    pad_2: u32;
    transparent_color_index: u8;
    ignore: [3]u8;
    num_colors: u16;
    pixel_width: u8;
    pixel_height: u8;
    future: [92]u8;
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
    offset: int;
}

read_or_panic :: inline (buf: *Buffer, $T: Type) -> T {
    val, ok := read(buf, T);
    assert(ok, tprint("not enough bytes to read % bytes", size_of(T)));
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

read_string :: (buf: *Buffer) -> string {
    length := cast(int)read_or_panic(buf, u16);
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

err_print_return :: (s: string, msg: ..Any) -> bool {
    print(s, ..msg);
    return false;
}

Raw_Image :: struct {
    width: int;
    height: int;
    pixels: []u8; // rgba
}

load :: (filename: string, raw_frames: *[]Raw_Image) -> bool {
    bytes, ok := File.read_entire_file(filename);
    if !ok return err_print_return("cannot read", filename);

    buf: Buffer;
    buf.bytes = cast([]u8)bytes;
    buf.offset = 0;

    header, header_ok := read(*buf, Header);
    if !header_ok return err_print_return("not enough bytes for Header");
    if header.magic_number != 0xA5E0 return err_print_return("invalid Header magic number");

    bytes_per_pixel := header.bits_per_pixel / 8;;
    assert(bytes_per_pixel == 4 || bytes_per_pixel == 2 || bytes_per_pixel == 1);
    assert(bytes_per_pixel == 4, "TODO: implement other bpp");

    print("NUM FRAMES: %\n", header.num_frames);

    <<raw_frames = NewArray(header.num_frames, Raw_Image);

    for frame_i: 0..header.num_frames-1 {
        frame_header, frame_header_ok := read(*buf, Frame_Header);

        if !frame_header_ok return err_print_return("not enough bytes for frame header");
        if frame_header.magic_number != 0xF1FA return err_print_return("Frame_Header invalid magic number, got ", frame_header.magic_number);

        num_chunks := frame_header.num_chunks;
        if num_chunks == 0 num_chunks = cast(u32)frame_header.num_chunks_old;

        //println("FRAME", frame_i);

        raw_image := *((<<raw_frames)[frame_i]);
        raw_image.width = cast(int)header.width;
        raw_image.height = cast(int)header.height;
        raw_image.pixels = NewArray(header.width * header.height * 4, u8);

        for _: 0..num_chunks-1 {
            chunk_start := buf.offset;
            chunk_size := read_or_panic(*buf, u32);
            chunk_type := read_or_panic(*buf, Chunk_Type);
            chunk_end := chunk_start + cast(int)chunk_size;
            if chunk_type == {
                case .LAYER;
                    _unused_layer /*layer*/ := read_or_panic(*buf, Layer);
                    _unused_name /*layer_name*/ := read_string(*buf);
                    //println("layer", layer_name, layer);
                case .OLD_PALETTE_1;
                    num_packets := read_or_panic(*buf, u16);
                    for _: 0..num_packets-1 {
                        num_entries_to_skip := read_or_panic(*buf, u8);
                        print("num_entries_to_skip %\n", num_entries_to_skip);
                        num_colors := read_or_panic(*buf, u8);
                        num_colors_int :int = cast(int)num_colors;
                        if num_colors == 0 num_colors_int = 256;
                        print("num colors %\n", num_colors_int);
                        for _: 1..num_colors_int {
                            r := read_or_panic(*buf, u8);
                            g := read_or_panic(*buf, u8);
                            b := read_or_panic(*buf, u8);
                            print("% % %\n", r, g, b);
                        }
                    }
                case .PALETTE;
                    palette := read_or_panic(*buf, Palette);
                    print("palette %\n", palette);

                    for _: 0..palette.num_entries-1 {
                        entry := read_or_panic(*buf, Palette_Entry);
                        tprint("entry %\n", entry);
                        if entry.flags & 1 != 0 {
                            entry_name := read_string(*buf);
                            print("  entry name: %\n", entry_name);
                        }
                    }
                case .CEL;
                    cel := read_or_panic(*buf, Cel);
                    //println(cel);
                    if (cel.type) == {
                        case .Raw;
                            width := read_or_panic(*buf, s16);
                            height := read_or_panic(*buf, s16);
                            num_bytes := cast(int)(width * height * cast(s16)bytes_per_pixel);
                            //pixels := mem.slice_ptr(*buf.bytes[buf.offset], num_bytes);
                            buf.offset += num_bytes;
                            //println("width", width);
                            //println("height", height);
                            //println("pixels", pixels.count);
                        case .Linked;
                            assert(false, "unimplemented Linked CEL type");
                        case .Compressed;
                            width := read_or_panic(*buf, s16);
                            height := read_or_panic(*buf, s16);

                            compressed: []u8;
                            compressed.data = buf.bytes.data + buf.offset;
                            compressed.count = chunk_end - buf.offset;

                            buf.offset += chunk_end - buf.offset;
                            pixels, err := uncompress(compressed);
                            if err != .OK {
                                print("error uncompressing CEL data %\n", err);
                                return false;
                            }

                            for y: 0..height-1 {
                                for x: 0..width-1 {
                                    src_index := y*(width*4) + (x*4);

                                    dest_y := cel.y + y;
                                    dest_x := cel.x + x;

                                    dest_index := (dest_y * cast(s16)header.width * 4) + (dest_x * 4);
                                    raw_image.pixels[dest_index]   = pixels[src_index];
                                    raw_image.pixels[dest_index+1] = pixels[src_index+1];
                                    raw_image.pixels[dest_index+2] = pixels[src_index+2];
                                    raw_image.pixels[dest_index+3] = pixels[src_index+3];
                                }
                            }
                        case;
                            assert(false, tprint("unsupported cel type %", cel.type));
                    }
                case;
                    print("ignored chunk type %\n", chunk_type);
                    buf.offset = chunk_start + cast(int)chunk_size;
            }
            got_size := buf.offset - cast(int)chunk_start;
            assert(got_size == cast(int)chunk_size,
                tprint("expected: % but got: %", chunk_size, got_size));
        }
    }

    return true;
}

uncompress :: (compressed_bytes: []u8, allocator := context.allocator) -> (uncompressed_bytes: []u8, err: miniz.Status_Code) {
    src_len := cast(u64)compressed_bytes.count;
    dest_len := src_len * 50;
    dest := NewArray(cast(s64)dest_len, u8, allocator=allocator); // LEAK
    ret_code := miniz.uncompress(dest.data, *dest_len, compressed_bytes.data, src_len);
    return dest, ret_code;
}

