#load "../imgui_impl_gl.jai";

imgui_init :: (ui: *UI_State) {
    gl_load(*gl);
    ImGui_Impl_CreateContext(ui);
    ImGui.StyleColorsDark();
    style := ImGui.GetStyle();
    style.ScaleAllSizes(style, 1.2);

    io := ImGui.GetIO();

    //font_file :: "resources/fonts/FiraCode-VariableFont_wght.ttf"; font_size :: 24;
    font_file :: "resources/fonts/consola.ttf"; font_size :: 18;

    io.Fonts.AddFontFromFileTTF(io.Fonts, font_file, font_size);

    ImGui_Impl_Init(ui, GetWindowHandle());
}

imgui_raylib_new_frame :: (ui: *UI_State) {
    ImGui_SetMouseEvents(ui,
        left = IsMouseButtonDown(.MOUSE_LEFT_BUTTON),
        middle = IsMouseButtonDown(.MOUSE_MIDDLE_BUTTON),
        right = IsMouseButtonDown(.MOUSE_RIGHT_BUTTON),
        wheel = cast(float)GetMouseWheelMove());
    ImGui_Impl_NewFrame(ui, GetWindowHandle(), GetScreenWidth(), GetScreenHeight());
}

imgui_render :: (ui: *UI_State) {
    ImGui.Render();
    ImGui_Impl_RenderDrawData(ui, ImGui.GetDrawData());
}

