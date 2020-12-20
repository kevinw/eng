#scope_file
#import "renderer";
#import "Basic";
Gamepad :: #import "Gamepad";
renderer: *Renderer;
_native_window: *void;
_input_button_states: *[Input.NUM_BUTTON_STATES]Input.Key_Current_State;
Input :: #import "Input";
#scope_export
R::#import "renderer";
Texture :: R.Texture;
Image :: Bitmap;

_XXX_SetRenderer :: (renderer_ptr: *Renderer) { renderer = renderer_ptr; }
_XXX_SetNativeWindow :: (native_window: *void) { _native_window = native_window; }
_XXX_SetHostInputButtonStates :: (host_button_states: *[Input.NUM_BUTTON_STATES] Input.Key_Current_State) {
    assert(host_button_states != null, "cannot pass a null pointer to _XXX_SetHostInputButtonStates");
    _input_button_states = host_button_states;
}

// ----

ColorFromNormalized :: (normalized: Vector4) -> Color {
    c: Color = ---;
    c.r = cast(u8)(normalized.x * 255.0);
    c.g = cast(u8)(normalized.y * 255.0);
    c.b = cast(u8)(normalized.z * 255.0);
    c.a = cast(u8)(normalized.w * 255.0);
    return c;
}

ColorToNormalized :: (color: Color) -> Vector4 {
    v: Vector4 = ---;
    v.x = cast(float)color.r / 255.0;
    v.y = cast(float)color.g / 255.0;
    v.z = cast(float)color.b / 255.0;
    v.w = cast(float)color.a / 255.0;
    return v;
}

GetTime :: get_time;

CheckCollisionPointRec :: (point: Vector2, rec: Rectangle) -> bool {
    return (point.x >= rec.x) && (point.x <= (rec.x + rec.width)) && (point.y >= rec.y) && (point.y <= (rec.y + rec.height));
}

CheckCollisionRecs :: (rec1: Rectangle, rec2: Rectangle) -> bool {
    return (rec1.x < (rec2.x + rec2.width) && (rec1.x + rec1.width) > rec2.x) &&
        (rec1.y < (rec2.y + rec2.height) && (rec1.y + rec1.height) > rec2.y);
}

DrawCircleV :: (center: Vector2, radius: float, color: Color) {
    im_draw_circle(*context.state.im_context, center, make_vector2(radius, radius), color=ColorToNormalized(color));
}

DrawRectangleLinesEx :: (rec: Rectangle, lineThick: s32, color: Color) {
    if cast(float)lineThick > rec.width || cast(float)lineThick > rec.height {
        if rec.width > rec.height lineThick = cast(s32)rec.height/2;
        else if rec.width < rec.height lineThick = cast(s32)rec.width/2;
    }

    DrawRectangle(cast(s32)rec.x, cast(s32)rec.y, cast(s32)rec.width, lineThick, color);
    DrawRectangle(cast(s32)(rec.x - lineThick + rec.width), cast(s32)(rec.y + lineThick), lineThick, cast(s32)(rec.height - lineThick*2.0), color);
    DrawRectangle(cast(s32)rec.x, cast(s32)(rec.y + rec.height - lineThick), cast(s32)rec.width, lineThick, color);
    DrawRectangle(cast(s32)rec.x, cast(s32)(rec.y + lineThick), lineThick, cast(s32)(rec.height - lineThick*2), color);
}

DrawRectangle :: (posX: s32, posY: s32, width: s32, height: s32, color: Color) {
    DrawRectangleV(make_vector2(cast(float)posX, cast(float)posY), make_vector2(cast(float)width, cast(float)height), color);
}

DrawRectangleV :: (position: Vector2, size: Vector2, color: Color) {
    im_set_texture(*context.state.im_context, null);
    im_draw_rect(*context.state.im_context,
        p0=position,
        p1=position+size,
        t0=make_vector2(0,0),
        t1=make_vector2(1,1),
        c=ColorToNormalized(color));
}

IsKeyDown :: (key: KeyboardKey) -> bool {
    if cast(int)key > 300 return false;
    key_code := _translate_keycode(key);
    assert(_input_button_states != null);
    return (<<_input_button_states)[cast(int)key] & .DOWN != 0;
}

_translate_keycode :: (key: KeyboardKey) -> Input.Key_Code {
    // temporary mapping from raylib keycode types back to the Jai input ones
    if key == {
        case .KEY_TAB;     return .TAB;
        case .KEY_ENTER;   return .ENTER;
        case .KEY_ESCAPE;  return .ESCAPE;
        case .KEY_SPACE;   return .SPACEBAR;
    }

    return cast(Input.Key_Code)key;
}

