
// TODO: generate the HLSL to insert into the shader via this struct!
Constants :: struct {
    projection, view, model: Matrix4;
    viewConeSweep: float;
    projModifier: float;
    numViews: s32;
}

set_camera_constants :: (using constants: *Constants, cam: *Camera) {
    holoplay_capture := context.state.current_im_holoplay_capture;
    num_views := context.state.multiview.num_views;

    calc_matrices(cam);

    if num_views > 1 {
        dist           := reset_lkg_camera(cam, holoplay_capture);
        view_cone      := context.state.multiview.device_params.view_cone;

        viewConeSweep   = -dist * tan(view_cone * holoplay_capture.view_cone_modifier * TO_RADIANS);
        projModifier    = 1 / (holoplay_capture.size * camera_aspect(cam));
    } else {
        viewConeSweep = 0;
        projModifier  = 1;
    }
    
    projection    = cam.projection_matrix;
    view          = cam.view_matrix;
    numViews      = num_views;
}

Fragment_Constants :: struct {
    mouse_xy: Vector2;
    currently_drawing_entity_id: u32;
    currently_drawing_entity_generation: s32;
}

#scope_file
#import "camera";
#import "Math";
#import "math_extra";
