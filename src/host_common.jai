Looking_Glass_Device :: struct {
    xpos, ypos, width, height: s32;
    pitch, tilt, center, invView, subp, fringe: float;
    ri, bi: s32;
    view_cone: float;
}

Game_Window_Flags :: enum_flags {
    Show_Editor                      :: (1 << 0);
    Show_Multiview                   :: (1 << 1);
    Show_Multiview_Even_If_No_Device :: (1 << 2);

    DEV_DEFAULT :: Game_Window_Flags.Show_Editor | .Show_Multiview;
}

Host_State :: struct {
    game_window_flags: Game_Window_Flags = .DEV_DEFAULT;
    jai_compiler_did_error: bool;
    jai_compiler_error_string: string;
    soloud_context:      *void;
    window_handle:       *void;
    debug_extra_window_handles: [..]*void;
    events_this_frame:   [..]Event;
    input_button_states: *[NUM_BUTTON_STATES] Key_Current_State; // since the Input module stores state in module globals, we need to pass sa pointer down to the dll
    pending_resizes:     *[..] Window_Resize_Record;
    mouse_delta: struct { x, y, z: int; }
    time:                float64;
    looking_glass_devices: []Looking_Glass_Device;
    change_window_state: #type (op: Window_State_Operation);
    built_with_backend: Host_Build_Backend;
}

Host_Build_Backend :: enum u32 { // so we don't have to #import Compiler...
    X64    :: 0;
    LLVM   :: 1;
}

get_compiler_codegen_backend :: () -> Host_Build_Backend {
    if #complete Compiler.get_build_options().backend == {
        case .X64;  return .X64;
        case .LLVM; return .LLVM;
    }
}

Window_State_Operation :: enum {
    Toggle_Borderless_Fullscreen;
    Toggle_Always_On_Top;
    Toggle_Transparent_When_Out_Of_Focus;
}

Sanity_Check_Info :: struct {
    size_of_context: int;
}


#scope_file
Compiler :: #import "Compiler";
#import "Input";
