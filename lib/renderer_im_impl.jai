renderer_Im_Draw_Callback :: (im_ctx: *Im_Context, indices: [] u16, vertices: [] Im_Vertex, draws: [] Im_Draw_Command) {
    ctx := cast(*Im_Context_R)im_ctx;
    using ctx;

    apply_viewport();
    apply_pipeline(*pipeline);

    w:float = xx renderer.depth_buffer_desc.Width;
    h:float = xx renderer.depth_buffer_desc.Height;
    {
        // TODO: only update this when necessary (when the framebuffer changes size)
        using constants : *Constants;
        get_constant_buffer_ptr(*constants, *constant_buffer);
        projection = orthographic_projection_matrix(0, w, h, 0, -1, 1);
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

    apply_constant_buffers(*constant_buffer);
    apply_bindings(*shader, to_array(vertex_buffer), *index_buffer);
    idx_buffer_offset: u32;
    for draw_cmd: draw_array {
        draw(num_elements = draw_cmd.index_count, base_element = idx_buffer_offset);
        idx_buffer_offset += draw_cmd.index_count;
    }
}

im_init_renderer :: (using ctx: *Im_Context_R, index_elements := 4096, vertex_elements := 4096, draw_elements := 64) {
    assert(ctx.renderer != null, "Please set the 'renderer' pointer inside Im_Context_R");

    im_init(ctx, index_elements, vertex_elements, draw_elements, renderer_Im_Draw_Callback);

    index_buffer  = create_dynamic_buffer(cast(u32)(index_elements * size_of(u32)), .Index);
    vertex_buffer = create_dynamic_buffer(cast(u32)(vertex_elements * size_of(Im_Vertex)), .Vertex);
    constant_buffer = create_constant_buffer(Constants);

    ok: bool;
    ok, shader   = load_shader_from_file(renderer, "unlit_texture.hlsl");
    assert(ok);
    pipeline = make_pipeline(*shader, .Triangles,
        cull_mode = .None,
    );
}

Im_Context_R :: struct {
    using base: Im_Context;

    renderer:      *Renderer;

    vertex_buffer:   Buffer;
    index_buffer:    Buffer;
    constant_buffer: Buffer;
    pipeline:        Pipeline;
    shader:          Shader;
}

#scope_file

Constants :: struct {
    projection: Matrix4;
}

to_array :: (elems: ..$A) -> []A { return elems; }

#import "renderer_im";
#import "renderer";
#import "Basic";
#import "Math";
