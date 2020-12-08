Host_State :: struct {
    jai_compiler_did_error: bool;
    jai_compiler_error_string: string;
    soloud_context: *void;
    window_handle: *void;

    host_events_this_frame: [..]Input.Event;
}

Sanity_Check_Info :: struct {
    size_of_context: int;
}


#scope_file
Input :: #import "Input";
