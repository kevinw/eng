#load "imgui_impl_d3d11.jai";

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
    
    using ImGui.Col;
    c := style.Colors;
    c[Text]                  = .{0.95, 0.96, 0.98, 1.00};
    c[TextDisabled]          = .{0.36, 0.42, 0.47, 1.00};
    c[WindowBg]              = .{0.11, 0.15, 0.17, 1.00};
    c[ChildBg]               = .{0.15, 0.18, 0.22, 1.00};
    c[PopupBg]               = .{0.08, 0.08, 0.08, 0.94};
    c[Border]                = .{0.08, 0.10, 0.12, 1.00};
    c[BorderShadow]          = .{0.00, 0.00, 0.00, 0.00};
    c[FrameBg]               = .{0.20, 0.25, 0.29, 1.00};
    c[FrameBgHovered]        = .{0.12, 0.20, 0.28, 1.00};
    c[FrameBgActive]         = .{0.09, 0.12, 0.14, 1.00};
    c[TitleBg]               = .{0.09, 0.12, 0.14, 0.65};
    c[TitleBgActive]         = .{0.08, 0.10, 0.12, 1.00};
    c[TitleBgCollapsed]      = .{0.00, 0.00, 0.00, 0.51};
    c[MenuBarBg]             = .{0.15, 0.18, 0.22, 1.00};
    c[ScrollbarBg]           = .{0.02, 0.02, 0.02, 0.39};
    c[ScrollbarGrab]         = .{0.20, 0.25, 0.29, 1.00};
    c[ScrollbarGrabHovered]  = .{0.18, 0.22, 0.25, 1.00};
    c[ScrollbarGrabActive]   = .{0.09, 0.21, 0.31, 1.00};
    c[CheckMark]             = .{0.28, 0.56, 1.00, 1.00};
    c[SliderGrab]            = .{0.28, 0.56, 1.00, 1.00};
    c[SliderGrabActive]      = .{0.37, 0.61, 1.00, 1.00};
    c[Button]                = .{0.20, 0.25, 0.29, 1.00};
    c[ButtonHovered]         = .{0.28, 0.56, 1.00, 1.00};
    c[ButtonActive]          = .{0.06, 0.53, 0.98, 1.00};
    c[Header]                = .{0.20, 0.25, 0.29, 0.55};
    c[HeaderHovered]         = .{0.26, 0.59, 0.98, 0.80};
    c[HeaderActive]          = .{0.26, 0.59, 0.98, 1.00};
    c[Separator]             = .{0.20, 0.25, 0.29, 1.00};
    c[SeparatorHovered]      = .{0.10, 0.40, 0.75, 0.78};
    c[SeparatorActive]       = .{0.10, 0.40, 0.75, 1.00};
    c[ResizeGrip]            = .{0.26, 0.59, 0.98, 0.25};
    c[ResizeGripHovered]     = .{0.26, 0.59, 0.98, 0.67};
    c[ResizeGripActive]      = .{0.26, 0.59, 0.98, 0.95};
    c[Tab]                   = .{0.11, 0.15, 0.17, 1.00};
    c[TabHovered]            = .{0.26, 0.59, 0.98, 0.80};
    c[TabActive]             = .{0.20, 0.25, 0.29, 1.00};
    c[TabUnfocused]          = .{0.11, 0.15, 0.17, 1.00};
    c[TabUnfocusedActive]    = .{0.11, 0.15, 0.17, 1.00};
    c[PlotLines]             = .{0.61, 0.61, 0.61, 1.00};
    c[PlotLinesHovered]      = .{1.00, 0.43, 0.35, 1.00};
    c[PlotHistogram]         = .{0.90, 0.70, 0.00, 1.00};
    c[PlotHistogramHovered]  = .{1.00, 0.60, 0.00, 1.00};
    c[TextSelectedBg]        = .{0.26, 0.59, 0.98, 0.35};
    c[DragDropTarget]        = .{1.00, 1.00, 0.00, 0.90};
    c[NavHighlight]          = .{0.26, 0.59, 0.98, 1.00};
    c[NavWindowingHighlight] = .{1.00, 1.00, 1.00, 0.70};
    c[NavWindowingDimBg]     = .{0.80, 0.80, 0.80, 0.20};
    c[ModalWindowDimBg]      = .{0.80, 0.80, 0.80, 0.35};
}

imgui_render :: (ui: *UI_State) {
    ImGui.Render();
    ok := ImGui_Impl_RenderDrawData(ui, ImGui.GetDrawData());
    assert(ok);
}

ui_change_scale :: (using ui: *UI_State, delta: int) {
    assert(original_style != null);

    config.current_style_scale += 0.2 * delta;

    style := ImGui.GetStyle();
    <<style = <<original_style;
    ImGui.Style.ScaleAllSizes(style, config.current_style_scale);
    reload_fonts_later = true;
}

