#scope_file

#if OS == .WINDOWS {
    chipmunk_lib :: #foreign_library "win/chipmunk";
}

#scope_module

Space :: struct {}
Shape :: struct {}
Body  :: struct {}

Vect :: struct { x, y: float64; }    

v :: inline (x: $A, y: $B) -> Vect {
    v: Vect = ---;
    v.x = xx x;
    v.y = xx y;
    return v;
}

vzero: Vect;

SpaceNew :: () -> *Space #foreign chipmunk_lib "cpSpaceNew";
SpaceFree          :: (space: *Space) #foreign chipmunk_lib "cpSpaceFree";
SpaceSetGravity :: (space: *Space, v: Vect) #foreign chipmunk_lib "cpSpaceSetGravity";
SpaceAddShape      :: (space: *Space, shape: *Shape) -> *Shape #foreign chipmunk_lib "cpSpaceAddShape";
SpaceGetStaticBody :: (space: *Space) -> *Body #foreign chipmunk_lib "cpSpaceGetStaticBody";
SpaceAddBody       :: (space: *Space, body: *Body) -> *Body #foreign chipmunk_lib "cpSpaceAddBody";
SpaceStep          :: (space: *Space, time_step: float64) #foreign chipmunk_lib "cpSpaceStep";
SpaceRemoveShape   :: (space: *Space, shape: *Shape) #foreign chipmunk_lib "cpSpaceRemoveShape";
SpaceRemoveBody    :: (space: *Space, body: *Body) #foreign chipmunk_lib "cpSpaceRemoveBody";

//

BodyNew :: (mass: float64, moment: float64) -> *Body #foreign chipmunk_lib "cpBodyNew";
BodyFree        :: (body: *Body) #foreign chipmunk_lib "cpBodyFree";
BodySetPosition :: (body: *Body, pos: Vect) #foreign chipmunk_lib "cpBodySetPosition";
BodyGetPosition :: (body: *Body) -> Vect #foreign chipmunk_lib "cpBodyGetPosition";
BodyGetVelocity :: (body: *Body) -> Vect #foreign chipmunk_lib "cpBodyGetVelocity";
BodyGetSpace    :: (body: *Body) -> *Space #foreign chipmunk_lib "cpBodyGetSpace";

//

SegmentShapeNew :: (body: *Body, prev: $V/interface Vect, next: V, radius: float64) -> *Shape {
    _SegmentShapeNew :: (body: *Body, prev: Vect, next: Vect, radius: float64) -> *Shape #foreign chipmunk_lib "cpSegmentShapeNew";
    return _SegmentShapeNew(body, prev, next, radius);
}
CircleShapeNew :: (body: *Body, radius: float64, offset: Vect) -> *Shape #foreign chipmunk_lib "cpCircleShapeNew";
ShapeFree        :: (shape: *Shape) #foreign chipmunk_lib "cpShapeFree";
ShapeSetFriction :: (shape: *Shape, friction: float64) #foreign chipmunk_lib "cpShapeSetFriction";

//

MomentForCircle :: (m: float64, r1: float64, r2: float64, offset: Vect) -> float64 #foreign chipmunk_lib "cpMomentForCircle";
