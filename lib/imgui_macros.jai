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

PushPopStyleColor :: (idx: ImGui.Col, col: ImGui.ImVec4) #expand {
    ImGui.PushStyleColor(idx, col);
    `defer ImGui.PopStyleColor();
}

PushPopStyleVar :: (idx: ImGui.StyleVar, var: ImGui.ImVec2) #expand {
    ImGui.PushStyleVar(idx, var);
    `defer ImGui.PopStyleVar();
}

PushPopStyleVar :: (idx: ImGui.StyleVar, var: float) #expand {
    ImGui.PushStyleVar(idx, var);
    `defer ImGui.PopStyleVar();
}

PushPopIndent :: (indent: float) #expand {
    ImGui.Indent(indent);
    `defer ImGui.Unindent(indent);
}

BeginEndTooltip :: () #expand {
    ImGui.BeginTooltip();
    `defer ImGui.EndTooltip();
}

PushPopTextWrapPos :: (size: float) #expand {
    ImGui.PushTextWrapPos(size);
    `defer ImGui.PopTextWrapPos();
}

BeginEnd_return :: (name: string, open: *bool) #expand {
    `defer ImGui.End();
    if !ImGui.Begin(name, open)
        `return;
}

BeginEndMenu :: (name: string, code: Code) #expand {
    using ImGui;

    if BeginMenu(name) {
        defer EndMenu();
        #insert code;
    }
}

