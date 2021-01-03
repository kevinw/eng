//
// TODO: not sure this file should exist
//

create :: (main_renderer: *Renderer, debug := true, x: s32, y: s32, width: s32, height: s32, parent: Window_Type = null) {
    using ctx();
    assert(window == null, "Window was already created.");
    logprint("multiview_window", "Creating window with width=%, height=%", width, height);
    window = create_window(width, height, "", x, y, parent=parent);
    platform.set_window_borderless(window, true, x, y, width, height);
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
platform :: #import "platform";
