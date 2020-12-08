// originally from Jai's modules/Render/Bitmap.jai

#import "stb_image";
#import "stb_image_write";
#import "stb_image_resize";

Bitmap :: struct {
    width, height: s32;
    mipmap_count: s32 = 1;

    data: * u8;
    own_data:bool=true;
    length_in_bytes : s64;
    pitch: s32;

    srgb : bool;
    format := Texture_Format.BGRA8;
}


// @@ Rename create_bitmap ?
make_bitmap :: (w: s32, h: s32, format:=Texture_Format.BGRA8) -> *Bitmap {
    bmp := New(Bitmap);
    bitmap_alloc(bmp, w, h, format);

    /*
    //  Debugging code to fill the texture map with a checkerboard.
    int i, j;
    for (j = 0; j < h; j++) {
        for (i = 0; i < w; i++) {
            unsigned char *pixel = data->data + (j * w + i) * 4;
            if ((i * j) & 4) {
                pixel[0] = 0;
                pixel[1] = 0;
                pixel[2] = 0;
                pixel[3] = 255;
            } else {
                pixel[0] = 255;
                pixel[1] = 255;
                pixel[2] = 255;
                pixel[3] = 255;
            }
        }
    }
    */

    return bmp;    
}

deinit :: (bmp: *Bitmap) {
    bitmap_unload(bmp);
}


// @@ Consistency: texture functions tend to place format as the first argument.
bitmap_alloc :: (bmp: *Bitmap, w: s32, h: s32, format: Texture_Format) {
    bitmap_unload(bmp);

    bmp.width = w;
    bmp.height = h;
    bmp.mipmap_count = 1;

    size, pitch := get_image_size(format, w, h);
    bmp.data = alloc(size);
    bmp.length_in_bytes = size;
    bmp.pitch = xx pitch;

    bmp.format = format;
    bmp.srgb = false;
}


bitmap_load :: (bmp: *Bitmap, filepath: string) -> bool {

    w, h, channels : s32;
    data_tmp := stbi_load(temp_c_string(filepath), *w, *h, *channels, 0);

    if data_tmp == null then {
        // @@ Log error, return error message?
        return false;
    }

    // call stbi_image_free() on the data here and copy it into
    // memory alloc'd by the jai program. This is to work-around
    // an issue of calling a different implementation of free()
    // than the one stb_image is linked against, thus crashing.
    // :FreeingBitmapDataFromSTBI:
    defer { stbi_image_free(data_tmp); }

    format: Texture_Format;
    if channels == {
        case 1; format = Texture_Format.R8;
        case 2; format = Texture_Format.RG8;
        case 3; format = Texture_Format.RGB8;
        case 4; format = Texture_Format.RGBA8;
    }

    bitmap_alloc(bmp, w, h, format);

    // Copy one row at a time to fix row alignment.
    dst := bmp.data;
    src := data_tmp;
    for 0..h-1 {
        memcpy(dst, src, bmp.width * channels);
        src += w * channels;    // stb data is stored contiguosly.
        dst += bmp.pitch;
    }

    return true;
}

// @@ Rename bitmap_unload() ?
bitmap_unload :: (using bmp: *Bitmap) {
    width = 0;
    height = 0;
    mipmap_count = 1;

    // :FreeingBitmapDataFromSTBI:
    // We have to call stbi_image_free here because the compiler,
    // the user code, and the DLL may have different libc versions
    // linked in. Calling free() here causes a "Debug Assertion failed!"
    // (_CrtIsValidHeapPointer(block)) message to pop up from Windows
    // when calling this function at compile-time in a Debug build!
    // -josh 21 April 2018
    // @@ IC: Note that this depends on whether the data was allocated with load_bitmap or make_bitmap_data!
    // A work-around has been added to load_bitmap to memcpy the data into memory
    // allocated with the jai allocator. We free the stb_image data there instead. -josh 3 January 2019

    if own_data free(data);
    data = null;
    length_in_bytes = 0;

    srgb = false;    
    format = Texture_Format.Unknown;
}


