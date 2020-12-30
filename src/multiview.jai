MAXIMUM_VIEWS :: 45; // must match shader value

Multiview_State :: struct {
    enabled := true;
    num_views: u16 = 45;
    subview_w: int = 800;

    force_num_views: int;

    device_params: Looking_Glass_Device;

    offscreen: struct {
        pass: Pass;
        color: Texture;
        depth: Texture;
    }
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

calc_lkg_subquilt_size :: (fb_size: Vector2_u16) -> Vector2_u16 {
    using ctx();

    if get_num_views() == 1
        return v2u16(fb_size.width, fb_size.height);

    aspect := cast(float)fb_size.width / cast(float)fb_size.height;
    width  := max(10, cast(int)subview_w);
    return v2u16(xx width, cast(u16)(cast(float)width / aspect));
}

create_multiview_pass :: (fb_size: Vector2_u16) {
    assert(fb_size.width > 0 && fb_size.height > 0);
    sz := calc_lkg_subquilt_size(fb_size);
    assert(sz.width > 0 && sz.height > 0);

    using context.state.multiview;
    // offscreen rendertarget
    {
        using offscreen;
        create_texture(*color, sz, array_size=num_views, format=.BGRA8, type=.Render_Target_Color, label="multiview-offscreen-color");
        create_texture(*depth, sz, array_size=num_views, format=.D24S8, type=.Render_Target_Depth, label="multiview-offscreen-depth");
        pass.color[0] = *color;
        pass.depth = *depth;
        pass.label = "multiview-offscreen";
    }
}

Lenticular_Constants :: struct {
    pitch: float;
    slope: float;
    center: float;
    subpixelSize: float;
    tile: Vector4;
    viewPortion: Vector4;
    aspect: Vector4;
    fringe: float;
    verticalOffset: float;

    _ScreenParams: Vector4;
}
#scope_file
#import "Basic";
#import "Math";
#import "host_common";
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

