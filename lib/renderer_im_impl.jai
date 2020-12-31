im_set_texture :: inline (using ctx: *Im_Context, texture: *Texture) {
    _unsafe_im_set_texture(ctx, texture);
}

renderer_Im_Draw_Callback :: (im_ctx: *Im_Context, indices: [] u16, vertices: [] Im_Vertex, draws: [] Im_Draw_Command) {
    ctx := cast(*Im_Context_R)im_ctx;
    using ctx;

    apply_viewport();
    if current_blend
        apply_pipeline(*pipeline_blend);
    else
        apply_pipeline(*pipeline_no_blend);


    w:float = xx renderer.depth_buffer_desc.Width;
    h:float = xx renderer.depth_buffer_desc.Height;
    {
        // TODO: only update this when necessary
        using constants : *Constants;
        get_constant_buffer_ptr(*constants, *constant_buffer);

        if im_ctx.fullscreen_ortho {
            projection  = orthographic_projection_matrix(0, 1, 1, 0, -100, 100);
            view = matrix4_identity();
            translation = make_vector3(0, 0, 0);
        } else {
            cam := *context.state.editor.scene_camera;
            forward := rotate(Vector3.{0, 0, 1}, cam.rotation);
            look_at := cam.position + forward * 10;

            projection = make_projection_matrix(30, w/h, -50, 50, depth_range_01 = true);
            view = make_look_at_matrix(
                viewpoint = cam.position,
                look_at   = look_at,
                reference_up_vector = Vector3.{0, 1, 0}, x_is_forward = false);
            translation = make_vector3(0.005, 0.0, 0.0);
        }
    }

    // TODO: the following two memcpys could become an abstraction. moreover,
    // the buffer in debug mode could hold the type info of what it was created
    // with, and then verify that the thing you're copying into it seems right.
    //
    // like: copy_into_buffer(*vertex_buffer, vertices);
    //
    // this means the create_dynamic_buffer calls would change to include the
    // type and the count.
    gpu_verts: *Im_Vertex;
    {
        get_buffer_ptr(*vertex_buffer, *gpu_verts);
        memcpy(gpu_verts, vertices.data, vertices.count * size_of(Im_Vertex));
    }

    gpu_indices: *u16;
    {
        indices_32: [..]u32;
        indices_32.allocator = __temporary_allocator;
        for indices array_add(*indices_32, it);

        get_buffer_ptr(*index_buffer, *gpu_indices);
        memcpy(gpu_indices, indices_32.data, indices_32.count * size_of(u32));
    }

    apply_constant_buffers(.Vertex, *constant_buffer);

    color_texture := current_texture;
    if color_texture == null
        color_texture = *renderer.white_texture;

    apply_bindings(*shader, to_array(vertex_buffer), *index_buffer, color_texture);
    idx_buffer_offset: u32;
    for draw_cmd: draw_array {
        num_instances := context.state.multiview.num_views;
        draw(num_elements = draw_cmd.index_count,
            num_instances = num_instances,
            base_element = idx_buffer_offset);
        idx_buffer_offset += draw_cmd.index_count;
    }
}

im_init_renderer :: (using ctx: *Im_Context_R, index_elements := 4096, vertex_elements := 4096, draw_elements := 64) {
    assert(ctx.renderer != null, "Please set the 'renderer' pointer inside Im_Context_R");

    im_init(ctx, index_elements, vertex_elements, draw_elements, renderer_Im_Draw_Callback);

    index_buffer  = create_dynamic_buffer(cast(u32)(index_elements * size_of(u32)), .Index);
    vertex_buffer = create_dynamic_buffer(cast(u32)(vertex_elements * size_of(Im_Vertex)), .Vertex);
    constant_buffer = create_constant_buffer(Constants);

    filename ::"resources/shaders/unlit_texture.hlsl";
    ok := load_shader_from_file(*shader, filename);
    assert(ok, tprint("did not compile shader '%'", filename));
    pipeline_blend = make_pipeline(*shader, .Triangles,
        cull_mode = .None,
        blend_mode = .Alpha_Blended,
        depth_stencil_opts = .{
            depth_write = false,
            depth_compare_func = .Always,
        },
    );

    pipeline_no_blend = make_pipeline(*shader, .Triangles,
        cull_mode = .None,
        blend_mode = .Default,
        depth_stencil_opts = .{
            depth_write = false,
            depth_compare_func = .Always,
        },
    );
}

Im_Context_R :: struct {
    using base: Im_Context;

    renderer:          *Renderer;
    vertex_buffer:     Buffer;
    index_buffer:      Buffer;
    constant_buffer:   Buffer;
    pipeline_blend:    Pipeline;
    pipeline_no_blend: Pipeline;
    shader:            Shader;
}

#scope_file

// TODO: generate the HLSL to insert into the shader via this struct!
Constants :: struct {
    projection: Matrix4;
    view: Matrix4;
    translation: Vector3;
}

to_array :: (elems: ..$A) -> []A { return elems; }

#import "renderer_im";
#import "renderer";
#import "Basic";
#import "Math";
