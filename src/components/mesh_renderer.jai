Mesh_Renderer :: struct {
    using component: Component;

    mesh: *Mesh; @noserialize
}

draw :: (using it: *Mesh_Renderer) {
    if mesh != null
        dumb_draw_mesh(mesh);
}

#scope_file
#import "mesh_draw";
#import "mesh";