IsKeyPressed :: (key: KeyboardKey) -> bool {
    if cast(int)key > 300 return false;
    key_code := _translate_keycode(key);
    assert(_input_button_states != null);
    return (<<_input_button_states)[cast(int)key_code] & .START != 0;
}

GetMousePosition :: () -> Vector2 {
    x, y := Window_Creation.get_mouse_pointer_position();

    v: Vector2 = ---;
    v.x = cast(float)x;
    v.y = cast(float)y;
    return v;
}

DrawTexturePro :: (texture: *Texture, sourceRec_: Rectangle, destRec: Rectangle, origin: Vector2, rotation: float, tint: Color) {
    assert(texture != null);
    sourceRec := sourceRec_;

    p0 := destRec.position;
    p1 := p0 + destRec.size;

    tex_size := make_vector2(xx texture.width, xx texture.height);


    flip_x := false;
    if sourceRec.width < 0 {
        sourceRec.width = -sourceRec.width;
        flip_x = true;
    }

    assert(tex_size.x > 0 && tex_size.y > 0, tprint("texture '%' has size %x%\n", texture.debug_name, texture.width, texture.height));

    t0 := sourceRec.position;
    t0.x /= tex_size.x;
    t0.y /= tex_size.y;

    t1 := sourceRec.position + sourceRec.size;
    t1.x /= tex_size.x;
    t1.y /= tex_size.y;

    if flip_x
        t0.x, t1.x = swap(t0.x, t1.x);

    im_set_texture(*context.state.im_context, texture);
    im_draw_rect(*context.state.im_context,
        p0, p1, t0, t1,
        c = ColorToNormalized(tint));
}

DrawTexture :: (texture: *Texture, posX: s32, posY: s32, tint: Color) {
    assert(texture != null);

    p0 := make_vector2(xx posX, xx posY);
    p1 := p0 + make_vector2(xx texture.width, xx texture.height);

    ctx :: inline () -> *Im_Context { return *context.state.im_context; }
    im_set_texture(ctx(), texture);
    im_draw_rect(ctx(),
        p0, p1,
        c=ColorToNormalized(tint));
    print("TODO: DrawTexture\n");
}


GetGamepadAxisMovement :: (gamepad: int, axis: GamepadAxis) -> float {
    assert(gamepad == 0);
    if axis == {
        case .GAMEPAD_AXIS_LEFT_X;  return Gamepad.gamepad.left_stick.x;
        case .GAMEPAD_AXIS_LEFT_Y;  return Gamepad.gamepad.left_stick.y;
        case .GAMEPAD_AXIS_RIGHT_X; return Gamepad.gamepad.right_stick.y;
        case .GAMEPAD_AXIS_RIGHT_Y; return Gamepad.gamepad.right_stick.y;
        case;
            assert(false, "TODO");
    }

    return 0;
}

get_gamepad_button :: (raylib_button: GamepadButton) -> Gamepad.Gamepad_Code {
    if raylib_button == {
        case .GAMEPAD_BUTTON_LEFT_FACE_UP;     return .DPAD_UP;
        case .GAMEPAD_BUTTON_LEFT_FACE_RIGHT;  return .DPAD_RIGHT;
        case .GAMEPAD_BUTTON_LEFT_FACE_DOWN;   return .DPAD_DOWN;
        case .GAMEPAD_BUTTON_LEFT_FACE_LEFT;   return .DPAD_LEFT;

        case .GAMEPAD_BUTTON_RIGHT_FACE_UP;    return .Y;
        case .GAMEPAD_BUTTON_RIGHT_FACE_RIGHT; return .X;
        case .GAMEPAD_BUTTON_RIGHT_FACE_DOWN;  return .A;
        case .GAMEPAD_BUTTON_RIGHT_FACE_LEFT;  return .B;

        case .GAMEPAD_BUTTON_MIDDLE_RIGHT;     return .START;
        case .GAMEPAD_BUTTON_MIDDLE_LEFT;      return .BACK;

        case;
            assert(false, tprint("gamepad button %", raylib_button));
    }

    return 0;
}

IsGamepadButtonDown :: (gamepad: int, button: GamepadButton) -> bool {
    assert(gamepad == 0);
    return Gamepad.gamepad.buttons[cast(int)get_gamepad_button(button)] & .DOWN != 0;
}

IsGamepadButtonPressed :: (gamepad: int, button: GamepadButton) -> bool { 
    assert(gamepad == 0);
    return Gamepad.gamepad.buttons[cast(int)get_gamepad_button(button)] & .START != 0;
}

    
//------

