
im_set_texture :: inline (using ctx: *Im_Context, texture: *Texture) {
    _unsafe_im_set_texture(ctx, texture);
}


ObjectIDInfo :: struct { // must match unlit_texture.hlsl
    entity_id:         u32;
    entity_generation: s32;
    depth:             float;
}

get_hovered_entities :: (im_ctx: *Im_Context) -> []ObjectIDInfo {
    ctx := cast(*Im_Context_R)im_ctx;
    return ctx.mousepick_hovered;
}

renderer_Im_Draw_Callback :: (im_ctx: *Im_Context, indices: [] u16, vertices: [] Im_Vertex, draws: [] Im_Draw_Command) {
    ctx := cast(*Im_Context_R)im_ctx;
    using ctx;

    MAX_MOUSEPICK_COUNT :: 50;
    if track_mouse && !did_init {
        mousepick_objectids         = create_structured_buffer(size_of(ObjectIDInfo), MAX_MOUSEPICK_COUNT, debug_name = "mousepick_objectids");
        mousepick_objectids_staging = create_structured_buffer(size_of(ObjectIDInfo), MAX_MOUSEPICK_COUNT, .Staging, debug_name = "mousepick_objectids_staging");
        mousepick_objectids_count   = create_count_buffer(debug_name = "mousepick_objectids_count");
        did_init = true;
    }

    reset_mousepick_counts := false;
    if track_mouse {
        if current_frame != context.state.Time.frame_count {
            // note, this will happen asynchronously. we're getting previous values
            gpu_copy_buffer_count(dest=*mousepick_objectids_count, src=*mousepick_objectids);
            gpu_copy_buffer(dest=*mousepick_objectids_staging, src=*mousepick_objectids);

            current_frame = context.state.Time.frame_count;
            reset_mousepick_counts = true;

            MousePick :: struct {
                infos: [MAX_MOUSEPICK_COUNT]ObjectIDInfo;
            }
            total_objs := 0;
            count: u32;
            {
                gpu_count: *u32;
                get_constant_buffer_ptr(*gpu_count, *mousepick_objectids_count, usage=.Read);
                count = <<gpu_count;
            }
            {
                mousepick_hovered.count = 0;
                if count > 0 {
                    buf: *MousePick;
                    get_constant_buffer_ptr(*buf, *mousepick_objectids_staging, usage=.Read);
                    for count_i: 0..count-1 {
                        if count_i >= MAX_MOUSEPICK_COUNT break;
                        it := buf.infos[count_i];
                        array_add(*mousepick_hovered, buf.infos[count_i]);
                    }
                }
                // TODO: @Perf just insert sorted by depth to begin with
                Sort.quick_sort(mousepick_hovered, (a, b) => Sort.compare_floats(a.depth, b.depth));
            }
        }
    }

    apply_viewport();
    if current_blend
        apply_pipeline(*pipeline_blend);
    else
        apply_pipeline(*pipeline_no_blend);

    {
        // TODO: only update this when necessary
        using constants : *Constants;
        get_constant_buffer_ptr(*constants, *constant_buffer);

        if im_ctx.fullscreen_ortho {
            projection  = orthographic_projection_matrix(0, 1, 1, 0, -100, 100);
            view = matrix4_identity();
            translation = make_vector3(0, 0, 0);
        } else {
            cam := context.state.current_im_camera;
            calc_matrices(cam);
            projection  = cam.projection_matrix;
            view        = cam.view_matrix;
            translation = cam.per_view_translation;
        }
    }

    if track_mouse {
        mouse_x, mouse_y := platform.get_client_mouse_pos(get_swapchain_native_window_handle());

        using fragment_constants: *Fragment_Constants;
        get_constant_buffer_ptr(*fragment_constants, *fragment_constant_buffer);
        currently_drawing_entity_id         = im_ctx.entity_handle.id;
        currently_drawing_entity_generation = im_ctx.entity_handle.generation;
        if im_ctx.track_mouse {
            mouse_xy.x = cast(float)mouse_x;
            mouse_xy.y = cast(float)mouse_y;
        } else {
            mouse_xy.x = -1;
            mouse_xy.y = -1;
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
    if track_mouse
        apply_constant_buffers(.Fragment, *fragment_constant_buffer);

    color_texture := current_texture;
    if color_texture == null
        color_texture = *renderer.white_texture;


    pick_buffer: *Buffer = null;
    if track_mouse
        pick_buffer = *mousepick_objectids;
    apply_bindings(*shader, to_array(vertex_buffer), *index_buffer, color_texture);
    apply_uav(pick_buffer, new_count = ifx reset_mousepick_counts then cast(u32)0 else 0xffffffff);
    idx_buffer_offset: u32;
    for draw_cmd: draw_array {
        num_instances := context.state.multiview.num_views;
        draw(num_elements = draw_cmd.index_count,
            num_instances = num_instances,
            base_element = idx_buffer_offset);
        idx_buffer_offset += draw_cmd.index_count;
    }
    if pick_buffer != null
        apply_uav(null);
}

im_init_renderer :: (using ctx: *Im_Context_R, index_elements := 4096, vertex_elements := 4096, draw_elements := 64) {
    assert(ctx.renderer != null, "Please set the 'renderer' pointer inside Im_Context_R");

    im_init(ctx, index_elements, vertex_elements, draw_elements, renderer_Im_Draw_Callback);

    index_buffer  = create_dynamic_buffer(cast(u32)(index_elements * size_of(u32)), .Index,         debug_name="im index buffer");
    vertex_buffer = create_dynamic_buffer(cast(u32)(vertex_elements * size_of(Im_Vertex)), .Vertex, debug_name="im vertex buffer");

    constant_buffer          = create_constant_buffer(Constants, debug_name="im vert constants");
    fragment_constant_buffer = create_constant_buffer(Fragment_Constants, debug_name="im frag constants");

    filename ::"resources/shaders/unlit_texture.hlsl";
    ok := load_shader_from_file(*shader, filename);
    assert(ok, "did not compile shader '%'", filename);
    pipeline_blend = make_pipeline(*shader, .Triangles,
        cull_mode = .None,
        blend_mode = .Alpha_Blended,
        depth_stencil_opts = .{
            depth_write = false,
            depth_compare_func = .Always,
        },
        label = "im alpha pipeline",
    );

    pipeline_no_blend = make_pipeline(*shader, .Triangles,
        cull_mode = .None,
        blend_mode = .Default,
        depth_stencil_opts = .{
            depth_write = true,
            depth_compare_func = .Less,
        },
        label = "im depth write pipeline",
    );
}

Im_Context_R :: struct {
    using base: Im_Context;

    renderer:                 *Renderer;
    vertex_buffer:            Buffer;
    index_buffer:             Buffer;
    constant_buffer:          Buffer;
    fragment_constant_buffer: Buffer;
    pipeline_blend:           Pipeline;
    pipeline_no_blend:        Pipeline;
    pipeline_depth_test:      Pipeline;
    shader:                   Shader;

    // mousepick
    did_init:  bool = false;
    mousepick_hovered: [..]ObjectIDInfo;

    mousepick_objectids:         Buffer;
    mousepick_objectids_staging: Buffer;
    mousepick_objectids_count:   Buffer;
    current_frame: u64 = 99999; // we just use this to check if we have changed frames, so start at a high number
}

#scope_file

// TODO: generate the HLSL to insert into the shader via this struct!
Constants :: struct {
    projection: Matrix4;
    view: Matrix4;
    translation: Vector3;
}

Fragment_Constants :: struct {
    mouse_xy: Vector2;
    currently_drawing_entity_id: u32;
    currently_drawing_entity_generation: s32;
}

to_array :: (elems: ..$A) -> []A { return elems; }

Window_Creation :: #import "Window_Creation";
platform :: #import "platform";
#import "renderer_im";
#import "renderer";
#import "Basic";
#import "Math";
#import "camera";
Sort :: #import "Sort";
