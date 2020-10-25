Circle_Collider_2D :: struct {
    using component: Component;

    body: *cp.Body;
    shape: *cp.Shape;
}

on_enable :: (using col: *Circle_Collider_2D, parent_entity: *Entity) {
    using context.state.physics_2d_state;
    ensure_space_created(*space);

    print("on_enable %\n", col);
    xrs := get_transform(parent_entity);

    radius := max(xrs.scale.x, xrs.scale.y);
    mass := 1.0;

    moment := cp.MomentForCircle(mass, 0, radius, cp.vzero);
    body = cp.BodyNew(mass, moment);

    print("space: %, body->space: %\n", space, cp.BodyGetSpace(body));
    
    cp.SpaceAddBody(space, body);

    // on init, set the position to the transform's position
    cp.BodySetPosition(body, cp.v(xrs.position.x, xrs.position.y));

    shape = cp.SpaceAddShape(space, cp.CircleShapeNew(body, radius, cp.vzero));
    cp.ShapeSetFriction(shape, 0.7);
}

update :: (using collider: *Circle_Collider_2D, transform: *Transform) {
    if body != null {
        pos := cp.BodyGetPosition(body);
        transform.position.xy = v2(pos.x, pos.y);
    }
}

on_disable :: (using rb: *Circle_Collider_2D) {
    if body != null {
        cp.BodyFree(body);
        body = null;
    }
}

//

#scope_file

ensure_space_created :: (space: **cp.Space) {
    if <<space == null {
        <<space = cp.SpaceNew();
    }
}

cp :: #import "Chipmunk";