rlglDraw :: () {}
Matrix :: Matrix4;
rlLoadIdentity :: () {}
GetWindowHandle :: () -> *void { return _native_window; }
GetMonitorWidth :: (monitor: s32) -> s32 { return 0; }
GetMonitorHeight :: (monitor: s32) -> s32 { return 0; }
GetWindowPosition :: () -> Vector2 { return .{}; }
SetWindowPosition :: (x: s32, y: s32)  {}
SetWindowSize :: (width: s32, height: s32) {}
ToggleFullscreen :: () {}
GetScreenWidth :: () -> s32 { 
    // XXX
    Basic.assert(renderer != null);
    return cast(s32)renderer.depth_buffer_desc.Width;
}
GetScreenHeight :: () -> s32 {
    Basic.assert(renderer != null);
    return cast(s32)renderer.depth_buffer_desc.Height;
}
MatrixTranslate :: (x: float, y: float, z: float) -> Matrix {
    return make_translation_matrix4(make_Vector3(x, y, z));
}
MatrixRotate    :: (axis: Vector3, angle_radians: float) -> Matrix {
    Basic.assert(false);
    return .{};
}
MatrixScale     :: (x: float, y: float, z: float) -> Matrix {
    return make_scale_matrix4(make_Vector3(x, y, z));
}
MatrixMultiply  :: (a: Matrix, b: Matrix) -> Matrix { return multiply(a, b); }
float16 :: struct {
    v: [16]float;
}
MatrixToFloatV  :: (mat: Matrix) -> float16 { 
    f16: float16;
    f16.v = mat.floats;
    return f16;
}
rlMultMatrixf   :: (matf: *float) { Basic.assert(false); }


GetScreenToWorld2D :: (position: Vector2, camera: Camera2D) -> Vector2 {
    return position;
}

DrawText :: (text: *u8, posX: s32, posY: s32, fontSize: s32, color: Color) {
}

DrawText :: inline ($$text: string, posX: s32, posY: s32, fontSize: s32, color: Color) {
    DrawText(constant_or_temp_cstring(text), posX, posY, fontSize, color);
}

NPatchType :: enum {
    NPT_9PATCH :: 0;         // Npatch defined by 3x3 tiles
    NPT_3PATCH_VERTICAL;    // Npatch defined by 1x3 tiles
    NPT_3PATCH_HORIZONTAL;
}


NPatchInfo :: struct {
    sourceRec: Rectangle;
    left: s32;
    top: s32;
    right: s32;
    bottom: s32;
    type: s32;
}

GenImageColor :: (width: s32, height: s32, color: Color) -> Bitmap {
    assert(width > 0);
    assert(height > 0);

    bmp: Bitmap;
    bitmap_alloc(*bmp, width, height, .RGBA8);
    pixel := cast(*Color)bmp.data;
    for 0..width*height {
        <<pixel = color;
        pixel += 1;
    }
    return bmp;
}

GamepadAxis :: enum {
    // This is here just for error checking
    GAMEPAD_AXIS_UNKNOWN :: 0;

    // Left stick
    GAMEPAD_AXIS_LEFT_X;
    GAMEPAD_AXIS_LEFT_Y;

    // Right stick
    GAMEPAD_AXIS_RIGHT_X;
    GAMEPAD_AXIS_RIGHT_Y;

    // Pressure levels for the back triggers
    GAMEPAD_AXIS_LEFT_TRIGGER;      // [1..-1] (pressure-level)
    GAMEPAD_AXIS_RIGHT_TRIGGER;
}


Camera2D :: struct {
    offset: Vector2;
    target: Vector2;
    rotation: float;
    zoom: float;
}

DrawTriangleStrip :: (points: *Vector2, pointsCount: s32, color: Color) {
    print("TODO: DrawTriangleStrip\n");
}


Color :: struct {
    r: u8;
    g: u8;
    b: u8;
    a: u8;
}

Shader :: struct {
}

SetShaderValue :: (shader: Shader, uniformLoc: s32, value: *void, uniformType: ShaderUniformDataType) {

}

ShaderUniformDataType :: enum {
    UNIFORM_FLOAT :: 0;
    UNIFORM_VEC2;
    UNIFORM_VEC3;
    UNIFORM_VEC4;
    UNIFORM_INT;
    UNIFORM_IVEC2;
    UNIFORM_IVEC3;
    UNIFORM_IVEC4;
    UNIFORM_SAMPLER2D;
}

GetShaderLocation :: (shader: Shader, uniformName: *u8) -> s32 { return 0; }

UnloadShader :: (shader: Shader) {}
LoadShader :: (vsFileName: *u8, fsFileName: *u8) -> Shader { return .{}; }

