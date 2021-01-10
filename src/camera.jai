Camera :: struct {
    position: Vector3;
    rotation: Quaternion;
    fov:      float       = 30;

    near_plane: float     = 10;
    far_plane:  float     = 1000;

    per_view_translation := Vector3.{1.05, 0.0, 0.0};

    matrices_need_update := true;    @noserialize @noui
    last_calced_renderer: *Renderer; @noserialize @noui // TODO: I believe this goes away once we make the looking glass display have its own camera.

    struct {
        view_matrix:       Matrix4;              @noserialize @noui
        projection_matrix: Matrix4;              @noserialize @noui
        inverse_view_projection_matrix: Matrix4; @noserialize @noui
    }
}

make_ray :: (origin: Vector3, direction: Vector3, $normalize_direction := false) -> Ray {
    ray: Ray = ---;
    ray.origin = origin;
    ray.direction = direction;
    #if normalize_direction
        normalize_or_z_axis(*ray.direction);
    return ray;
}

_update_matrices :: (using camera: *Camera) {
    forward := rotate(Vector3.{0, 0, 1}, rotation);
    up      := rotate(Vector3.{0, 1, 0}, rotation);
    look_at := position + forward * 10; // TODO: there's probably a better way

    aspect := camera_aspect(camera);
    projection_matrix = make_projection_matrix(fov, aspect,
        near_plane, far_plane, depth_range_01 = true);

    view_matrix = make_look_at_matrix(
        viewpoint = position,
        look_at   = look_at,
        reference_up_vector = up,
        //reference_up_vector = Vector3.{0, 1, 0},
        x_is_forward        = false);

    vp := multiply(projection_matrix, view_matrix);

    inverse_succeeded := false;
    inverse_view_projection_matrix, inverse_succeeded = inverse(vp);
    if !inverse_succeeded
        logprint("camera", .MINIMAL, "warning: taking the inverse of the VP matrix failed!");

    matrices_need_update = false;
    last_calced_renderer = get_renderer_ptr();
}

calc_matrices :: inline (using camera: *Camera) {
    if matrices_need_update || get_renderer_ptr() != last_calced_renderer {
        _update_matrices(camera);
    }
}

camera_aspect :: (camera: *Camera) -> float {
    // TODO: what if render textures, etc...
    return framebuffer_aspect();
}

pixel_size :: (camera: *Camera) -> u16, u16 {
    // TODO: what if render textures, etc...
    sz := framebuffer_size();
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
