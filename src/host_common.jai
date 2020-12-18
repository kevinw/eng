Host_State :: struct {
    jai_compiler_did_error: bool;
    jai_compiler_error_string: string;
    soloud_context:      *void;
    window_handle:       *void;
    events_this_frame:   [..]Event;
    input_button_states: *[NUM_BUTTON_STATES] Key_Current_State; // since the Input module stores state in module globals, we need to pass sa pointer down to the dll
    pending_resizes:     *[..] Window_Resize_Record;
    time:                float64;

    toggle_borderless_fullscreen: #type ();
}

Sanity_Check_Info :: struct {
    size_of_context: int;
}


#scope_file
#import "Input";
