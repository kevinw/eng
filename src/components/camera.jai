Cam :: struct {
    using component: Component;
    using camera: Camera;
}

Multiview_Capture :: struct {
    using component: Component;

    using holoplay_capture: Holoplay_Capture;
}

Cam_Follow :: struct {
    using component: Component;
    target_entity: Entity_Handle;
    mode: enum u16 {
        Smooth :: 0;
        Center :: 1;
    }
}

get_main_camera :: () => find_component(Cam);

on_enable :: (cam_follow: *Cam_Follow, entity: *Entity) {
    /*
    TODO: on_enable needs to be called after all sibling components get added.
    then we can fix Cam_Follow to set it's target position on startup.
    trs := get_transform(target_entity);
    if trs {
    }

    camera.rotation = 0.0;
    camera.offset = Vector2.{ cast(float)gameWidth/2.0, cast(float)gameHeight/2.0 };
    camera.zoom = DEFAULT_CAM_ZOOM;
    */
}

update :: (cam_follow: *Cam_Follow, cam: *Cam) {
    minSpeed        :: 30.0;
    minEffectLength :: 10.0;
    fractionSpeed   :: 2.9;

    //if context.state.editor.play_mode != .Play
        //return;

    transform := get_transform(cam.entity);

    target_transform := get_transform(cam_follow.target_entity);
    if !target_transform
        return;

    target_pos := target_transform.position.xy;

    if cam_follow.mode == {
        case .Smooth;
            diff := target_pos - transform.position.xy;
            len  := length(diff);
            if len > minEffectLength {
                speed := max(fractionSpeed * len, minSpeed);
                transform.position.xy += Vector2Scale(diff, speed * context.state.Time.delta_time / len);
            }
        case .Center;
            transform.position.xy = target_pos;
    } 

    //
    // do the static camera per room thing
    //
    if 0 {

        //world_screen_width := 
        screenp("%", target_pos);
        WIDTH :: 400.0;
        HALF_SCREEN_WIDTH :: WIDTH * 0.5;
        transform.position.x = cast(int)((target_pos.x + HALF_SCREEN_WIDTH) / WIDTH) * WIDTH;

        ASPECT :: 9.0 / 16.0;
        HEIGHT :: WIDTH / ASPECT;
        HALF_SCREEN_HEIGHT :: HEIGHT * 0.5;
        OFFSET :: 200.0;
        transform.position.y = cast(int)((target_pos.y - OFFSET + HALF_SCREEN_HEIGHT) / HEIGHT) * HEIGHT + OFFSET;

        // vary based on player pos
        transform.position.x += target_pos.x * 0.05;
    }


    cam.camera.position = transform.position;
    cam.camera.rotation = transform.rotation;
    cam.camera.matrices_need_update = true;
}

#scope_file

rl :: #import "raylib";
#import "raymath";
#import "Math";
#import "camera";