bitmap_save :: (bmp: *Bitmap, filepath: string, alpha:=false) -> bool {

    if bmp.format != Texture_Format.RGB8 && bmp.format != Texture_Format.RGBA8 {
        return false;
    }

    comp:s32 = 4;
    if bmp.format == Texture_Format.RGB8 comp = 3;
    pitch := bmp.pitch;

    if path_extension(filepath) == {
        case "png"; 
            return stbi_write_png(temp_c_string(filepath), bmp.width, bmp.height, comp, bmp.data, pitch) != 0;
        case "tga";
            return stbi_write_tga(temp_c_string(filepath), bmp.width, bmp.height, comp, bmp.data, pitch) != 0;
        case "bmp";
            return stbi_write_bmp(temp_c_string(filepath), bmp.width, bmp.height, comp, bmp.data, pitch) != 0;
        case "hdr";
            return stbi_write_hdr(temp_c_string(filepath), bmp.width, bmp.height, comp, bmp.data, pitch) != 0;
        case "jpg";
            return stbi_write_jpg(temp_c_string(filepath), bmp.width, bmp.height, comp, bmp.data, pitch, quality=80) != 0;
        case "exr";
            // @@ Use mini-exr writer.
    }
    
    return false;
}


// @@ Name collisions are annoying: I have to name this "bitmap_build_mipmaps" to avoid collision with the "build_mipmaps" argument.
// @@ Add support for alignment parameter?
// The output is always an image with 4-byte aligned rows.
bitmap_build_mipmaps :: (bmp: *Bitmap) {

    channels :s32= 0;
    if bmp.format == {
        case Texture_Format.R8; channels = 1;
        case Texture_Format.RG8; channels = 2;
        case Texture_Format.RGB8; channels = 3;
        case Texture_Format.RGBA8; channels = 4;
    }
    assert(channels != 0, "Unsuported texture format in bitmap_build_mipmaps");

    // Compute texture size with mipmaps.
    w := bmp.width;
    h := bmp.height;
    //size, p := get_image_size(bmp.format, bmp.width, bmp.height, 1, mipmap_count);
    p := (w * channels + 3) & -4;
    size := p * h;
    m := 1;
    while w != 1 || h != 1 {
        w = max(w/2, 1);
        h = max(h/2, 1);
        p = (w * channels + 3) & -4; 
        size += p * h;
        m += 1;
    }

    // Allocate mipmap data.
    data_tmp := alloc(size);

    // Copy first mipmap.
    dst := data_tmp;
    src := bmp.data;
    for 0..h-1 {
        memcpy(dst, src, bmp.width * channels);
        dst += (bmp.width * channels + 3) & -4;
        src += bmp.pitch;
    }

    // Generate mipmaps.
    w = bmp.width;
    h = bmp.height;
    input_w := w;
    input_h := h;
    input_ptr := data_tmp;
    input_pitch := p;
    
    alpha :s32 = -1;
    if channels == 4 alpha = 3;

    while w != 1 || h != 1 {
        w = max(w/2, 1);
        h = max(h/2, 1);
        p = (w * channels + 3) & -4;
        ptr := input_ptr + input_pitch * input_h;

        if bmp.srgb stbir_resize_uint8_srgb(input_ptr, input_w, input_h, input_pitch, ptr, w, h, p, channels, alpha, flags=0);
        else        stbir_resize_uint8(input_ptr, input_w, input_h, input_pitch, ptr, w, h, p, channels);
        
        input_w = w;
        input_h = h;
        input_ptr = ptr;
        input_pitch = p;
    }
    assert(size == input_ptr - data_tmp + p * h * channels);

    // Update bitmap members.
    if bmp.own_data free(bmp.data);
    bmp.data = data_tmp;
    bmp.length_in_bytes = size;
    bmp.pitch = bmp.width * channels;
    bmp.mipmap_count = cast(u16) m;
}




