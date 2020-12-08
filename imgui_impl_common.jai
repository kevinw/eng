UI_State_Base :: struct {
    ctx: *ImGui.Context;

    small_font: *ImGui.ImFont;
    monospace_font: *ImGui.ImFont;

    Time: float64;
    MousePressed: [3]bool;
    MouseWheel: float;
}

imgui_alloc_context: Context;

// @Speed: maybe imgui should just get 
c_alloc :: (sz: u64, userdata: *void) -> *void #c_call {
    push_context << cast(*Context)userdata {
        return alloc(cast(s64)sz);
    }
}

c_free :: (ptr: *void, userdata: *void) #c_call {
    push_context << cast(*Context)userdata {
        free(ptr);
    }
}

_SetAllocators :: () {
    imgui_alloc_context = context;
    ImGui.SetAllocatorFunctions(c_alloc, c_free, *imgui_alloc_context);
}

ImGui_Impl_CreateContext :: (using ui_state: *UI_State) {
    _SetAllocators();
    ctx = ImGui.CreateContext();

    io := ImGui.GetIO();
    io.ConfigFlags_ |= .DockingEnable;
}

ImGui_Impl_ProcessInputEvent :: (using ui_state: *UI_State, events: []Input.Event) -> bool {
    using Input;
    io := ImGui.GetIO();
    for event: events {
        if event.type == {
            case .MOUSE_WHEEL;
                if event.wheel_delta > 0 MouseWheel = 1;
                if event.wheel_delta < 0 MouseWheel = -1;
                return true;
            case .KEYBOARD;
                if event.key_code == {
                    case .MOUSE_BUTTON_LEFT;   MousePressed[0] = event.key_pressed != 0;
                    case .MOUSE_BUTTON_MIDDLE; MousePressed[1] = event.key_pressed != 0;
                    case .MOUSE_BUTTON_RIGHT;  MousePressed[2] = event.key_pressed != 0;
                    case;
                        io.KeysDown[event.key_code] = event.key_pressed != 0;
                        io.KeyShift = event.shift_pressed;
                        io.KeyCtrl  = event.ctrl_pressed;
                        io.KeyAlt   = event.alt_pressed;
                }
                return true;
            case .TEXT_INPUT;
                buf := talloc(size_of(s32) + 1); // unicode rune + 0
                memcpy(buf, *event.utf32, size_of(s32));
                io.AddInputCharactersUTF8(io, buf);
                return true;
        }
    }
    return false;
}

ImGui_Impl_SetupInputModuleKeymap :: (using ui_state: *UI_State) {
    using Input.Key_Code;
    io := ImGui.GetIO();
    io.KeyMap[ImGui.Key.Tab] = xx TAB;                     // Keyboard mapping. ImGui will use those indices to peek into the io.KeyDown[] array.
    io.KeyMap[ImGui.Key.LeftArrow] = xx ARROW_LEFT;
    io.KeyMap[ImGui.Key.RightArrow] = xx ARROW_RIGHT;
    io.KeyMap[ImGui.Key.UpArrow] = xx ARROW_UP;
    io.KeyMap[ImGui.Key.DownArrow] = xx ARROW_DOWN;
    io.KeyMap[ImGui.Key.PageUp] = xx PAGE_UP;
    io.KeyMap[ImGui.Key.PageDown] = xx PAGE_DOWN;
    io.KeyMap[ImGui.Key.Home] = xx HOME;
    io.KeyMap[ImGui.Key.End] = xx END;
    io.KeyMap[ImGui.Key.Delete] = xx DELETE;
    io.KeyMap[ImGui.Key.Backspace] = xx BACKSPACE;
    io.KeyMap[ImGui.Key.Enter] = xx ENTER;
    io.KeyMap[ImGui.Key.Escape] = xx ESCAPE;
    io.KeyMap[ImGui.Key.A] = xx #char "A";
    io.KeyMap[ImGui.Key.C] = xx #char "C";
    io.KeyMap[ImGui.Key.V] = xx #char "V";
    io.KeyMap[ImGui.Key.X] = xx #char "X";
    io.KeyMap[ImGui.Key.Y] = xx #char "Y";
    io.KeyMap[ImGui.Key.Z] = xx #char "Z";
}

#scope_file
Input :: #import "Input";
