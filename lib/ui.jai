#load "../imgui_impl_gl.jai";

gl_debug_context: Context;


DEBUG_SEVERITY_NOTIFICATION:GLenum: 0x826B;

gl_debug_proc :: (
    source: GLenum,
    type: GLenum,
    id: GLuint,
    severity: GLenum,
    length: GLsizei,
    message: *u8,
    userdata: *void) #c_call
{
    if severity == DEBUG_SEVERITY_NOTIFICATION return;

    ctx := cast(*Context)userdata;
    push_context <<ctx {
        print("GL ERROR: severity: % --- %\n", severity, to_string(message));
    }
}

imgui_init :: (ui: *UI_State) {
    ImGui_Impl_SetupGLContext();

    ImGui_Impl_CreateContext(ui);
    ImGui.StyleColorsDark();
    style := ImGui.GetStyle();
    style.ScaleAllSizes(style, 1.2);

    //font_file :: "resources/fonts/FiraCode-VariableFont_wght.ttf"; font_size :: 24;
    //font_file :: "resources/fonts/consola.ttf"; font_size :: 18;
    font_file :: "resources/fonts/Roboto-Regular.ttf"; font_size :: 20;

    io := ImGui.GetIO();
    io.Fonts.AddFontFromFileTTF(io.Fonts, font_file, font_size);

    ImGui_Impl_Init(ui, GetWindowHandle());
}

control_keys :: KeyboardKey.[
    .KEY_TAB,
    .KEY_LEFT,
    .KEY_RIGHT,
    .KEY_UP,
    .KEY_DOWN,
    .KEY_BACKSPACE,
    .KEY_PAGE_UP,
    .KEY_PAGE_DOWN,
    .KEY_HOME,
    .KEY_END,
    .KEY_DELETE,
    .KEY_BACKSPACE,
    .KEY_ENTER,
    .KEY_ESCAPE,
    .KEY_A,
    .KEY_C,
    .KEY_V,
    .KEY_X,
    .KEY_Y,
    .KEY_Z,
];

imgui_raylib_new_frame :: (ui: *UI_State) {
    ImGui_SetMouseEvents(ui,
        left = IsMouseButtonDown(.MOUSE_LEFT_BUTTON),
        middle = IsMouseButtonDown(.MOUSE_MIDDLE_BUTTON),
        right = IsMouseButtonDown(.MOUSE_RIGHT_BUTTON),
        wheel = cast(float)GetMouseWheelMove());

    add_key :: (key: s32) {
        buf := cast(*s32)talloc(size_of(s32) + 1); // s32 + 0
        << buf = key;
        io := ImGui.GetIO();
        io.AddInputCharactersUTF8(io, cast(*u8)buf);
    }

    // this only handles "unicode character" input. for arrows, backspace, etc. we'll need to use the io.KeyDown
    key := GetKeyPressed();
    if key > 0 add_key(key);

    io := ImGui.GetIO();

    // send control keys from raylib to imgui (note they get mapped through io.KeyMap
    // which is setup in the impl
    for control_keys io.KeysDown[cast(int)it] = IsKeyDown(it);

    ImGui_Impl_NewFrame(ui, GetWindowHandle(), GetScreenWidth(), GetScreenHeight());
}

imgui_render :: (ui: *UI_State) {
    ImGui.Render();
    ImGui_Impl_RenderDrawData(ui, ImGui.GetDrawData());
}

