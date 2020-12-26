create :: (main_renderer: *Renderer, debug := true) {
    using ctx();
    assert(window == null, "Window was already created.");
    window = create_window(400, 400, "lkg window", 20, 20);
    init_from_main_window(main_renderer=main_renderer,
        new_renderer_ptr=*mview_renderer, window, debug=debug);
}

close :: () {
    using ctx();
    if window != null
        DestroyWindow(window);
}

State :: struct {
    window:         Window_Type;
    mview_renderer: Renderer;
}

#scope_file

ctx :: () -> *State { return *context.state.mview_window; }

#import "Window_Creation";
#import "Input";
#import "renderer";
#import "Basic";
#import "Windows";
