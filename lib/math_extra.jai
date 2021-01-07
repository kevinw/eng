XY_PLANE :: Plane3.{.{0, 0, 1}};

Ray :: struct {
    origin:    Vector3;
    direction: Vector3;
}


raycast :: (plane: Plane3, ray: Ray) -> (bool, float) {
    plane_normal := get_normal(plane);
    plane_distance := plane.d;

    vdot := dot(ray.direction, plane_normal);
    ndot := -dot(ray.origin, plane_normal) - plane_distance;

    if (is_approximately_zero(vdot))
        return false, 0;

    enter := ndot / vdot;
    return enter > 0.0, enter;
}


Vector2Integer :: struct(T: Type) {
    x: T;
    #place x; width: T;

    y: T;
    #place y; height: T;
}

Vector2_s32 :: Vector2Integer(s32);
Vector2_u32 :: Vector2Integer(u32);
Vector2_u16 :: Vector2Integer(u16);

v2_constructor :: ($T: Type, x: T, y: T) -> Vector2Integer(T) {
    v: Vector2Integer(T) = ---;
    v.x = x;
    v.y = y;
    return v;
}

v2int  :: #bake_arguments v2_constructor(T = s32);
v2uint :: #bake_arguments v2_constructor(T = u32);
v2u16  :: #bake_arguments v2_constructor(T = u16);

#scope_file
#import "Math";
#import "Sloppy_Math";