// Transform from RGBA16F or RGBA32F to RGBA8F
bitmap_tone_map :: (bmp: *Bitmap, exposure:=1.0, alpha_scale:=1.0) -> bool {
    assert(bmp.mipmap_count == 1);
    if (bmp.format != Texture_Format.RGBA16F) return false;

    new_size := 4 * bmp.width * bmp.height;
    new_data : *u8 = alloc(4 * bmp.width * bmp.height);

    for bitmap_pixels(bmp, [4]u16) {
        r := half_to_float(it[0]);
        g := half_to_float(it[1]);
        b := half_to_float(it[2]);
        a := half_to_float(it[3]);

        if r < 0 || g < 0 || b < 0 {
            r, g, b = 0, 1, 0;
        }
        if !is_finite(r) || !is_finite(g) || !is_finite(b) {
            r, g, b = 1, 0, 0;
        }
        if a < 0 || !is_finite(a) {
            r, g, b = 1, 0, 1;
            a = 0;
        }

        // Tone map.
        r, g, b *= exposure;
        r = 1 - exp(-r);
        g = 1 - exp(-g);
        b = 1 - exp(-b);

        a *= alpha_scale;

        ir := cast(u8) clamp(r*255, 0, 255);
        ig := cast(u8) clamp(g*255, 0, 255);
        ib := cast(u8) clamp(b*255, 0, 255);
        ia := cast(u8) clamp(a*255, 0, 255);

        new_data[4*it_index+0] = ir;
        new_data[4*it_index+1] = ig;
        new_data[4*it_index+2] = ib;
        new_data[4*it_index+3] = ia;
    }

    if bmp.own_data free(bmp.data);
    bmp.format = Texture_Format.RGBA8;
    bmp.data = new_data;
    bmp.length_in_bytes = new_size;
    bmp.own_data = true;

    return true;
}


// Convenience function to iterate over bitmap pixels.
bitmap_pixels :: (bmp: *Bitmap, $T: Type) -> []T {
    pixels: []T = ---;
    pixels.count = bmp.width * bmp.height; // @@ This is assuming 1 byte pitch alignment.
    pixels.data = xx bmp.data;
    return pixels;
}




#scope_file