LIGHTGRAY :: Color.{  200, 200, 200, 255  };
GRAY :: Color.{  130, 130, 130, 255  };
DARKGRAY :: Color.{  80, 80, 80, 255  };
YELLOW :: Color.{  253, 249, 0, 255  };
GOLD :: Color.{  255, 203, 0, 255  };
ORANGE :: Color.{  255, 161, 0, 255  };
PINK :: Color.{  255, 109, 194, 255  };
RED :: Color.{  230, 41, 55, 255  };
MAROON :: Color.{  190, 33, 55, 255  };
GREEN :: Color.{  0, 228, 48, 255  };
LIME :: Color.{  0, 158, 47, 255  };
DARKGREEN :: Color.{  0, 117, 44, 255  };
SKYBLUE :: Color.{  102, 191, 255, 255  };
BLUE :: Color.{  0, 121, 241, 255  };
DARKBLUE :: Color.{  0, 82, 172, 255  };
PURPLE :: Color.{  200, 122, 255, 255  };
VIOLET :: Color.{  135, 60, 190, 255  };
DARKPURPLE :: Color.{  112, 31, 126, 255  };
BEIGE :: Color.{  211, 176, 131, 255  };
BROWN :: Color.{  127, 106, 79, 255  };
DARKBROWN :: Color.{  76, 63, 47, 255  };
WHITE :: Color.{  255, 255, 255, 255  };
BLACK :: Color.{  0, 0, 0, 255  };
BLANK :: Color.{  0, 0, 0, 0  };
MAGENTA :: Color.{  255, 0, 255, 255  };
RAYWHITE :: Color.{  245, 245, 245, 255  };
Rectangle :: struct {
    x: float;
    y: float;
    width: float;
    height: float;

    #place x;     position: Vector2;
    #place width; size: Vector2;
}

LoadImagePro :: (data: *void, width: s32, height: s32, format: s32) -> Image {
    return .{};
}

DrawRectangleGradientEx :: (rec: Rectangle, col1: Color, col2: Color, col3: Color, col4: Color) {
    v2 :: make_vector2;
    ctx :: inline () -> *Im_Context { return *context.state.im_context; }
    _ctx := ctx();
    im_set_primitive(_ctx, 3);
    im_ensure_space_for(_ctx, 6, 4);

    p0 := v2(rec.x, rec.y);
    p1 := v2(rec.x, rec.y + rec.height);
    p2 := v2(rec.x + rec.width, rec.y + rec.height);
    p3 := v2(rec.x + rec.width, rec.y);

    t0 := v2(0, 0);
    t1 := v2(0, 1);
    t2 := v2(1, 1);
    t3 := v2(1, 0);

    im_set_texture(_ctx, null);
    vt0 := im_vertex(_ctx, p0, t0, ColorToNormalized(col1));
    vt1 := im_vertex(_ctx, p1, t1, ColorToNormalized(col2));
    vt2 := im_vertex(_ctx, p2, t2, ColorToNormalized(col3));
    vt3 := im_vertex(_ctx, p3, t3, ColorToNormalized(col4));
    im_indices(_ctx, vt0, vt1, vt2, vt2, vt0, vt3);
}

LoadImageEx :: (pixels: *Color, width: s32, height: s32) -> Image {
    bmp: Bitmap;
    bitmap_alloc(*bmp, width, height, .RGBA8);
    bmp.own_data = true;
    memcpy(bmp.data, pixels, width * height * 4);
    return bmp;
}

UnloadImage :: (image: Bitmap) {
}

ImageFromImage :: (image: Image, rec: Rectangle) -> Image {
    result := image;
    memcpy(result.data, image.data, image.length_in_bytes);
    result.own_data = true;
    return result;
}

ImageResize :: (image: *Image, newWidth: int, newHeight: int) {
    assert(image.format == .RGBA8);
    bytesPerPixel := 4;
    output := alloc(newWidth * newHeight * bytesPerPixel);
    if image.format == {
        case .RGBA8;
            stbir_resize_uint8(image.data, image.width, image.height, 0, output, xx newWidth, xx newHeight, 0, 4);
    }

    if image.own_data
        free(image.data);

    image.data = output;
    image.width = xx newWidth;
    image.height = xx newHeight;
}

GetPixelDataSize :: (width: s32, height: s32, format: Texture_Format) -> s32 {
    return width * height * cast(s32)get_image_bytes_per_texel(format);
}

GetPixelColor :: (srcPtr: *void, format: Texture_Format) -> Color {
    assert(format == .RGBA8);

    col: Color;
    col.r = (cast([4]u8)srcPtr)[0];
    col.g = (cast([4]u8)srcPtr)[1];
    col.b = (cast([4]u8)srcPtr)[2];
    col.a = (cast([4]u8)srcPtr)[3];
    return col;
}

