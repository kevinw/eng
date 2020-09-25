My_Camera :: struct {
    using component: Component;

    foo: int;
}

#scope_file

rl :: #import "raylib";
Vector2 :: rl.Vector2;

CameraFunc :: #type (camera: *rl.Camera2D, player: *Player, delta: float, w: int, h: int);


even_out_state: struct {
    eveningOut: int;
    evenOutTarget: float;
};


UpdateCameraCenter :: (using camera: *rl.Camera2D, player: *Player, delta: float, width: int, height: int) {
    offset = rl.make_Vector2(width/2, height/2);
    target = get_transform(player).position.xy;
}

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
