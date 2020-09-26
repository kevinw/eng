#load "../imgui_impl_gl.jai";

imgui_init :: (ui: *UI_State) {
    gl_load(*gl);
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

imgui_raylib_new_frame :: (ui: *UI_State) {
    ImGui_SetMouseEvents(ui,
        left = IsMouseButtonDown(.MOUSE_LEFT_BUTTON),
        middle = IsMouseButtonDown(.MOUSE_MIDDLE_BUTTON),
        right = IsMouseButtonDown(.MOUSE_RIGHT_BUTTON),
        wheel = cast(float)GetMouseWheelMove());

    add_key :: (key: s32) {
        buf := cast(*s32)talloc(size_of(s32) + 1); // s32 + 0
        << buf = key;
        print("key %\n", key);
        io := ImGui.GetIO();
        io.AddInputCharactersUTF8(io, cast(*u8)buf);
    }

    // this only handles "unicode character" input. for arrows, backspace, etc. we'll need to use the io.KeyDown
    key := GetKeyPressed();
    if key > 0 add_key(key);

    ImGui_Impl_NewFrame(ui, GetWindowHandle(), GetScreenWidth(), GetScreenHeight());
}

imgui_render :: (ui: *UI_State) {
    ImGui.Render();
    ImGui_Impl_RenderDrawData(ui, ImGui.GetDrawData());
}

