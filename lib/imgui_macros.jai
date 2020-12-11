
PushGroup :: () #expand {
    ImGui.BeginGroup();
    `defer ImGui.EndGroup();
}

PushPopFont :: (font: *ImGui.ImFont) #expand {
    ImGui.PushFont(font);
    `defer ImGui.PopFont();
}

PushPopID :: (id_str: string) #expand {
    ImGui.PushID(id_str);
    `defer ImGui.PopID();
}

PushPopID :: (id_ptr: *void) #expand {
    ImGui.PushID(id_ptr);
    `defer ImGui.PopID();
}

BeginEnd :: (name: string, open: *bool = null, window_flags: ImGui.WindowFlags = .None) #expand {
    res := ImGui.Begin(name, open, window_flags);
    `defer { if res ImGui.End(); }
}

PushPopStyleColor :: (idx: ImGui.Col, col: ImGui.ImVec4) #expand {
    ImGui.PushStyleColor(idx, col);
    `defer ImGui.PopStyleColor();
}

PushPopStyleVar :: (idx: ImGui.StyleVar, var: ImGui.ImVec2) #expand {
    ImGui.PushStyleVar(idx, var);
    `defer ImGui.PopStyleVar();
}
