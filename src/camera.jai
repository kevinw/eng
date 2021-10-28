Camera :: struct {
    position: Vector3;
    rotation: Quaternion;
    fov_degrees: float = 60; // TODO: we should probably serialize radians and use set_fov_degrees as a function

    near_plane: float     = 0.1;
    far_plane:  float     = 1000;

    reverse_z  := false; // Invert so Z=1 at near plane
    infinite_z := false; // Far plane at infinity

    render_texture: *Texture; @noserialize @noui

    matrices_need_update := true;    @noserialize @noui
    last_calced_renderer: *Renderer; @noserialize @noui // TODO: I believe this goes away once we make the looking glass display have its own camera.
    last_w, last_h: u16; @noserialize @noui

    struct {
        view_matrix:       Matrix4;              @noserialize @noui
        projection_matrix: Matrix4;              @noserialize @noui
        view_projection_matrix: Matrix4;         @noserialize @noui
        inverse_view_projection_matrix: Matrix4; @noserialize @noui
    }
}

Holoplay_Capture :: struct {
    size:               float = 5;
    near_clip_factor:   float = 1.5;
    far_clip_factor:    float = 4;
    view_cone_modifier: float = 1;
}

set_position_and_rotation :: (camera: *Camera, position: Vector3, rotation: Quaternion) {
    camera.position = position;
    camera.rotation = rotation;
    camera.matrices_need_update = true;
}

/// Returns the camera's distance from the center, a positive number.
get_cam_distance :: (using camera: *Camera, using holoplay_capture: *Holoplay_Capture) -> (dist: float) {
    return size / tan(fov_degrees * TO_RADIANS * 0.5);
}

reset_lkg_camera :: (using camera: *Camera, holoplay_capture: *Holoplay_Capture) -> (dist: float) {
    dist := get_cam_distance(camera, holoplay_capture);

    //print("TODO: reset_lkg_camera %\n", dist);

    /*
    // set near and far clip planes based on dist
    near_plane = max(dist - size * near_clip_factor, 0.1);
    far_plane  = max(dist + size * far_clip_factor, near_plane);
    */

    return dist;
}

_update_matrices :: (using camera: *Camera) {
    forward := rotate(Vector3.{0, 0, 1}, rotation);
    up      := rotate(Vector3.{0, 1, 0}, rotation);
    look_at := position + forward * 10; // TODO: there's probably a better way

    aspect := camera_aspect(camera);
    projection_matrix = make_projection_matrix(fov_degrees * TO_RADIANS, aspect,
        near_plane, far_plane, depth_range_01 = true);

    view_matrix = make_look_at_matrix(
        viewpoint = position,
        look_at   = look_at,
        reference_up_vector = up,
        x_is_forward        = false);

    view_projection_matrix = multiply(projection_matrix, view_matrix);

    inverse_succeeded := false;
    inverse_view_projection_matrix, inverse_succeeded = inverse(view_projection_matrix);
    if !inverse_succeeded
        log_error("taking the inverse of the camera VP matrix failed");

    matrices_need_update = false;
    last_calced_renderer = get_renderer_ptr();
}

calc_matrices :: inline (using camera: *Camera) {
    if !matrices_need_update && get_renderer_ptr() == last_calced_renderer {
        w, h := pixel_size(camera);
        if w == last_w && h == last_h
            return;
    }

    _update_matrices(camera);
}

camera_aspect :: (camera: *Camera) -> float {
    if camera.render_texture
        return aspect(camera.render_texture.size);

    return framebuffer_aspect();
}

pixel_size :: (camera: *Camera) -> u16, u16 {
    sz := ifx camera.render_texture then camera.render_texture.size else framebuffer_size();
    return sz.x, sz.y;
}

screen_point_to_ray :: (using camera: *Camera, screen_pos: Vector2, view_index := -1) -> Ray {
    target_w, target_h := pixel_size(camera);
    mouse_viewport := v4(
         (cast(float)screen_pos.x / cast(float)target_w - 0.5) * 2.0,
        -(cast(float)screen_pos.y / cast(float)target_h - 0.5) * 2.0,
        z = 0.1, // works if either proj is 0->1 or -1->1
        w = 1);

    calc_matrices(camera);
    world := multiply(inverse_view_projection_matrix, mouse_viewport);
    if world.w != 0
        world /= world.w;

    return make_ray(
        origin = position,
        direction = (world.xyz - position), normalize_direction=true);
}

#scope_file
#import "Math";
#import "Basic";
#import "renderer";
#import "toolbelt";
#import "math_extra";
