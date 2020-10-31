Physics_Object :: struct {
    body: *cp.Body;
    shape: *cp.Shape;
}

remove_physics_object :: (using physics_object: *Physics_Object) {
    space := context.state.physics_2d_state.space;

    if shape != null {
        cp.SpaceRemoveShape(space, shape);
        cp.ShapeFree(shape);
        shape = null;
    }

    if body != null {
        static_body := cp.SpaceGetStaticBody(space);
        if body != static_body {
            cp.SpaceRemoveBody(space, body);
            cp.BodyFree(body);
        }
        body = null;
    }
}


Circle_Collider_2D :: struct {
    using component: Component;
    using physics_object: Physics_Object; @no_serialize @noui
}

on_enable :: (using col: *Circle_Collider_2D, parent_entity: *Entity) {
    using context.state.physics_2d_state;
    ensure_space_created(*space);

    xrs := get_transform(parent_entity);

    radius := max(xrs.scale.x, xrs.scale.y);
    mass := 1.0;

    moment := cp.MomentForCircle(mass, 0, radius, cp.vzero);
    body = cp.BodyNew(mass, moment);

    cp.SpaceAddBody(space, body);
    cp.BodySetPosition(body, cp.v(xrs.position.x, xrs.position.y));

    shape = cp.SpaceAddShape(space, cp.CircleShapeNew(body, radius, cp.vzero));
    cp.ShapeSetFriction(shape, 0.7);
}

updated_this_frame := -1;

update :: (using collider: *Circle_Collider_2D, transform: *Transform) {
    using context.state;

    if cast(s64)Time.frame_count != updated_this_frame {
        updated_this_frame = cast(s64)Time.frame_count;

        cp.SpaceStep(physics_2d_state.space, 1.0/60.0);
        logprint("=fadjskl", "updating step %", Time.frame_count);
    }

    if body != null {
        pos := cp.BodyGetPosition(body);
        transform.position.xy = v2(pos.x, pos.y);
    }
}

on_disable :: (using rb: *Circle_Collider_2D, parent_entity: *Entity) {
    remove_physics_object(*physics_object);
}

Collision_Type :: enum_flags u8 {
    NONE     :: 0;
    PLATFORM :: (1 << 0);
    PHYSICAL :: (1 << 1);
}

BoxCollider :: struct {
    using component: Component;
    collision: Collision_Type;

    size:   rl.Vector2 = .{1, 1};
    offset: rl.Vector2 = .{0, 0};


    using physics_object: Physics_Object;
}

worldspace_rect :: (it: *BoxCollider, transform: *Transform = null) -> rl.Rectangle {
    if transform == null
        transform = get_transform(it);

    sz := Vector2Scale(transform.scale.xy, it.size);
    p := transform.position.xy + it.offset;
    return rect_from_points( p - sz * 0.5, p + sz * 0.5);
}

on_enable :: (using col: *BoxCollider, parent_entity: *Entity) {
    using context.state.physics_2d_state;
    ensure_space_created(*space);

	{
        static_body := cp.SpaceGetStaticBody(space);

        world_rect := worldspace_rect(col);

		width := world_rect.width;
        height := world_rect.height;

        body = static_body;

        mp := midpoint(world_rect);
        pos: cp.Vect;
        pos.x = mp.x;
        pos.y = mp.y;

		cp.BodySetPosition(body, pos);
		
		shape = cp.SpaceAddShape(space, cp.BoxShapeNew(body, width, height, 0.0));
		cp.ShapeSetFriction(shape, 0.8);
	}
}

on_disable :: (using rb: *BoxCollider, parent_entity: *Entity) {
    remove_physics_object(*physics_object);
}

#scope_file

ensure_space_created :: (space_ptr: **cp.Space) {
    if <<space_ptr != null
        return;

    space := cp.SpaceNew();
    cp.SpaceSetGravity(space, cp.v(0, 300));

    <<space_ptr = space;
}

cp :: #import "Chipmunk";
rl :: #import "raylib";
#import "toolbelt";
