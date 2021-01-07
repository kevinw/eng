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

    screenp("camera % transform.position=% target_transform=%", cam_follow.mode, transform.position, target_transform.position);

}

#scope_file

rl :: #import "raylib";
#import "raymath";
#import "Math";
#import "camera";

/*
even_out_state: struct {
    eveningOut: int;
    evenOutTarget: float;
};

UpdateCameraEvenOutOnLanding :: (camera: *rl.Camera2D, player: *Player, delta: float, width: int, height: int) {
    using even_out_state;

    evenOutSpeed :: 700;
    
    camera.offset = rl.make_Vector2(width/2, height/2);
    transform := get_transform(player);
    camera.target.x = transform.position.x;
    
    if eveningOut {
        if evenOutTarget > camera.target.y {
            camera.target.y += evenOutSpeed*delta;
            
            if camera.target.y > evenOutTarget {
                camera.target.y = evenOutTarget;
                eveningOut = 0;
            }
        } else {
            camera.target.y -= evenOutSpeed*delta;
            
            if camera.target.y < evenOutTarget {
                camera.target.y = evenOutTarget;
                eveningOut = 0;
            }
        }
    } else {
        if (player.speed.y == 0) && (transform.position.y != camera.target.y) {
            eveningOut = 1;
            evenOutTarget = transform.position.y;
        }
    }
}

UpdateCameraPlayerBoundsPush :: (camera: *rl.Camera2D, player: *Player, delta: float, width: int, height: int) {
    bbox :: Vector2.{ 0.2, 0.2 };

    bboxWorldMin := rl.GetScreenToWorld2D(rl.make_Vector2((1 - bbox.x)*0.5*width, (1 - bbox.y)*0.5*height ), << camera);
    bboxWorldMax := rl.GetScreenToWorld2D(rl.make_Vector2((1 + bbox.x)*0.5*width, (1 + bbox.y)*0.5*height ), << camera);
    camera.offset = rl.make_Vector2((1 - bbox.x)*0.5 * width, (1 - bbox.y)*0.5*height);

    ok, player_entity := get_entity(player.entity);
    assert(ok);
    transform := get_transform(player_entity);

    if transform.position.x < bboxWorldMin.x camera.target.x = transform.position.x;
    if transform.position.y < bboxWorldMin.y camera.target.y = transform.position.y;
    if transform.position.x > bboxWorldMax.x camera.target.x = bboxWorldMin.x + (transform.position.x - bboxWorldMax.x);
    if transform.position.y > bboxWorldMax.y camera.target.y = bboxWorldMin.y + (transform.position.y - bboxWorldMax.y);
}
*/
