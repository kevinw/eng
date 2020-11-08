Cam :: struct {
    using component: Component;
    cam2D: rl.Camera2D;
    cam2D.zoom = 1.2;
}

Cam_Follow :: struct {
    using component: Component;
    target_entity: Entity_Handle;

    mode: Mode;

    Mode :: enum u16 {
        Smooth :: 0;
        Center :: 1;
    }
}

get_main_camera :: () -> *Cam {
    return find_component(Cam);
}

get_main_camera_2D :: () -> *rl.Camera2D {
    cam := get_main_camera();
    if cam != null
        return *cam.cam2D;
    else
        return null;
}

get_worldspace_center :: (cam: *Cam) -> rl.Vector3 {
    return v3(cam.cam2D.target +
        rl.make_Vector2(context.state.gameWidth/2.0, context.state.gameHeight/2.0));
}

set_worldspace_center :: (cam: *Cam, position: rl.Vector2) {
    cam.cam2D.target = position - v2(context.state.gameWidth/2.0, context.state.gameHeight/2.0);
}

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

update :: (cam_follow: *Cam_Follow, camera: *Cam) {
    minSpeed :: 30.0;
    minEffectLength :: 10.0;
    fractionSpeed :: 2.9;

    if context.state.editor.play_mode != .Play return;

    transform := get_transform(cam_follow.target_entity);
    if !transform return;

    using context;
    using camera;
    if cam_follow.mode == {
        case .Smooth;
            cam2D.offset = rl.make_Vector2(state.gameWidth/2, state.gameHeight/2);
            diff := transform.position.xy - cam2D.target;
            length := Vector2Length(diff);
            if length > minEffectLength {
                speed := max(fractionSpeed*length, minSpeed);
                cam2D.target = Vector2Add(cam2D.target, Vector2Scale(diff, speed*state.Time.delta_time/length));
            }
        case .Center;
            cam2D.target = transform.position.xy;
    } 
}


#scope_file

rl :: #import "raylib";
#import "raymath";
Vector2 :: rl.Vector2;

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
