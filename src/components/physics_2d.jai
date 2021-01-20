Physics_Object :: struct {
    body: *cp.Body;
    shape: *cp.Shape;
}

Circle_Collider_2D :: struct {
    using component: Component;
    using physics_object: Physics_Object; @noserialize @noui
}

BoxCollider :: struct {
    using component: Component;
    collision: Collision_Type;

    size:   Vector2 = .{1, 1};
    offset: Vector2 = .{0, 0};


    using physics_object: Physics_Object; @noui @noserialize
}


physics_2d_draw_debug :: () {
    if 0 {
        using context.state.physics_2d_state;

        debug_draw_context = context;
        drawOptions := cp.SpaceDebugDrawOptions.{
            DrawCircle,
            DrawSegment,
            DrawFatSegment,
            DrawPolygon,
            DrawDot,
            
            cp.SpaceDebugDrawFlags.SHAPES | .CONSTRAINTS | .COLLISION_POINTS,
            
            .{0xEE/255.0, 0xE8/255.0, 0xD5/255.0, 1.0}, // Outline color
            ColorForShape,
            .{0.0, 0.75, 0.0, 1.0}, // Constraint color
            .{1.0, 0.0, 0.0, 1.0}, // Collision point color
            null,
        };
        drawOptions.data = *debug_draw_context;
        cp.SpaceDebugDraw(space, *drawOptions);
    }
}

remove_physics_object :: (using physics_object: *Physics_Object) {
    assert(physics_object != null);

    space := context.state.physics_2d_state.space;

    if shape != null {
        cp.SpaceRemoveShape(space, shape);
        cp.ShapeFree(shape);
        shape = null;
    }

    if body != null {
        cp.SpaceRemoveBody(space, body);
        cp.BodyFree(body);
        body = null;
    }
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

worldspace_rect :: (it: *BoxCollider, transform: *Transform = null) -> rl.Rectangle {
    if transform == null
        transform = get_transform(it);

    sz := Vector2Scale(transform.scale.xy, it.size);
    p := transform.position.xy + it.offset;
    return rect_from_points( p - sz * 0.5, p + sz * 0.5);
}

operator != :: (a: cp.Vect, b: cp.Vect) -> bool {
    return a.x != b.x || a.y != b.y;
}

update :: (using col: *BoxCollider, transform: *Transform) {
    using context.state.physics_2d_state;
    ensure_space_created(*space);

    // reindex static body positions if necessary.
    if context.state.editor.play_mode == .Edit && col.body != null && cp.BodyGetType(col.body) == .STATIC {
        pos, width, height := get_chipmunk_rect(col, transform);
        if cp.BodyGetPosition(body) != pos {
            cp.BodySetPosition(body, pos);
            cp.SpaceReindexShapesForBody(space, body);
        }
    }
}

get_chipmunk_rect :: (col: *BoxCollider, transform: *Transform) -> (cp.Vect, float64, float64) {
    sz := Vector2Scale(transform.scale.xy, col.size);

    pos: cp.Vect;
    pos.x = transform.position.x + sz.x * 0.5;
    pos.y = transform.position.y + sz.y * 0.5;

    return pos, cast(float64)sz.x, cast(float64)sz.y;
}

on_enable :: (using col: *BoxCollider, parent_entity: *Entity) {
    using context.state.physics_2d_state;
    ensure_space_created(*space);

    transform := get_transform(col);

    pos, width, height := get_chipmunk_rect(col, transform);

    body = cp.BodyNewStatic();
    cp.SpaceAddBody(space, body);
    cp.BodySetPosition(body, pos);
    
    shape = cp.SpaceAddShape(space, cp.BoxShapeNew(body, width, height, 0.0));
    cp.ShapeSetFriction(shape, 0.8);
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


ColorForShape :: (shape: *cp.Shape, data: *void) -> cp.SpaceDebugColor #c_call {
	if cp.ShapeGetSensor(shape) {
		return LAColor(1.0, 0.1);
	}

    body := cp.ShapeGetBody(shape);
    
    if cp.BodyIsSleeping(body) {
        return RGBAColor(0x58/255.0, 0x6e/255.0, 0x75/255.0, 1.0);
    } else if body.sleeping.idleTime > shape.space.sleepTimeThreshold {
        return RGBAColor(0x93/255.0, 0xa1/255.0, 0xa1/255.0, 1.0);
    }

    val := cast(u32)shape.hashid;
    
    // scramble the bits up using Robert Jenkins' 32 bit integer hash function
    val = (val+0x7ed55d16) + (val<<12);
    val = (val^0xc761c23c) ^ (val>>19);
    val = (val+0x165667b1) + (val<<5);
    val = (val+0xd3a2646c) ^ (val<<9);
    val = (val+0xfd7046c5) + (val<<3);
    val = (val^0xb55a4f09) ^ (val>>16);

    return Colors[val & 0x7];
}

LAColor :: inline (l: float, a: float) -> cp.SpaceDebugColor #c_call {
    color: cp.SpaceDebugColor;
    color.r = l;
    color.g = l;
    color.b = l;
    color.a = a;
	return color;
}

