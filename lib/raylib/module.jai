#scope_file
#import "renderer";
#import "Basic";
renderer: *Renderer;
_native_window: *void;
_input_button_states: *[Input.NUM_BUTTON_STATES]Input.Key_Current_State;
Input :: #import "Input";
#scope_export
_XXX_SetRenderer :: (renderer_ptr: *Renderer) { renderer = renderer_ptr; }
_XXX_SetNativeWindow :: (native_window: *void) { _native_window = native_window; }
_XXX_SetHostInputButtonStates :: (host_button_states: *[Input.NUM_BUTTON_STATES] Input.Key_Current_State) {
    assert(host_button_states != null, "cannot pass a null pointer to _XXX_SetHostInputButtonStates");
    _input_button_states = host_button_states;
}

// ----

DrawCircleV :: (center: Vector2, radius: float, color: Color) {
    im_draw_circle(*context.state.im_context, center, make_vector2(radius, radius), color=ColorToNormalized(color));
}

DrawRectangleV :: (position: Vector2, size: Vector2, color: Color) {
    im_draw_rect(*context.state.im_context,
        p0=position,
        p1=position+size,
        t0=make_vector2(0,0),
        t1=make_vector2(1,1),
        c=ColorToNormalized(color));
}

IsKeyDown :: (key: KeyboardKey) -> bool {
    if cast(int)key > 300 return false;
    assert(_input_button_states != null);
    return (<<_input_button_states)[cast(int)key] & .DOWN != 0;
}

IsKeyPressed :: (key: KeyboardKey) -> bool {
    if cast(int)key > 300 return false;
    assert(_input_button_states != null);
    return (<<_input_button_states)[cast(int)key] & .START != 0;
}

DrawTexturePro :: (texture: Texture2D, sourceRec: Rectangle, destRec: Rectangle, origin: Vector2, rotation: float, tint: Color) {
    print("TODO: DrawTexturePro\n");
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
GetMousePosition :: () -> Vector2 { return .{}; }
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
GetTime :: () -> float64 { return 0; }
GetFrameTime :: () -> float { return 0; }
rlMultMatrixf   :: (matf: *float) { Basic.assert(false); }


CheckCollisionPointRec :: (point: Vector2, rec: Rectangle) -> bool { return false; }
CheckCollisionRecs :: (rec1: Rectangle, rec2: Rectangle) -> bool { return false; }

GetScreenToWorld2D :: (position: Vector2, camera: Camera2D) -> Vector2 { return .{}; }

DrawText :: (text: *u8, posX: s32, posY: s32, fontSize: s32, color: Color) {
}

DrawText :: inline ($$text: string, posX: s32, posY: s32, fontSize: s32, color: Color) {
    DrawText(constant_or_temp_cstring(text), posX, posY, fontSize, color);
}

DrawRectangleGradientEx :: (rec: Rectangle, col1: Color, col2: Color, col3: Color, col4: Color) {
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

GenImageColor :: (width: s32, height: s32, color: Color) -> Image {
    print("TODO: GetImageColor\n");
    return .{};
}

GetGamepadAxisMovement :: (gamepad: int, axis: GamepadAxis) -> float {
    print("TODO: GetGamepadAxisMovement\n");
    return 0;
}

IsGamepadButtonDown :: (gamepad: int, button: GamepadButton) -> bool {
    print("TODO: IsGamepadButtonDown\n");
    return false;
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

LoadImageEx :: (pixels: *Color, width: s32, height: s32) -> Image {
    return .{};
}

UnloadImage :: (image: Image) {
}

ImageDraw :: (dst: *Image, src: Image, srcRec: Rectangle, dstRec: Rectangle, tint: Color) {
}

DrawRectangleLinesEx :: (rec: Rectangle, lineThick: s32, color: Color) {
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


IsGamepadButtonPressed :: (gamepad: int, button: GamepadButton) -> bool { return false; }

BeginShaderMode :: (shader: Shader) {}
EndShaderMode :: () {}

DrawTexture :: (texture: Texture2D, posX: s32, posY: s32, tint: Color) {
    print("TODO: DrawTexture\n");
}

DrawTextureNPatch :: (texture: Texture2D, nPatchInfo: NPatchInfo, destRec: Rectangle, origin: Vector2, rotation: float, tint: Color) {
}

LoadTexture :: (fileName: *u8) -> Texture2D {
    print("TODO: LoadTexture\n");
    return .{};
}

LoadTextureFromImage :: (image: Image) -> Texture2D {
    print("TODO: LoadTextureFromImage\n");
    return .{};
}

UnloadTexture :: (texture: Texture2D) {
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

Image :: struct {
    data: *void;
    width: s32;
    height: s32;
    mipmaps: s32;
    format: s32;
}

RenderTexture2D :: struct {
    id: u32;
    texture: Texture2D;
    depth: Texture2D;
    depthTexture: bool;
}

RenderTexture :: RenderTexture2D;


Texture2D :: struct {
    id: u32;
    width: s32;
    height: s32;
    mipmaps: s32;
    format: s32;
}
Texture :: Texture2D;

Font :: struct {
    baseSize: s32;
    charsCount: s32;
    texture: Texture2D;
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
#import "Math";
#import "renderer_im";
Basic :: #import "Basic";
print :: Basic.print;

_to_temp_c_string :: (s: string) -> *u8 {
    result : *u8 = Basic.talloc(s.count + 1);
    memcpy(result, s.data, s.count);
    result[s.count] = 0;
    return result;
}
