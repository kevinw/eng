Looking_Glass_Device :: struct {
    xpos, ypos, width, height: s32;
    pitch, tilt, center, invView, subp, fringe: float;
    ri, bi: s32;
}

Host_State :: struct {
    jai_compiler_did_error: bool;
    jai_compiler_error_string: string;
    soloud_context:      *void;
    window_handle:       *void;
    events_this_frame:   [..]Event;
    input_button_states: *[NUM_BUTTON_STATES] Key_Current_State; // since the Input module stores state in module globals, we need to pass sa pointer down to the dll
    pending_resizes:     *[..] Window_Resize_Record;
    mouse_delta_x: int;
    mouse_delta_y: int;
    mouse_delta_z: int;
    time:                float64;

    looking_glass_devices: []Looking_Glass_Device;

    change_window_state: #type (op: Window_State_Operation);

    toggle_borderless_fullscreen: #type ();
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
#import "Input";
