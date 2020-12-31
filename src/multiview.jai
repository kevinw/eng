MAXIMUM_VIEWS :: 45; // must match shader value

Multiview_State :: struct {
    enabled := true;
    num_views: u16 = 45;
    subview_w: int = 800;

    force_num_views: int;

    device_params: Looking_Glass_Device;

    lenticular_shader: Shader;
    constant_buffer: Buffer;
    pipeline: Pipeline;

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

    // TODO: we need a Material which wraps up a shader, constant blocks, blend modes, and 
    ok := load_shader_from_file(*lenticular_shader, "resources/shaders/lenticular.hlsl");
    assert(ok);

    pipeline = make_pipeline(*lenticular_shader, .Triangles,
        cull_mode = .None,
        blend_mode = .Default,
        depth_stencil_opts = .{
            depth_write = false,
            depth_compare_func = .Always,
        },
    );

    // offscreen rendertarget
    {
        using offscreen;
        create_texture(*color, sz, array_size=num_views, format=.BGRA8, type=.Render_Target_Color, label="multiview-offscreen-color");
        create_texture(*depth, sz, array_size=num_views, format=.D24S8, type=.Render_Target_Depth, label="multiview-offscreen-depth");
        pass.color[0] = *color;
        pass.depth = *depth;
        pass.label = "multiview-offscreen";
    }

    constant_buffer = create_constant_buffer(Lenticular_Constants);
    {
        lenticular_constants: *Lenticular_Constants;
        get_constant_buffer_ptr(*lenticular_constants, *constant_buffer);
        apply_settings_to_buffer_ptr(lenticular_constants);
    }
}

draw_lightfield :: () {
    using ctx();

    apply_viewport();
    apply_pipeline(*pipeline);
    apply_constant_buffers(.Fragment, *constant_buffer);
    apply_bindings(*lenticular_shader, .[], null, offscreen.pass.color[0]);
    draw(3);
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

    _ScreenParams: Vector4;
}

apply_settings_to_buffer_ptr :: (using constants: *Lenticular_Constants) {
    using ctx();

    print("device_params: %\n", formatStruct(device_params, use_newlines_if_long_form=true));

    assert(device_params.width > 0);
    use_aspect := cast(float)device_params.width / cast(float)device_params.height;
    assert(use_aspect > 0);
 
    pitch        = device_params.pitch;
    slope        = device_params.tilt;
    center       = device_params.center;
    subpixelSize = device_params.subp;
    viewColumns := 5; // TODO: no
    viewRows    := 9;
    tile         = make_vector4(xx viewColumns, xx viewRows, xx num_views, xx num_views);
    //viewPortion
    aspect       = make_vector4(
        use_aspect,
        // if it's the default aspect (-1), just use the same aspect as the screen
        use_aspect, //quiltSettings.aspect < 0 ? cal.aspect : quiltSettings.aspect,
        0, //quiltSettings.overscan ? 1 : 0
        0,
    );
    fringe       = device_params.fringe;

    color := *offscreen.color;
    _ScreenParams = make_vector4(
        cast(float)color.width,   // width of the camera’s target texture in pixels
        cast(float)color.height,  // height of the camera’s target texture in pixels
        cast(float)(1.0 + 1.0 / cast(float)color.width),    // z is 1.0 + 1.0/width
        cast(float)(1.0 + 1.0 / cast(float)color.height));  // w is 1.0 + 1.0/height

    print("%\n", <<constants);
}

#scope_file
#import "Basic";
#import "Math";
#import "host_common";
#import "renderer";
#import "math_extra";

ctx :: () -> *Multiview_State {
    return *context.state.multiview;
}

