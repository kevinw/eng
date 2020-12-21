MAXIMUM_VIEWS :: 45; // must match shader value

Multiview_State :: struct {
    force_num_views: int;
    num_views: int;
    subview_w: int;

    pass: *Pass;
}

toggle_multiview :: () {
    using ctx();
    force_num_views = ifx get_num_views() > 1 then 1 else -1;
    logprint("multiview", "changing to % views", force_num_views);
}

get_num_views :: () -> int {
    using ctx();

    if force_num_views != -1 return force_num_views;

    return min(MAXIMUM_VIEWS, max(1, cast(int)num_views));
}

calc_lkg_subquilt_size :: (fb_size: Vector2Int) -> Vector2Int {
    using ctx();

    if get_num_views() == 1
        return v2int(fb_size.width, fb_size.height);

    aspect := cast(float)fb_size.width / cast(float)fb_size.height;
    width := max(10, cast(int)subview_w);
    return v2int(width, cast(float)width / aspect);
}

create_multiview_pass :: (fb_size: Vector2Int) {
    sz := calc_lkg_subquilt_size(fb_size);
    assert(sz.width > 0 && sz.height > 0);
    {
    }
}

#scope_file
#import "Basic";
#import "renderer";
#import "math_extra";

Blitter :: struct {
    pass: Pass;
    pipeline: Pipeline;
    //bindings: Bindings;
}

ctx :: () -> *Multiview_State {
    return *context.state.multiview;
}