RGBAColor :: inline (r: float, g: float, b: float, a: float) -> cp.SpaceDebugColor #c_call {
    color: cp.SpaceDebugColor;
    color.r = r;
    color.g = g;
    color.b = b;
    color.a = a;
	return color;
}

Colors := cp.SpaceDebugColor.[
	cp.SpaceDebugColor.{0xb5/255.0, 0x89/255.0, 0x00/255.0, 1.0},
	cp.SpaceDebugColor.{0xcb/255.0, 0x4b/255.0, 0x16/255.0, 1.0},
	cp.SpaceDebugColor.{0xdc/255.0, 0x32/255.0, 0x2f/255.0, 1.0},
	cp.SpaceDebugColor.{0xd3/255.0, 0x36/255.0, 0x82/255.0, 1.0},
	cp.SpaceDebugColor.{0x6c/255.0, 0x71/255.0, 0xc4/255.0, 1.0},
	cp.SpaceDebugColor.{0x26/255.0, 0x8b/255.0, 0xd2/255.0, 1.0},
	cp.SpaceDebugColor.{0x2a/255.0, 0xa1/255.0, 0x98/255.0, 1.0},
	cp.SpaceDebugColor.{0x85/255.0, 0x99/255.0, 0x00/255.0, 1.0},
];

ColorFromFloats :: (r: float, g: float, b: float, a: float) -> rl.Color {
    color: rl.Color;
    color.r = cast(u8)(r * 255.0);
    color.g = cast(u8)(g * 255.0);
    color.b = cast(u8)(b * 255.0);
    color.a = cast(u8)(a * 255.0);
    return color;
}

DrawCircle :: (pos: cp.Vect, angle: float64, radius: float64, outline_color: cp.SpaceDebugColor, fill_color: cp.SpaceDebugColor, data: *void) #c_call {
    push_context <<cast(*Context)data {
        rl.DrawCircleV(v2(pos.x, pos.y), cast(float)radius, ColorFromFloats(fill_color.r, fill_color.g, fill_color.b, fill_color.a));
    }
}

DrawSegment :: (a: cp.Vect, b: cp.Vect, color: cp.SpaceDebugColor, data: *void) #c_call {
}

DrawFatSegment :: (a: cp.Vect, b: cp.Vect, radius: float64, outlineColor: cp.SpaceDebugColor, fill_color: cp.SpaceDebugColor, data: *void) #c_call {}

DrawPolygon :: (count: s32, verts: *cp.Vect, radius: float64, outlineColor: cp.SpaceDebugColor, fill_color: cp.SpaceDebugColor, data: *void) #c_call {
    points: [3]Vector2;

    push_context <<cast(*Context)data {
        i := 0;
        while i <= count-2 {

            points[0].x = cast(float)((verts + (i + 1) % count).x);
            points[0].y = cast(float)((verts + (i + 1) % count).y);
            points[1].x = cast(float)((verts + (i + 0) % count).x);
            points[1].y = cast(float)((verts + (i + 0) % count).y);
            points[2].x = cast(float)((verts + (i + 2) % count).x);
            points[2].y = cast(float)((verts + (i + 2) % count).y);

            rl.DrawTriangleStrip(points.data, 3, ColorFromFloats(fill_color.r, fill_color.g, fill_color.b, fill_color.a));
            i += 1;
        }
    }
}

DrawDot ::  (size: float64, pos: cp.Vect, color: cp.SpaceDebugColor, data: *void) #c_call {}


debug_draw_context: Context;



cp :: #import "Chipmunk";
rl :: #import "raylib";
#import "toolbelt";

