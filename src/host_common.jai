Host_State :: struct {
    jai_compiler_did_error: bool;
    jai_compiler_error_string: string;
    soloud_context: *void;
    window_handle: *void;

    events_this_frame: [..]Input.Event;
    input_button_states: *[Input.NUM_BUTTON_STATES] Input.Key_Current_State; // since the Input module stores state in module globals, we need to pass sa pointer down to the dll
}

Sanity_Check_Info :: struct {
    size_of_context: int;
}


#scope_file
Input :: #import "Input";