/*

// miniexr.cpp - v0.1 - public domain - 2012 Aras Pranckevicius / Unity Technologies
//
// Writes OpenEXR files out of half-precision RGBA data.
//
// Only tested on Windows (VS2008) and Mac (gcc 4.2), little endian.
// Testing status: "works for me".

// https://github.com/aras-p/miniexr/blob/master/miniexr.cpp

// Writes EXR into a memory buffer.
// Input: (width) x (height) image, 8 bytes per pixel (R,G,B,A order, 16 bit float per channel).
// Returns memory buffer with .EXR contents and buffer size in outSize. free() the buffer when done with it.
miniexr_write :: (width: u32, height: u32, rgba16f: *void) -> *void, size:int {
    ww := width-1;
    hh := height-1;
    kHeader := {:u8:            // @@ Boo. Array elements must be immutable.
        0x76, 0x2f, 0x31, 0x01, // magic
        2, 0, 0, 0, // version, scanline
        // channels
        #char "c", #char "h", #char "a", #char "n", #char "n", #char "e", #char "l", #char "s", 0,
        #char "c", #char "h", #char "l", #char "i", #char "s", #char "t", 0,
        55, 0, 0, 0,
        #char "B", 0, 1,0,0,0, 0, 0,0,0,1,0,0,0,1,0,0,0, // R, half
        #char "G", 0, 1,0,0,0, 0, 0,0,0,1,0,0,0,1,0,0,0, // G, half
        #char "R", 0, 1,0,0,0, 0, 0,0,0,1,0,0,0,1,0,0,0, // B, half
        0,
        // compression
        #char "c", #char "o", #char "m", #char "p", #char "r", #char "e", #char "s", #char "s", #char "i", #char "o", #char "n", 0,
        #char "c", #char "o", #char "m", #char "p", #char "r", #char "e", #char "s", #char "s", #char "i", #char "o", #char "n", 0,
        1, 0, 0, 0,
        0, // no compression
        // dataWindow
        #char "d", #char "a", #char "t", #char "a", #char "W", #char "i", #char "n", #char "d", #char "o", #char "w", 0,
        #char "b", #char "o", #char "x", #char "2", #char "i", 0,
        16, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        (ww&0xFF), ((ww>>8)&0xFF), ((ww>>16)&0xFF), ((ww>>24)&0xFF),
        (hh&0xFF), ((hh>>8)&0xFF), ((hh>>16)&0xFF), ((hh>>24)&0xFF),
        // displayWindow
        #char "d", #char "i", #char "s", #char "p", #char "l", #char "a", #char "y", #char "W", #char "i", #char "n", #char "d", #char "o", #char "w", 0,
        #char "b", #char "o", #char "x", #char "2", #char "i", 0,
        16, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        (ww&0xFF), ((ww>>8)&0xFF), ((ww>>16)&0xFF), ((ww>>24)&0xFF),
        (hh&0xFF), ((hh>>8)&0xFF), ((hh>>16)&0xFF), ((hh>>24)&0xFF),
        // lineOrder
        #char "l", #char "i", #char "n", #char "e", #char "O", #char "r", #char "d", #char "e", #char "r", 0,
        #char "l", #char "i", #char "n", #char "e", #char "O", #char "r", #char "d", #char "e", #char "r", 0,
        1,0,0,0,
        0, // increasing Y
        // pixelAspectRatio
        #char "p", #char "i", #char "x", #char "e", #char "l", #char "A", #char "s", #char "p", #char "e", #char "c", #char "t", #char "R", #char "a", #char "t", #char "i", #char "o", 0,
        #char "f", #char "l", #char "o", #char "a", #char "t", 0,
        4,0,0,0,
        0,0,0x80,0x3f, // 1.0f
        // screenWindowCenter
        #char "s", #char "c", #char "r", #char "e", #char "e", #char "n", #char "W", #char "i", #char "n", #char "d", #char "o", #char "w", #char "C", #char "e", #char "n", #char "t", #char "e", #char "r", 0,
        #char "v", #char "2", #char "f", 0,
        8,0,0,0,
        0,0,0,0, 0,0,0,0,
        // screenWindowWidth
        #char "s", #char "c", #char "r", #char "e", #char "e", #char "n", #char "W", #char "i", #char "n", #char "d", #char "o", #char "w", #char "W", #char "i", #char "d", #char "t", #char "h", 0,
        #char "f", #char "l", #char "o", #char "a", #char "t", 0,
        4,0,0,0,
        0,0,0x80,0x3f, // 1.0f
        // end of header
        0,
    };
    kHeaderSize :: size_of(type_of(kHeader));

    kScanlineTableSize := 8 * height;
    pixelRowSize := width * 3 * 2;
    fullRowSize := pixelRowSize + 8;

    bufSize := kHeaderSize + kScanlineTableSize + height * fullRowSize;
    u8* buf = malloc(bufSize);
    if !buf return null;

    // copy in header
    memcpy (buf, kHeader, kHeaderSize);

    // line offset table
    ofs := kHeaderSize + kScanlineTableSize;
    ptr := buf + kHeaderSize;
    for y: 0..hh {
        ptr[0] = ofs & 0xFF;
        ptr[1] = (ofs >> 8) & 0xFF;
        ptr[2] = (ofs >> 16) & 0xFF;
        ptr[3] = (ofs >> 24) & 0xFF;
        ptr[4] = 0;
        ptr[5] = 0;
        ptr[6] = 0;
        ptr[7] = 0;
        ptr += 8;
        ofs += fullRowSize;
    }

    // scanline data
    src := cast(*u8)rgba16f;
    for y: 0..hh {
        // coordinate
        *ptr++ = y & 0xFF;
        *ptr++ = (y >> 8) & 0xFF;
        *ptr++ = (y >> 16) & 0xFF;
        *ptr++ = (y >> 24) & 0xFF;
        
        // data size
        *ptr++ = pixelRowSize & 0xFF;
        *ptr++ = (pixelRowSize >> 8) & 0xFF;
        *ptr++ = (pixelRowSize >> 16) & 0xFF;
        *ptr++ = (pixelRowSize >> 24) & 0xFF;
        
        // B, G, R
        memcpy (ptr, src, width*6);
        
        chsrc := src + 4;
        for x: 0..ww {
            ptr[0] = chsrc[0];
            ptr[1] = chsrc[1];
            ptr += 2;
            chsrc += 8;
        }
        chsrc = src + 2;
        for x: 0..ww {
            ptr[0] = chsrc[0];
            ptr[1] = chsrc[1];
            ptr += 2;
            chsrc += 8;
        }
        chsrc = src + 0;
        for x: 0..ww {
            ptr[0] = chsrc[0];
            ptr[1] = chsrc[1];
            ptr += 2;
            chsrc += 8;
        }

        src += width*8;
    }

    assert (ptr - buf == bufSize);

    return buf, bufSize;
}

*/

#scope_file
#import "Render/Texture_Format";
#import "Basic";
#import "String";
#import "Math";