ImageDraw :: (dst: *Image, src: Image, srcRecIn: Rectangle, dstRecIn: Rectangle, tint: Color) {
    srcRec := srcRecIn;
    dstRec := dstRecIn;

    // Security check to avoid program crash
    if dst.data == null || (dst.width == 0) || (dst.height == 0) ||
        (src.data == null) || (src.width == 0) || (src.height == 0) return;

    //if dst.mipmaps > 1 logprint("raylib_fake", "Image drawing only applied to base mipmap level");
    assert(dst.format == .RGBA8);
    //if dst.format >= COMPRESSED_DXT1_RGB {
        //logprint("raylib_fake", "Image drawing not supported for compressed formats");
        //return;
    //}
    srcMod: Image;       // Source copy (in case it was required)
    srcPtr := *src;      // Pointer to source image
    useSrcMod := false;  // Track source copy required

    // Source rectangle out-of-bounds security checks
    if srcRec.x < 0 { srcRec.width += srcRec.x; srcRec.x = 0; }
    if srcRec.y < 0 { srcRec.height += srcRec.y; srcRec.y = 0; }
    if (srcRec.x + srcRec.width) > xx src.width srcRec.width = src.width - srcRec.x;
    if (srcRec.y + srcRec.height) > xx src.height srcRec.height = src.height - srcRec.y;

    // Check if source rectangle needs to be resized to destination rectangle
    // In that case, we make a copy of source and we apply all required transform
    if (cast(s32)srcRec.width != cast(s32)dstRec.width) || (cast(s32)srcRec.height != cast(s32)dstRec.height) {
        srcMod = ImageFromImage(src, srcRec);   // Create image from another image
        ImageResize(*srcMod, cast(s32)dstRec.width, cast(s32)dstRec.height);   // Resize to destination rectangle
        srcRec = make_Rectangle(0, 0, srcMod.width, srcMod.height);

        srcPtr = *srcMod;
        useSrcMod = true;
    }

    // Destination rectangle out-of-bounds security checks
    if dstRec.x < 0 {
        srcRec.x = -dstRec.x;
        srcRec.width += dstRec.x;
        dstRec.x = 0;
    } else if (dstRec.x + srcRec.width) > xx dst.width {
        srcRec.width = dst.width - dstRec.x;
    }

    if dstRec.y < 0 {
        srcRec.y = -dstRec.y;
        srcRec.height += dstRec.y;
        dstRec.y = 0;
    }
    else if ((dstRec.y + srcRec.height) > xx dst.height) srcRec.height = dst.height - dstRec.y;

    if dst.width < xx srcRec.width srcRec.width = xx dst.width;
    if dst.height < xx srcRec.height srcRec.height = xx dst.height;

    // This blitting method is quite fast! The process followed is:
    // for every pixel -> [get_src_format/get_dst_format -> blend -> format_to_dst]
    // Some optimization ideas:
    //    [x] Avoid creating source copy if not required (no resize required)
    //    [x] Optimize ImageResize() for pixel format (alternative: ImageResizeNN())
    //    [x] Optimize ColorAlphaBlend() to avoid processing (alpha = 0) and (alpha = 1)
    //    [x] Optimize ColorAlphaBlend() for faster operations (maybe avoiding divs?)
    //    [x] Consider fast path: no alpha blending required cases (src has no alpha)
    //    [x] Consider fast path: same src/dst format with no alpha -> direct line copy
    //    [-] GetPixelColor(): Return Vector4 instead of Color, easier for ColorAlphaBlend()

    colSrc, colDst, blend: Color;
    blendRequired := true;
    
    // Fast path: Avoid blend if source has no alpha to blend
    //if ((tint.a == 255) && ((srcPtr.format == UNCOMPRESSED_GRAYSCALE) || (srcPtr.format == UNCOMPRESSED_R8G8B8) || (srcPtr.format == UNCOMPRESSED_R5G6B5))) blendRequired = false;

    strideDst:s32 = GetPixelDataSize(dst.width, 1, dst.format);
    bytesPerPixelDst:s32 = strideDst/(dst.width);

    strideSrc:s32 = GetPixelDataSize(srcPtr.width, 1, srcPtr.format);
    bytesPerPixelSrc:s32 = strideSrc/srcPtr.width;

    pSrcBase := cast(*u8)srcPtr.data + (cast(s32)srcRec.y*srcPtr.width + cast(s32)srcRec.x)*bytesPerPixelSrc;
    pDstBase := cast(*u8)dst.data    + (cast(s32)dstRec.y*dst.width    + cast(s32)dstRec.x)*bytesPerPixelDst;

    for y: 0..cast(s32)srcRec.height-1 {
        pSrc := pSrcBase;
        pDst := pDstBase;

        // Fast path: Avoid moving pixel by pixel if no blend required and same format
        if !blendRequired && (srcPtr.format == dst.format)
            memcpy(pDst, pSrc, cast(s32)srcRec.width*bytesPerPixelSrc);
        else
        {
            for x: 0..cast(s32)srcRec.width-1 {
                colSrc = GetPixelColor(pSrc, srcPtr.format);
                colDst = GetPixelColor(pDst, dst.format);
                
                // Fast path: Avoid blend if source has no alpha to blend
                if (blendRequired) blend = ColorAlphaBlend(colDst, colSrc, tint);
                else blend = colSrc;

                SetPixelColor(pDst, blend, dst.format);

                pDst += bytesPerPixelDst;
                pSrc += bytesPerPixelSrc;
            }
        }

        pSrcBase += strideSrc;
        pDstBase += strideDst;
    }

    if useSrcMod UnloadImage(srcMod);     // Unload source modified image
}

