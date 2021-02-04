dumb_draw_mesh :: (using mesh: *Mesh) {
    for * sub_meshes
        dumb_draw_sub_mesh(it);
}

dumb_draw_sub_mesh :: (using submesh: *Sub_Mesh) {
    if !has_value(material) {
        logprint("mesh_draw", "submesh has a null material");
        return;
    }

    vertex_buffers: [..]Buffer;
    vertex_buffers.allocator = __temporary_allocator;
    array_add(*vertex_buffers, vertices);

    apply_pipeline(*material.pipeline);
    apply_bindings(*material.shader, vertex_buffers, *indices);
    draw();
}

#scope_file
#import "renderer";
#import "mesh";
#import "Basic";
#import "Live_Types";
