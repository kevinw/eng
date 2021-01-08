Cam :: struct {
    using component: Component;
    using camera: Camera;
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

    if cam_follow.mode == {
        case .Smooth;
            diff := target_transform.position.xy - transform.position.xy;
            len  := length(diff);
            if len > minEffectLength {
                speed := max(fractionSpeed * len, minSpeed);
                transform.position.xy += Vector2Scale(diff, speed * context.state.Time.delta_time / len);
            }
        case .Center;
            transform.position.xy = target_transform.position.xy;
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