SetPixelColor :: inline (dstPtr: *void, color: Color, format: Texture_Format)
{
    assert(format == .RGBA8);
    (cast([4]u8)dstPtr)[0] = color.r;
    (cast([4]u8)dstPtr)[1] = color.g;
    (cast([4]u8)dstPtr)[2] = color.b;
    (cast([4]u8)dstPtr)[3] = color.a;
}


// Returns src alpha-blended into dst color with tint
ColorAlphaBlend :: (dst: Color, srcIn: Color, tint: Color) -> Color
{
    out := WHITE;

    src := srcIn;
    
    // Apply color tint to source color
    src.r = cast(u8)((cast(u32)src.r*cast(u32)tint.r) >> 8);
    src.g = cast(u8)((cast(u32)src.g*cast(u32)tint.g) >> 8);
    src.b = cast(u8)((cast(u32)src.b*cast(u32)tint.b) >> 8);
    src.a = cast(u8)((cast(u32)src.a*cast(u32)tint.a) >> 8);

    if (src.a == 0) out = dst;
    else if (src.a == 255) out = src;
    else
    {
        alpha := cast(u32)src.a + 1;     // We are shifting by 8 (dividing by 256), so we need to take that excess into account
        out.a = cast(u8)((cast(u32)alpha*256 + cast(u32)dst.a*(256 - alpha)) >> 8);

        if out.a > 0 {
            out.r = cast(u8)(((cast(u32)src.r*alpha*256 + cast(u32)dst.r*cast(u32)dst.a*(256 - alpha))/out.a) >> 8);
            out.g = cast(u8)(((cast(u32)src.g*alpha*256 + cast(u32)dst.g*cast(u32)dst.a*(256 - alpha))/out.a) >> 8);
            out.b = cast(u8)(((cast(u32)src.b*alpha*256 + cast(u32)dst.b*cast(u32)dst.a*(256 - alpha))/out.a) >> 8);
        }
    }

    return out;
}


PixelFormat :: enum {
    UNCOMPRESSED_GRAYSCALE :: 1;     // 8 bit per pixel (no alpha)
    UNCOMPRESSED_GRAY_ALPHA;        // 8*2 bpp (2 channels)
    UNCOMPRESSED_R5G6B5;            // 16 bpp
    UNCOMPRESSED_R8G8B8;            // 24 bpp
    UNCOMPRESSED_R5G5B5A1;          // 16 bpp (1 bit alpha)
    UNCOMPRESSED_R4G4B4A4;          // 16 bpp (4 bit alpha)
    UNCOMPRESSED_R8G8B8A8;          // 32 bpp
    UNCOMPRESSED_R32;               // 32 bpp (1 channel - float)
    UNCOMPRESSED_R32G32B32;         // 32*3 bpp (3 channels - float)
    UNCOMPRESSED_R32G32B32A32;      // 32*4 bpp (4 channels - float)
    COMPRESSED_DXT1_RGB;            // 4 bpp (no alpha)
    COMPRESSED_DXT1_RGBA;           // 4 bpp (1 bit alpha)
    COMPRESSED_DXT3_RGBA;           // 8 bpp
    COMPRESSED_DXT5_RGBA;           // 8 bpp
    COMPRESSED_ETC1_RGB;            // 4 bpp
    COMPRESSED_ETC2_RGB;            // 4 bpp
    COMPRESSED_ETC2_EAC_RGBA;       // 8 bpp
    COMPRESSED_PVRT_RGB;            // 4 bpp
    COMPRESSED_PVRT_RGBA;           // 4 bpp
    COMPRESSED_ASTC_4x4_RGBA;       // 8 bpp
    COMPRESSED_ASTC_8x8_RGBA;
}