imgui_init :: (ui: *UI_State, window_handle: *void) {
    ImGui_Impl_CreateContext(ui);
    ImGui.StyleColorsDark();
    {
        using style := ImGui.GetStyle();

        FrameRounding = 1.45;
        GrabRounding = 3.0;
        TabRounding = 4.5;

        // we keep the "original" style around for when we scale it later
        ui.original_style = New(type_of(<<style));
        <<ui.original_style = <<style;

        ImGui.Style.ScaleAllSizes(style, ui.config.current_style_scale);
    }

    //dark_theme_2();

    reload_fonts(ui);

    ImGui_Impl_Init(ui, window_handle);
    ImGui_Impl_SetupInputModuleKeymap(ui);


    io := ImGui.GetIO();
    io.ConfigWindowsMoveFromTitleBarOnly = true;
}

imgui_deinit :: (ui: *UI_State) {
    free(ui.original_style);
    ui.original_style = null;

    ImGui_Impl_Shutdown(ui);
}

reload_fonts :: (ui: *UI_State) {
    regular_size := 15 * ui.config.current_style_scale;
    small_size := 14 * ui.config.current_style_scale;
    mono_size := 11 * ui.config.current_style_scale;

    font_file      :: "resources/fonts/Roboto-Regular.ttf"; 
    font_file_mono :: "resources/fonts/consola.ttf";        
    fonts := ImGui.GetIO().Fonts;
    fonts.Clear(fonts);
    #if #run Compiler.get_build_options().optimization_level != .RELEASE {
        // In debug builds, load the TTF files from disk.
        fonts.AddFontFromFileTTF(fonts, font_file, regular_size);
        log("[ui] loading font %", font_file);
        ui.small_font     = fonts.AddFontFromFileTTF(fonts, font_file, small_size);
        log("[ui] loading font %", font_file_mono);
        ui.monospace_font = fonts.AddFontFromFileTTF(fonts, font_file_mono, mono_size);
    } else {
        // In release builds, just include the font files in the data segment.
        font_file_bytes      := decompress_from_data_segment(font_file);
        font_file_mono_bytes := decompress_from_data_segment(font_file_mono);

        // By default, AddFontFromMemoryTTF transfers ownership so we don't need to free the decompressed bytes buffers.
        fonts.AddFontFromMemoryTTF(fonts, font_file_bytes.data, cast(s32)font_file_bytes.count, regular_size);
        ui.small_font     = fonts.AddFontFromMemoryTTF(fonts, font_file_bytes.data, cast(s32)font_file_bytes.count, small_size);
        ui.monospace_font = fonts.AddFontFromMemoryTTF(fonts, font_file_mono_bytes.data, cast(s32)font_file_bytes.count, mono_size);
    }

    ui.FontSampler = null;

}

#scope_file

decompress_from_data_segment :: inline ($filename: string) -> string {
    compressed :: #run compress(File.read_entire_file(filename), filename);
    return decompress(compressed);
}

compress :: (bytes: string, debug_name := "") -> string {
    assert(bytes.count > 0 && bytes.data != null);

    compressed_bytes_len := lz4.LZ4_compressBound(cast(s32)bytes.count);
    compressed_bytes_buf := alloc(compressed_bytes_len + size_of(s32));

    res := lz4.LZ4_compress_default(bytes.data, compressed_bytes_buf + size_of(s32), cast(s32)bytes.count, compressed_bytes_len);
    assert(res != 0);

    <<(cast(*s32)compressed_bytes_buf) = cast(s32)bytes.count; // store the uncompressed length in the first 4 bytes.

    // TODO: should we realloc here? it's running at compile time right now so I don't really care.

    s: string;
    s.data = compressed_bytes_buf;
    s.count = res + size_of(s32);
    print("[dataseg] compressed % into % bytes: '%'\n", bytes.count, res, debug_name);
    return s;
}

decompress :: (compressed_bytes: string) -> string {
    original_uncompressed_size := <<(cast(*s32)compressed_bytes.data);
    //print("Decompressing (original uncompressed size %)\n", original_uncompressed_size);
    buf := alloc(original_uncompressed_size);

    compressed_size := cast(s32)(compressed_bytes.count - size_of(s32));
    //print("  compressed_size: %\n", compressed_size);

    res := lz4.LZ4_decompress_safe(compressed_bytes.data + size_of(s32), buf, compressed_size, original_uncompressed_size);
    assert(res > 0, "LZ4_decompress_safe returned %", res);
    // TODO: should we realloc here? it's running at compile time right now so I don't really care.

    s: string;
    s.data = buf;
    s.count = res;
    return s;
}

File :: #import "File";
lz4 :: #import "lz4-1.9.1"; // 1.9.3
Compiler :: #import "Compiler";
