#module_parameters(LINK_STATIC := false);
#scope_file

#if OS == .WINDOWS {
    #if LINK_STATIC {
        chipmunk_lib :: #foreign_library,no_dll "win/static/chipmunk";
    } else {
        chipmunk_lib :: #foreign_library "win/dll/chipmunk";
    }
}

Float     :: float64;
HashValue :: *void;
Timestamp :: u32;

ShapeClass :: struct {
    type: ShapeType;
	
    cacheData: *void;
    destroy: *void;
    pointQuery: *void;
    segmentQuery: *void;
};

#scope_module

/// Column major affine transform.
Transform :: struct {
    a, b, c, d, tx, ty: Float;
}

SpatialIndex :: struct {}
Constraint :: struct {}
Arbiter :: struct {}
HashSet :: struct {}
Array :: struct {}
ContactBufferHeader :: struct {}

Group :: *void;
CollisionType :: *void;
Bitmask :: u32;

/// Chipmunk's axis-aligned 2D bounding box type. (left, bottom, right, top)
BB :: struct {
	l, b, r, t: Float;
}

BodyType :: enum {
	/// A dynamic body is one that is affected by gravity, forces, and collisions.
	/// This is the default body type.
	DYNAMIC;
	/// A kinematic body is an infinite mass, user controlled body that is not affected by gravity, forces or collisions.
	/// Instead the body only moves based on it's velocity.
	/// Dynamic bodies collide normally with kinematic bodies, though the kinematic body will be unaffected.
	/// Collisions between two kinematic bodies, or a kinematic body and a static body produce collision callbacks, but no collision response.
	KINEMATIC;
	/// A static body is a body that never (or rarely) moves. If you move a static body, you must call one of the cpSpaceReindex*() functions.
	/// Chipmunk uses this information to optimize the collision detection.
	/// Static bodies do not produce collision callbacks when colliding with other static bodies.
	STATIC;
}

ShapeMassInfo :: struct {
    m: Float;
	i: Float;
	cog: Vect;
	area: Float;
}

ShapeType :: enum {
	CIRCLE_SHAPE;
	SEGMENT_SHAPE;
	POLY_SHAPE;
	NUM_SHAPE;
}

/// Collision begin event function callback type.
/// Returning false from a begin callback causes the collision to be ignored until
/// the the separate callback is called when the objects stop colliding.
CollisionBeginFunc :: #type (arb: *Arbiter, space: *Space, userData: *void) -> bool #c_call;
/// Collision pre-solve event function callback type.
/// Returning false from a pre-step callback causes the collision to be ignored until the next step.
CollisionPreSolveFunc :: #type (arb: *Arbiter, space: *Space, userData: *void) -> bool #c_call;
/// Collision post-solve event function callback type.
CollisionPostSolveFunc :: #type (arb: *Arbiter, space: *Space, userData: *void) #c_call;
/// Collision separate event function callback type.
CollisionSeparateFunc :: #type (arb: *Arbiter, space: *Space, userData: *void) #c_call;

/// Struct that holds function callback pointers to configure custom collision handling.
/// Collision handlers have a pair of types; when a collision occurs between two shapes that have these types, the collision handler functions are triggered.
CollisionHandler :: struct {
	/// Collision type identifier of the first shape that this handler recognizes.
	/// In the collision handler callback, the shape with this type will be the first argument. Read only.
	typeA: CollisionType;
	/// Collision type identifier of the second shape that this handler recognizes.
	/// In the collision handler callback, the shape with this type will be the second argument. Read only.
    typeB: CollisionType;
	/// This function is called when two shapes with types that match this collision handler begin colliding.
    beginFunc: CollisionBeginFunc;
	/// This function is called each step when two shapes with types that match this collision handler are colliding.
	/// It's called before the collision solver runs so that you can affect a collision's outcome.
    preSolveFunc: CollisionPreSolveFunc;
	/// This function is called each step when two shapes with types that match this collision handler are colliding.
	/// It's called after the collision solver runs so that you can read back information about the collision to trigger events in your game.
    postSolveFunc: CollisionPostSolveFunc;
	/// This function is called when two shapes with types that match this collision handler stop colliding.
    separateFunc: 	CollisionSeparateFunc;
	/// This is a user definable context pointer that is passed to all of the collision handler functions.
    userData: *void;
};

/// Fast collision filtering type that is used to determine if two objects collide before calling collision or query callbacks.
ShapeFilter :: struct {
	/// Two objects with the same non-zero group value do not collide.
	/// This is generally used to group objects in a composite object together to disable self collisions.
    group: Group;
	/// A bitmask of user definable categories that this object belongs to.
	/// The category/mask combinations of both objects in a collision must agree for a collision to occur.
    categories: Bitmask;
	/// A bitmask of user definable category types that this object object collides with.
	/// The category/mask combinations of both objects in a collision must agree for a collision to occur.
    mask: Bitmask;
}