KeyboardKey :: enum {
    // Alphanumeric keys
    KEY_APOSTROPHE      :: 39;
    KEY_COMMA           :: 44;
    KEY_MINUS           :: 45;
    KEY_PERIOD          :: 46;
    KEY_SLASH           :: 47;
    KEY_ZERO            :: 48;
    KEY_ONE             :: 49;
    KEY_TWO             :: 50;
    KEY_THREE           :: 51;
    KEY_FOUR            :: 52;
    KEY_FIVE            :: 53;
    KEY_SIX             :: 54;
    KEY_SEVEN           :: 55;
    KEY_EIGHT           :: 56;
    KEY_NINE            :: 57;
    KEY_SEMICOLON       :: 59;
    KEY_EQUAL           :: 61;
    KEY_A               :: 65;
    KEY_B               :: 66;
    KEY_C               :: 67;
    KEY_D               :: 68;
    KEY_E               :: 69;
    KEY_F               :: 70;
    KEY_G               :: 71;
    KEY_H               :: 72;
    KEY_I               :: 73;
    KEY_J               :: 74;
    KEY_K               :: 75;
    KEY_L               :: 76;
    KEY_M               :: 77;
    KEY_N               :: 78;
    KEY_O               :: 79;
    KEY_P               :: 80;
    KEY_Q               :: 81;
    KEY_R               :: 82;
    KEY_S               :: 83;
    KEY_T               :: 84;
    KEY_U               :: 85;
    KEY_V               :: 86;
    KEY_W               :: 87;
    KEY_X               :: 88;
    KEY_Y               :: 89;
    KEY_Z               :: 90;

    // Function keys
    KEY_SPACE           :: 32;
    KEY_ESCAPE          :: 256;
    KEY_ENTER           :: 257;
    KEY_TAB             :: 258;
    KEY_BACKSPACE       :: 259;
    KEY_INSERT          :: 260;
    KEY_DELETE          :: 261;
    KEY_RIGHT           :: 262;
    KEY_LEFT            :: 263;
    KEY_DOWN            :: 264;
    KEY_UP              :: 265;
    KEY_PAGE_UP         :: 266;
    KEY_PAGE_DOWN       :: 267;
    KEY_HOME            :: 268;
    KEY_END             :: 269;
    KEY_CAPS_LOCK       :: 280;
    KEY_SCROLL_LOCK     :: 281;
    KEY_NUM_LOCK        :: 282;
    KEY_PRINT_SCREEN    :: 283;
    KEY_PAUSE           :: 284;
    KEY_F1              :: 290;
    KEY_F2              :: 291;
    KEY_F3              :: 292;
    KEY_F4              :: 293;
    KEY_F5              :: 294;
    KEY_F6              :: 295;
    KEY_F7              :: 296;
    KEY_F8              :: 297;
    KEY_F9              :: 298;
    KEY_F10             :: 299;
    KEY_F11             :: 300;
    KEY_F12             :: 301;
    KEY_LEFT_SHIFT      :: 340;
    KEY_LEFT_CONTROL    :: 341;
    KEY_LEFT_ALT        :: 342;
    KEY_LEFT_SUPER      :: 343;
    KEY_RIGHT_SHIFT     :: 344;
    KEY_RIGHT_CONTROL   :: 345;
    KEY_RIGHT_ALT       :: 346;
    KEY_RIGHT_SUPER     :: 347;
    KEY_KB_MENU         :: 348;
    KEY_LEFT_BRACKET    :: 91;
    KEY_BACKSLASH       :: 92;
    KEY_RIGHT_BRACKET   :: 93;
    KEY_GRAVE           :: 96;

    // Keypad keys
    KEY_KP_0            :: 320;
    KEY_KP_1            :: 321;
    KEY_KP_2            :: 322;
    KEY_KP_3            :: 323;
    KEY_KP_4            :: 324;
    KEY_KP_5            :: 325;
    KEY_KP_6            :: 326;
    KEY_KP_7            :: 327;
    KEY_KP_8            :: 328;
    KEY_KP_9            :: 329;
    KEY_KP_DECIMAL      :: 330;
    KEY_KP_DIVIDE       :: 331;
    KEY_KP_MULTIPLY     :: 332;
    KEY_KP_SUBTRACT     :: 333;
    KEY_KP_ADD          :: 334;
    KEY_KP_ENTER        :: 335;
    KEY_KP_EQUAL        :: 336;
}

