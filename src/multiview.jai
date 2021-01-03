MAXIMUM_VIEWS :: 45; // must match shader value

Multiview_State :: struct {
    draw_default_quilt := false;
    num_views: u16 = 45;
    num_views_this_frame: u16;
    subview_w: int = 768;

    device_params: Looking_Glass_Device;

    lenticular_shader: Shader;
    lenticular_shader_quilt: Shader;

    pipeline: Pipeline;
    pipeline_quilt: Pipeline;

    constant_buffer: Buffer;

    default_quilt_texture: Texture;

    offscreen: struct {
        pass: Pass;
        color: Texture;
        depth: Texture;
    }
}

calc_lkg_subquilt_size :: (fb_size: Vector2_u16) -> Vector2_u16 {
    using ctx();

    aspect := cast(float)fb_size.width / cast(float)fb_size.height;
    width  := max(10, cast(int)subview_w);
    res := v2u16(xx width, cast(u16)(cast(float)width / aspect));
    print("calc_lkg_subquilt_size: % -> %\n", fb_size, res);
    return res;
}

create_multiview_pass :: (fb_size: Vector2_u16) {
    assert(fb_size.width > 0 && fb_size.height > 0);
    sz := calc_lkg_subquilt_size(fb_size);
    assert(sz.width > 0 && sz.height > 0);

    using context.state.multiview;

    tex_ok: bool;
    tex_ok, default_quilt_texture = load_texture_from_file("resources/textures/default-quilt.jpg", sampling_type = .Linear);
    assert(tex_ok);

    // TODO: we need a Material which wraps up a shader, constant blocks, blend
    // modes, and ...
    {
        shader_defines :: "QUILT_TEXTURE\01\0";
        ok := load_shader_from_file(*lenticular_shader_quilt, "resources/shaders/lenticular2.hlsl", defines=shader_defines);
        assert(ok);
    }

    {
        ok := load_shader_from_file(*lenticular_shader, "resources/shaders/lenticular2.hlsl");
        assert(ok);
    }

    pipeline = make_pipeline(*lenticular_shader, .Triangles,
        cull_mode  = .None,
        blend_mode = .Default,
        depth_stencil_opts = .{
            depth_write        = false,
            depth_compare_func = .Always,
        },
    );

    pipeline_quilt = make_pipeline(*lenticular_shader_quilt, .Triangles,
        cull_mode  = .None,
        blend_mode = .Default,
        depth_stencil_opts = .{
            depth_write        = false,
            depth_compare_func = .Always,
        },
    );

    // offscreen rendertarget
    {
        using offscreen;
        create_texture(*color, sz, array_size=num_views, format=.BGRA8, type=.Render_Target_Color, label="multiview-offscreen-color");
        create_texture(*depth, sz, array_size=num_views, format=.D24S8, type=.Render_Target_Depth, label="multiview-offscreen-depth");
        pass.color[0] = *color;
        pass.depth    = *depth;
        pass.label    = "multiview-offscreen";
    }

    // TODO: @Speed make this immutable and just recreate it when necessary?
    constant_buffer = create_constant_buffer(Lenticular_Constants);
    {
        lenticular_constants: *Lenticular_Constants;
        get_constant_buffer_ptr(*lenticular_constants, *constant_buffer);
        apply_settings_to_buffer_ptr(lenticular_constants, fb_size);
    }
}

draw_lenticular_lightfield_to_backbuffer :: () {
    using ctx();

    pip: *Pipeline;
    shd: *Shader;

    if draw_default_quilt {
        pip = *pipeline_quilt;
        shd = *lenticular_shader_quilt;
    } else {
        pip = *pipeline;
        shd = *lenticular_shader;
    }

    apply_viewport();
    apply_pipeline(pip);
    {
        lenticular_constants: *Lenticular_Constants;
        get_constant_buffer_ptr(*lenticular_constants, *constant_buffer);
        fb_size: Vector2_u16;
        fb_size.width  = cast(u16)device_params.width;
        fb_size.height = cast(u16)device_params.height;
        assert(fb_size.width > 0 && fb_size.height > 0);
        apply_settings_to_buffer_ptr(lenticular_constants, fb_size);
    }
    apply_constant_buffers(.Fragment, *constant_buffer);
    if draw_default_quilt {
        apply_bindings(shd, .[], null, *default_quilt_texture, force_array_texture=false);
    } else {
        apply_bindings(shd, .[], null, offscreen.pass.color[0],
            // TODO: instead of passing a hacky bool here, should we instead notice
            // during reflection that the texture at slot N is a TextureArray? yes
            force_array_texture=true
        );
    }
    draw(3); // fullscreen triangle
}

Lenticular_Constants :: struct {
    // calibration values
    pitch:          float;
    tilt:          float;
    center:         float;
    invView:        s32;
    subpixelSize:   float;
    displayAspect:  float;
    ri:             s32;
    bi:             s32;

    // quilt settings
    tile:           Vector3;
    pad0:           float;
    viewPortion:    Vector2;
    quiltAspect:    float;
    overscan:       s32;
    quiltInvert:    s32;

    debug:          s32;
}

apply_settings_to_buffer_ptr :: (using constants: *Lenticular_Constants, fb_size: Vector2_u16) {
    using ctx();

    viewColumns := 5; // TODO: no
    viewRows    := 9;

    //print("device_params: %\n", formatStruct(device_params, use_newlines_if_long_form=true));

    assert(device_params.width > 0);
    use_aspect := cast(float)device_params.width / cast(float)device_params.height;
    assert(use_aspect > 0);
 
    quiltWidth  := cast(float)fb_size.width;
    quiltHeight := cast(float)fb_size.height;

    quilt_image_aspect := use_aspect;
    if draw_default_quilt {
        assert(default_quilt_texture.width > 0 && default_quilt_texture.height > 0);
        quilt_image_aspect = cast(float)default_quilt_texture.width / cast(float)default_quilt_texture.height;
        assert(quilt_image_aspect > 0);

        quiltWidth  = cast(float)default_quilt_texture.width;
        quiltHeight = cast(float)default_quilt_texture.height;
    }

    viewWidth   := quiltWidth / viewColumns;
    viewHeight  := quiltHeight / viewRows;

    pitch         = device_params.pitch;
    tilt          = device_params.tilt;
    center        = device_params.center;
    invView       = cast(s32)device_params.invView;
    subpixelSize  = device_params.subp;
    displayAspect = use_aspect;
    ri            = device_params.ri;
    bi            = device_params.bi;

    tile          = make_vector3(xx viewColumns, xx viewRows, xx num_views);
    viewPortion   = make_vector2(cast(float)viewColumns * viewWidth / quiltWidth,
                                 cast(float)viewRows * viewHeight / quiltHeight);
    quiltAspect   = quilt_image_aspect;
    overscan      = 0;
    quiltInvert   = cast(s32)draw_default_quilt;
    debug         = 0;

    //print("constants from jai:\n%\n", formatStruct(<<constants, use_newlines_if_long_form=true));
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