Space :: struct {
    iterations: s32;
	
    gravity: Vect;
    damping: Float;
	
    idleSpeedThreshold: Float;
    sleepTimeThreshold: Float;
	
    collisionSlop: Float;
    collisionBias: Float;
    collisionPersistence: Timestamp;
	
    userData: *void;
	
    stamp: Timestamp;
    curr_dt: Float;

	dynamicBodies: *Array;
	staticBodies: *Array;
	rousedBodies: *Array;
	sleepingComponents: *Array;
	
    shapeIDCounter: HashValue;
	staticShapes: *SpatialIndex;
	dynamicShapes: *SpatialIndex;
	
	constraints: *Array;
	
	arbiters: *Array;
	contactBuffersHead: *ContactBufferHeader;
	cachedArbiters: *HashSet;
	pooledArbiters: *Array;
	
	allocatedBuffers: *Array;
    locked: u32;
	
    usesWildcards: bool;
	collisionHandlers: *HashSet;
    defaultHandler: CollisionHandler;
	
    skipPostStep: bool;
	postStepCallbacks: *Array;
	
	staticBody: *Body;
    _staticBody: Body;
}

Shape :: struct {
	klass: *ShapeClass;
	
    space: *Space;
    body: *Body;
	massInfo: ShapeMassInfo;
    bb: BB;
	
    sensor: bool;
	
    e: Float;
    u: Float;
    surfaceV: Vect;

    userData: *void;
	
    type: CollisionType;
    filter: ShapeFilter;
	
    next: *Shape;
	prev: *Shape;
	
    hashid: HashValue;
}


/// Rigid body velocity update function type.
BodyVelocityFunc :: #type (body: *Body, gravity: Vect, damping: Float, dt: Float) #c_call;
/// Rigid body position update function type.
BodyPositionFunc :: #type (body: *Body, dt: Float) #c_call;

Body :: struct {
	// Integration functions
    velocity_func: BodyVelocityFunc;
    position_func: BodyPositionFunc;
	
	// mass and it's inverse
    m: Float;
    m_inv: Float;
	
	// moment of inertia and it's inverse
    i: Float;
    i_inv: Float;
	
	// center of gravity
    cog: Vect;
	
	// position, velocity, force
    p: Vect;
    v: Vect;
    f: Vect;
	
	// Angle, angular velocity, torque (radians)
    a: Float;
    w: Float;
    t: Float;
	
    transform: Transform;
	
    userData: *void;
	
	// "pseudo-velocities" used for eliminating overlap.
	// Erin Catto has some papers that talk about what these are.
    v_bias: Vect;
    w_bias: Float;
	
    space: *Space;
	
    shapeList: *Space;
    arbiterList: *Arbiter;
	constraintList: *Constraint;
	
    sleeping: struct {
        root: *Body;
        next: *Body;
        idleTime: Float;
	};
}


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
/// Debug draw the current state of the space using the supplied drawing options.
SpaceDebugDraw     :: (space: *Space, options: *SpaceDebugDrawOptions) #foreign chipmunk_lib "cpSpaceDebugDraw";
SpaceReindexShapesForBody :: (space: *Space, body: *Body) #foreign chipmunk_lib "cpSpaceReindexShapesForBody";

//

BodyNew          :: (mass: float64, moment: float64) -> *Body #foreign chipmunk_lib "cpBodyNew";
BodyNewStatic    :: () -> *Body #foreign chipmunk_lib "cpBodyNewStatic";
BodyNewKinematic :: () -> *Body #foreign chipmunk_lib "cpBodyNewKinematic";
BodyFree         :: (body: *Body) #foreign chipmunk_lib "cpBodyFree";
BodySetPosition  :: (body: *Body, pos: Vect) #foreign chipmunk_lib "cpBodySetPosition";
BodyGetPosition  :: (body: *Body) -> Vect #foreign chipmunk_lib "cpBodyGetPosition";
BodyGetVelocity  :: (body: *Body) -> Vect #foreign chipmunk_lib "cpBodyGetVelocity";
BodyGetSpace     :: (body: *Body) -> *Space #foreign chipmunk_lib "cpBodyGetSpace";
BodyIsSleeping   :: (body: *Body) -> bool #foreign chipmunk_lib "cpBodyIsSleeping";
BodyGetType      :: (body: *Body) -> BodyType #foreign chipmunk_lib "cpBodyGetType";