GamepadButton :: enum {
    // This is here just for error checking
    GAMEPAD_BUTTON_UNKNOWN :: 0;

    // This is normally a DPAD
    GAMEPAD_BUTTON_LEFT_FACE_UP;
    GAMEPAD_BUTTON_LEFT_FACE_RIGHT;
    GAMEPAD_BUTTON_LEFT_FACE_DOWN;
    GAMEPAD_BUTTON_LEFT_FACE_LEFT;

    // This normally corresponds with PlayStation and Xbox controllers
    // XBOX: [Y;X;A;B]
    // PS3: [Triangle;Square;Cross;Circle]
    // No support for 6 button controllers though..
    GAMEPAD_BUTTON_RIGHT_FACE_UP;
    GAMEPAD_BUTTON_RIGHT_FACE_RIGHT;
    GAMEPAD_BUTTON_RIGHT_FACE_DOWN;
    GAMEPAD_BUTTON_RIGHT_FACE_LEFT;

    // Triggers
    GAMEPAD_BUTTON_LEFT_TRIGGER_1;
    GAMEPAD_BUTTON_LEFT_TRIGGER_2;
    GAMEPAD_BUTTON_RIGHT_TRIGGER_1;
    GAMEPAD_BUTTON_RIGHT_TRIGGER_2;

    // These are buttons in the center of the gamepad
    GAMEPAD_BUTTON_MIDDLE_LEFT;     //PS3 Select
    GAMEPAD_BUTTON_MIDDLE;          //PS Button/XBOX Button
    GAMEPAD_BUTTON_MIDDLE_RIGHT;    //PS3 Start

    // These are the joystick press in buttons
    GAMEPAD_BUTTON_LEFT_THUMB;
    GAMEPAD_BUTTON_RIGHT_THUMB;
}

IsMouseButtonPressed :: (button: MouseButton) -> bool { return false; }
IsMouseButtonDown :: (button: MouseButton) -> bool { return false; }
IsMouseButtonReleased :: (button: MouseButton) -> bool { return false; }
IsMouseButtonUp :: (button: MouseButton) -> bool { return false; }

GetMouseWheelMove :: () -> s32 { return 0; }
GetKeyPressed :: () -> s32 { return 0; }

CharInfo :: struct {
    value: s32;
    offsetX: s32;
    offsetY: s32;
    advanceX: s32;
    image: Image;
}


MouseButton :: enum {
    MOUSE_LEFT_BUTTON   :: 0;
    MOUSE_RIGHT_BUTTON  :: 1;
    MOUSE_MIDDLE_BUTTON :: 2;
}


BeginShaderMode :: (shader: Shader) {}
EndShaderMode :: () {}

DrawTextureNPatch :: (texture: *Texture, nPatchInfo: NPatchInfo, destRec: Rectangle, origin: Vector2, rotation: float, tint: Color) {
}

LoadTexture :: (filename: string) -> Texture {
    assert(filename.count > 0);
    ok, tex := load_texture_from_file(filename);
    if !ok print("Warning: load_texture_from_file('%') failed\n", filename);
    assert(ok);
    return tex;
}

LoadTextureFromImage :: (image: Bitmap) -> Texture {
    assert(image.format == .RGBA8);
    assert(image.width > 0);
    assert(image.height > 0);

    ok, texture := load_texture_from_data(xx image.width, xx image.height, 4, image.data);
    assert(ok);
    return texture;
}

UnloadTexture :: (texture: Texture) {
    print("TODO: UnloadTexture\n");
}

make_Rectangle :: (x: $A, y: $B, width: $C, height: $D) -> Rectangle {
    r: Rectangle;
    r.x      = cast(float)x;
    r.y      = cast(float)y;
    r.width  = cast(float)width;
    r.height = cast(float)height;
    return r;
}

make_Color :: (r: $A, g: $B, b: $C, a: $D) -> Color {
    color: Color;
    color.r = cast(u8)r;
    color.g = cast(u8)g;
    color.b = cast(u8)b;
    color.a = cast(u8)a;
    return color;
}

make_Vector3 :: (x: $A, y: $B, z: $C) -> Vector3 {
    v: Vector3 = ---;
    v.x = cast(float)x;
    v.y = cast(float)y;
    v.z = cast(float)z;
    return v;
}

make_Vector2 :: (x: $A, y: $B) -> Vector2 {
    v: Vector2 = ---;
    v.x = cast(float)x;
    v.y = cast(float)y;
    return v;
}

RenderTexture2D :: struct {
    id: u32;
    texture: Texture;
    depth: Texture;
    depthTexture: bool;
}

RenderTexture :: RenderTexture2D;

Font :: struct {
    baseSize: s32;
    charsCount: s32;
    texture: Texture;
    recs: *Rectangle;
    chars: *CharInfo;
}


constant_or_temp_cstring :: inline ($$text: string) -> *u8 {
    c_str: *u8;
    #if is_constant(text)
        c_str = text.data;
    else
        c_str = _to_temp_c_string(text);
    return c_str;
}

#scope_file
#import "Bitmap";
#import "Math";
#import "renderer_im";
#import "stb_image_resize";
Basic :: #import "Basic";
Window_Creation :: #import "Window_Creation";
print :: Basic.print;
#import "Render/Texture_Format";

_to_temp_c_string :: (s: string) -> *u8 {
    result : *u8 = Basic.talloc(s.count + 1);
    memcpy(result, s.data, s.count);
    result[s.count] = 0;
    return result;
}
