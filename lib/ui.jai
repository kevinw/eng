ACTUALLY_USE_RAYLIB :: false;

#if ACTUALLY_USE_RAYLIB
    #load "../imgui_impl_gl.jai";
else
    #load "../imgui_impl_d3d11.jai";

make_ImVec4 :: (x: float, y: float, z: float, w: float) -> ImGui.ImVec4 {
    v: ImGui.ImVec4 = ---;
    v.x = x;
    v.y = y;
    v.z = z;
    v.w = w;
    return v;
}

dark_theme :: () {
    style := ImGui.GetStyle();
    style.Colors[cast(int)ImGui.Col.Text]                  = make_ImVec4(1.00, 1.00, 1.00, 1.00);
    style.Colors[cast(int)ImGui.Col.TextDisabled]          = make_ImVec4(0.50, 0.50, 0.50, 1.00);
    style.Colors[cast(int)ImGui.Col.WindowBg]              = make_ImVec4(0.13, 0.14, 0.15, 1.00);
    style.Colors[cast(int)ImGui.Col.ChildBg]               = make_ImVec4(0.13, 0.14, 0.15, 1.00);
    style.Colors[cast(int)ImGui.Col.PopupBg]               = make_ImVec4(0.13, 0.14, 0.15, 1.00);
    style.Colors[cast(int)ImGui.Col.Border]                = make_ImVec4(0.43, 0.43, 0.50, 0.50);
    style.Colors[cast(int)ImGui.Col.BorderShadow]          = make_ImVec4(0.00, 0.00, 0.00, 0.00);
    style.Colors[cast(int)ImGui.Col.FrameBg]               = make_ImVec4(0.25, 0.25, 0.25, 1.00);
    style.Colors[cast(int)ImGui.Col.FrameBgHovered]        = make_ImVec4(0.38, 0.38, 0.38, 1.00);
    style.Colors[cast(int)ImGui.Col.FrameBgActive]         = make_ImVec4(0.67, 0.67, 0.67, 0.39);
    style.Colors[cast(int)ImGui.Col.TitleBg]               = make_ImVec4(0.08, 0.08, 0.09, 1.00);
    style.Colors[cast(int)ImGui.Col.TitleBgActive]         = make_ImVec4(0.08, 0.08, 0.09, 1.00);
    style.Colors[cast(int)ImGui.Col.TitleBgCollapsed]      = make_ImVec4(0.00, 0.00, 0.00, 0.51);
    style.Colors[cast(int)ImGui.Col.MenuBarBg]             = make_ImVec4(0.14, 0.14, 0.14, 1.00);
    style.Colors[cast(int)ImGui.Col.ScrollbarBg]           = make_ImVec4(0.02, 0.02, 0.02, 0.53);
    style.Colors[cast(int)ImGui.Col.ScrollbarGrab]         = make_ImVec4(0.31, 0.31, 0.31, 1.00);
    style.Colors[cast(int)ImGui.Col.ScrollbarGrabHovered]  = make_ImVec4(0.41, 0.41, 0.41, 1.00);
    style.Colors[cast(int)ImGui.Col.ScrollbarGrabActive]   = make_ImVec4(0.51, 0.51, 0.51, 1.00);
    style.Colors[cast(int)ImGui.Col.CheckMark]             = make_ImVec4(0.11, 0.64, 0.92, 1.00);
    style.Colors[cast(int)ImGui.Col.SliderGrab]            = make_ImVec4(0.11, 0.64, 0.92, 1.00);
    style.Colors[cast(int)ImGui.Col.SliderGrabActive]      = make_ImVec4(0.08, 0.50, 0.72, 1.00);
    style.Colors[cast(int)ImGui.Col.Button]                = make_ImVec4(0.25, 0.25, 0.25, 1.00);
    style.Colors[cast(int)ImGui.Col.ButtonHovered]         = make_ImVec4(0.38, 0.38, 0.38, 1.00);
    style.Colors[cast(int)ImGui.Col.ButtonActive]          = make_ImVec4(0.67, 0.67, 0.67, 0.39);
    style.Colors[cast(int)ImGui.Col.Header]                = make_ImVec4(0.22, 0.22, 0.22, 1.00);
    style.Colors[cast(int)ImGui.Col.HeaderHovered]         = make_ImVec4(0.25, 0.25, 0.25, 1.00);
    style.Colors[cast(int)ImGui.Col.HeaderActive]          = make_ImVec4(0.67, 0.67, 0.67, 0.39);
    style.Colors[cast(int)ImGui.Col.Separator]             = style.Colors[ImGui.Col.Border];
    style.Colors[cast(int)ImGui.Col.SeparatorHovered]      = make_ImVec4(0.41, 0.42, 0.44, 1.00);
    style.Colors[cast(int)ImGui.Col.SeparatorActive]       = make_ImVec4(0.26, 0.59, 0.98, 0.95);
    style.Colors[cast(int)ImGui.Col.ResizeGrip]            = make_ImVec4(0.00, 0.00, 0.00, 0.00);
    style.Colors[cast(int)ImGui.Col.ResizeGripHovered]     = make_ImVec4(0.29, 0.30, 0.31, 0.67);
    style.Colors[cast(int)ImGui.Col.ResizeGripActive]      = make_ImVec4(0.26, 0.59, 0.98, 0.95);
    style.Colors[cast(int)ImGui.Col.Tab]                   = make_ImVec4(0.08, 0.08, 0.09, 0.83);
    style.Colors[cast(int)ImGui.Col.TabHovered]            = make_ImVec4(0.33, 0.34, 0.36, 0.83);
    style.Colors[cast(int)ImGui.Col.TabActive]             = make_ImVec4(0.23, 0.23, 0.24, 1.00);
    style.Colors[cast(int)ImGui.Col.TabUnfocused]          = make_ImVec4(0.08, 0.08, 0.09, 1.00);
    style.Colors[cast(int)ImGui.Col.TabUnfocusedActive]    = make_ImVec4(0.13, 0.14, 0.15, 1.00);
    style.Colors[cast(int)ImGui.Col.DockingPreview]        = make_ImVec4(0.26, 0.59, 0.98, 0.70);
    style.Colors[cast(int)ImGui.Col.DockingEmptyBg]        = make_ImVec4(0.20, 0.20, 0.20, 1.00);
    style.Colors[cast(int)ImGui.Col.PlotLines]             = make_ImVec4(0.61, 0.61, 0.61, 1.00);
    style.Colors[cast(int)ImGui.Col.PlotLinesHovered]      = make_ImVec4(1.00, 0.43, 0.35, 1.00);
    style.Colors[cast(int)ImGui.Col.PlotHistogram]         = make_ImVec4(0.90, 0.70, 0.00, 1.00);
    style.Colors[cast(int)ImGui.Col.PlotHistogramHovered]  = make_ImVec4(1.00, 0.60, 0.00, 1.00);
    style.Colors[cast(int)ImGui.Col.TextSelectedBg]        = make_ImVec4(0.26, 0.59, 0.98, 0.35);
    style.Colors[cast(int)ImGui.Col.DragDropTarget]        = make_ImVec4(0.11, 0.64, 0.92, 1.00);
    style.Colors[cast(int)ImGui.Col.NavHighlight]          = make_ImVec4(0.26, 0.59, 0.98, 1.00);
    style.Colors[cast(int)ImGui.Col.NavWindowingHighlight] = make_ImVec4(1.00, 1.00, 1.00, 0.70);
    style.Colors[cast(int)ImGui.Col.NavWindowingDimBg]     = make_ImVec4(0.80, 0.80, 0.80, 0.20);
    style.Colors[cast(int)ImGui.Col.ModalWindowDimBg]      = make_ImVec4(0.80, 0.80, 0.80, 0.35);
    style.GrabRounding                   = 2.3;
    style.FrameRounding                  = 2.3;
}

