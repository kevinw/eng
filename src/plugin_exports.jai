#program_export
plugin_init :: (old_value: *void) {
    if old_value != null {
        old_state := cast(*type_of(state))old_value;
        state = << old_state;
        free(old_state);
    } else {
        on_host_init();
    }
}

#program_export
plugin_deinit :: (shutting_down: bool) -> *void {
    if shutting_down {
        on_host_shutdown();
        return null;
    }

    heap_state := cast(*type_of(state))alloc(size_of(type_of(state)) * 2); // * 2 for adding extra things on the end
    << heap_state = state;
    return heap_state;
}
