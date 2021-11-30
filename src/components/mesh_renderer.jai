Mesh_Renderer :: struct {
    using component: Component;

    mesh: *Mesh; @noserialize
}

draw_all_mesh_renderers :: (world: *World, cam: *Camera) {
    screenp("TODO: finish draw_all_mesh_renderers");

    vertex_buffers: [..]Buffer;
    vertex_buffers.allocator = __temporary_allocator;

    using constants : *Constants;
    if !is_initialized(context.state.mesh_rendering_constants)
        context.state.mesh_rendering_constants = create_constant_buffer(Constants, debug_name="Mesh_Renderer");
    {
        get_constant_buffer_ptr(*constants, *context.state.mesh_rendering_constants);
        set_camera_constants(constants, cam);
        constants.model = matrix4_identity();
    }
    num_views := context.state.multiview.num_views;

    // TODO: @Perf this is all very inefficient. Ideally we could have
    // everything be GPU driven :) but at the very least, sorting mesh
    // renderers by their meshes, and then using instanced rendering would be a
    // big improvement.

    for * mesh_renderer: world._Mesh_Renderer {
        using mesh := mesh_renderer.mesh;
        if mesh == null continue;

        for * sub_meshes {
            if !has_value(it.material) {
                log_error("submesh has a null material");
                continue;
            }

            array_reset_keeping_memory(*vertex_buffers);
            array_add(*vertex_buffers, it.vertices);

            apply_pipeline(*it.material.pipeline);
            apply_bindings(*it.material.shader, vertex_buffers, *it.indices);

            xform := get_transform(mesh_renderer);
            if xform {
                // TODO: @Perf this per-instance model matrix is currently in
                // the same constants block as the camera stuff. not
                // performance ideal
                get_constant_buffer_ptr(*constants, *context.state.mesh_rendering_constants);
                constants.model = get_matrix(xform);
            } else {
                constants.model = matrix4_identity();
            }

            apply_constant_buffers(.Vertex, *context.state.mesh_rendering_constants);
            draw(num_instances = num_views);
        }
    }
}

#scope_file
#import "unlit_shader_constants";
#import "renderer";
#import "mesh_draw";
#import "mesh";