dark_theme_2 :: () {
    //imGuiIO.Fonts->AddFontFromFileTTF("../data/Fonts/Ruda-Bold.ttf", 15.0f, &config);
    style := ImGui.GetStyle();

    style.FrameRounding = 4.0;
    style.GrabRounding = 4.0;
    
    style.Colors[ImGui.Col.Text] = make_ImVec4(0.95, 0.96, 0.98, 1.00);
    style.Colors[ImGui.Col.TextDisabled] = make_ImVec4(0.36, 0.42, 0.47, 1.00);
    style.Colors[ImGui.Col.WindowBg] = make_ImVec4(0.11, 0.15, 0.17, 1.00);
    style.Colors[ImGui.Col.ChildBg] = make_ImVec4(0.15, 0.18, 0.22, 1.00);
    style.Colors[ImGui.Col.PopupBg] = make_ImVec4(0.08, 0.08, 0.08, 0.94);
    style.Colors[ImGui.Col.Border] = make_ImVec4(0.08, 0.10, 0.12, 1.00);
    style.Colors[ImGui.Col.BorderShadow] = make_ImVec4(0.00, 0.00, 0.00, 0.00);
    style.Colors[ImGui.Col.FrameBg] = make_ImVec4(0.20, 0.25, 0.29, 1.00);
    style.Colors[ImGui.Col.FrameBgHovered] = make_ImVec4(0.12, 0.20, 0.28, 1.00);
    style.Colors[ImGui.Col.FrameBgActive] = make_ImVec4(0.09, 0.12, 0.14, 1.00);
    style.Colors[ImGui.Col.TitleBg] = make_ImVec4(0.09, 0.12, 0.14, 0.65);
    style.Colors[ImGui.Col.TitleBgActive] = make_ImVec4(0.08, 0.10, 0.12, 1.00);
    style.Colors[ImGui.Col.TitleBgCollapsed] = make_ImVec4(0.00, 0.00, 0.00, 0.51);
    style.Colors[ImGui.Col.MenuBarBg] = make_ImVec4(0.15, 0.18, 0.22, 1.00);
    style.Colors[ImGui.Col.ScrollbarBg] = make_ImVec4(0.02, 0.02, 0.02, 0.39);
    style.Colors[ImGui.Col.ScrollbarGrab] = make_ImVec4(0.20, 0.25, 0.29, 1.00);
    style.Colors[ImGui.Col.ScrollbarGrabHovered] = make_ImVec4(0.18, 0.22, 0.25, 1.00);
    style.Colors[ImGui.Col.ScrollbarGrabActive] = make_ImVec4(0.09, 0.21, 0.31, 1.00);
    style.Colors[ImGui.Col.CheckMark] = make_ImVec4(0.28, 0.56, 1.00, 1.00);
    style.Colors[ImGui.Col.SliderGrab] = make_ImVec4(0.28, 0.56, 1.00, 1.00);
    style.Colors[ImGui.Col.SliderGrabActive] = make_ImVec4(0.37, 0.61, 1.00, 1.00);
    style.Colors[ImGui.Col.Button] = make_ImVec4(0.20, 0.25, 0.29, 1.00);
    style.Colors[ImGui.Col.ButtonHovered] = make_ImVec4(0.28, 0.56, 1.00, 1.00);
    style.Colors[ImGui.Col.ButtonActive] = make_ImVec4(0.06, 0.53, 0.98, 1.00);
    style.Colors[ImGui.Col.Header] = make_ImVec4(0.20, 0.25, 0.29, 0.55);
    style.Colors[ImGui.Col.HeaderHovered] = make_ImVec4(0.26, 0.59, 0.98, 0.80);
    style.Colors[ImGui.Col.HeaderActive] = make_ImVec4(0.26, 0.59, 0.98, 1.00);
    style.Colors[ImGui.Col.Separator] = make_ImVec4(0.20, 0.25, 0.29, 1.00);
    style.Colors[ImGui.Col.SeparatorHovered] = make_ImVec4(0.10, 0.40, 0.75, 0.78);
    style.Colors[ImGui.Col.SeparatorActive] = make_ImVec4(0.10, 0.40, 0.75, 1.00);
    style.Colors[ImGui.Col.ResizeGrip] = make_ImVec4(0.26, 0.59, 0.98, 0.25);
    style.Colors[ImGui.Col.ResizeGripHovered] = make_ImVec4(0.26, 0.59, 0.98, 0.67);
    style.Colors[ImGui.Col.ResizeGripActive] = make_ImVec4(0.26, 0.59, 0.98, 0.95);
    style.Colors[ImGui.Col.Tab] = make_ImVec4(0.11, 0.15, 0.17, 1.00);
    style.Colors[ImGui.Col.TabHovered] = make_ImVec4(0.26, 0.59, 0.98, 0.80);
    style.Colors[ImGui.Col.TabActive] = make_ImVec4(0.20, 0.25, 0.29, 1.00);
    style.Colors[ImGui.Col.TabUnfocused] = make_ImVec4(0.11, 0.15, 0.17, 1.00);
    style.Colors[ImGui.Col.TabUnfocusedActive] = make_ImVec4(0.11, 0.15, 0.17, 1.00);
    style.Colors[ImGui.Col.PlotLines] = make_ImVec4(0.61, 0.61, 0.61, 1.00);
    style.Colors[ImGui.Col.PlotLinesHovered] = make_ImVec4(1.00, 0.43, 0.35, 1.00);
    style.Colors[ImGui.Col.PlotHistogram] = make_ImVec4(0.90, 0.70, 0.00, 1.00);
    style.Colors[ImGui.Col.PlotHistogramHovered] = make_ImVec4(1.00, 0.60, 0.00, 1.00);
    style.Colors[ImGui.Col.TextSelectedBg] = make_ImVec4(0.26, 0.59, 0.98, 0.35);
    style.Colors[ImGui.Col.DragDropTarget] = make_ImVec4(1.00, 1.00, 0.00, 0.90);
    style.Colors[ImGui.Col.NavHighlight] = make_ImVec4(0.26, 0.59, 0.98, 1.00);
    style.Colors[ImGui.Col.NavWindowingHighlight] = make_ImVec4(1.00, 1.00, 1.00, 0.70);
    style.Colors[ImGui.Col.NavWindowingDimBg] = make_ImVec4(0.80, 0.80, 0.80, 0.20);
    style.Colors[ImGui.Col.ModalWindowDimBg] = make_ImVec4(0.80, 0.80, 0.80, 0.35);
}

imgui_init :: (ui: *UI_State, window_handle: *void) {
    #if ACTUALLY_USE_RAYLIB
        ImGui_Impl_SetupGLContext();

    ImGui_Impl_CreateContext(ui);
    ImGui.StyleColorsDark();
    style := ImGui.GetStyle();
    style.ScaleAllSizes(style, 1.2);

    dark_theme_2();

    font_file      :: "resources/fonts/Roboto-Regular.ttf"; font_size :: 20;
    font_file_mono :: "resources/fonts/consola.ttf";

    io := ImGui.GetIO();
    io.Fonts.AddFontFromFileTTF(io.Fonts, font_file, 20);
    ui.small_font     = io.Fonts.AddFontFromFileTTF(io.Fonts, font_file, 16);
    ui.monospace_font = io.Fonts.AddFontFromFileTTF(io.Fonts, font_file_mono, 18);

    ImGui_Impl_Init(ui, window_handle);

    #if !ACTUALLY_USE_RAYLIB
        ImGui_Impl_SetupInputModuleKeymap(ui);
}