//

SegmentShapeNew :: (body: *Body, prev: $V/interface Vect, next: V, radius: float64) -> *Shape {
    _SegmentShapeNew :: (body: *Body, prev: Vect, next: Vect, radius: float64) -> *Shape #foreign chipmunk_lib "cpSegmentShapeNew";
    return _SegmentShapeNew(body, prev, next, radius);
}
CircleShapeNew :: (body: *Body, radius: float64, offset: Vect) -> *Shape #foreign chipmunk_lib "cpCircleShapeNew";
BoxShapeNew      :: (body: *Body, width: float64, height: float64, radius: float64) -> *Shape #foreign chipmunk_lib "cpBoxShapeNew";
ShapeFree        :: (shape: *Shape) #foreign chipmunk_lib "cpShapeFree";
ShapeSetFriction :: (shape: *Shape, friction: float64) #foreign chipmunk_lib "cpShapeSetFriction";

//

MomentForCircle :: (m: float64, r1: float64, r2: float64, offset: Vect) -> float64 #foreign chipmunk_lib "cpMomentForCircle";
MomentForBox    :: (mass: float64, width: float64, height: float64) -> float64 #foreign chipmunk_lib "cpMomentForBox";

//

ShapeGetSensor :: (shape: *Shape) -> bool #foreign chipmunk_lib "cpShapeGetSensor";
ShapeGetBody   :: (shape: *Shape) -> *Body #foreign chipmunk_lib "cpShapeGetBody";

/// Color type to use with the space debug drawing API.
SpaceDebugColor :: struct {
	r, g, b, a: float;
}

/// Callback type for a function that draws a filled, stroked circle.
SpaceDebugDrawCircleImpl :: #type (pos: Vect, angle: float64, radius: float64, outlineColor: SpaceDebugColor, fillColor: SpaceDebugColor, data: *void) #c_call;
/// Callback type for a function that draws a line segment.
SpaceDebugDrawSegmentImpl :: #type (a: Vect, b: Vect, color: SpaceDebugColor, data: *void) #c_call;
/// Callback type for a function that draws a thick line segment.
SpaceDebugDrawFatSegmentImpl :: #type (a: Vect, b: Vect, radius: float64, outlineColor: SpaceDebugColor, fillColor: SpaceDebugColor, data: *void) #c_call;
/// Callback type for a function that draws a convex polygon.
SpaceDebugDrawPolygonImpl :: #type (count: s32, verts: *Vect, radius: float64, outlineColor: SpaceDebugColor, fillColor: SpaceDebugColor, data: *void) #c_call;
/// Callback type for a function that draws a dot.
SpaceDebugDrawDotImpl ::  #type (size: float64, pos: Vect, color: SpaceDebugColor, data: *void) #c_call;
/// Callback type for a function that returns a color for a given shape. This gives you an opportunity to color shapes based on how they are used in your engine.
SpaceDebugDrawColorForShapeImpl :: #type (shape: *Shape, data: *void) -> SpaceDebugColor #c_call;

SpaceDebugDrawFlags :: enum_flags {
    SHAPES           :: 1<<0;
    CONSTRAINTS      :: 1<<1;
    COLLISION_POINTS :: 1<<2;
}

/// Struct used with SpaceDebugDraw() containing drawing callbacks and other drawing settings.
SpaceDebugDrawOptions :: struct {
	/// Function that will be invoked to draw circles.
    drawCircle: SpaceDebugDrawCircleImpl;
	/// Function that will be invoked to draw line segments.
    drawSegment: SpaceDebugDrawSegmentImpl;
	/// Function that will be invoked to draw thick line segments.
    drawFatSegment: SpaceDebugDrawFatSegmentImpl;
	/// Function that will be invoked to draw convex polygons.
    drawPolygon: SpaceDebugDrawPolygonImpl;
	/// Function that will be invoked to draw dots.
    drawDot: SpaceDebugDrawDotImpl;
	
	/// Flags that request which things to draw (collision shapes, constraints, contact points).
    flags: SpaceDebugDrawFlags;
	/// Outline color passed to the drawing function.
    shapeOutlineColor: SpaceDebugColor;
	/// Function that decides what fill color to draw shapes using.
    colorForShape: SpaceDebugDrawColorForShapeImpl;
	/// Color passed to drawing functions for constraints.
    constraintColor: SpaceDebugColor;
	/// Color passed to drawing functions for collision points.
    collisionPointColor: SpaceDebugColor;
	
	/// User defined context pointer passed to all of the callback functions as the 'data' argument.
    data: *void;
}

