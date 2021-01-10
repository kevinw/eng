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

copysign :: (x: float, y: float) -> float {
    if y < 0
        return -abs(x);
    else
        return abs(x);
}


euler_angles :: (q: Quaternion) -> Vector3 {
    angles: Vector3;

    // roll (x-axis rotation)
    sinr_cosp:float = 2 * (q.w * q.x + q.y * q.z);
    cosr_cosp:float = 1 - 2 * (q.x * q.x + q.y * q.y);
    angles.x = atan2(sinr_cosp, cosr_cosp);

    // pitch (y-axis rotation)
    sinp:float = 2 * (q.w * q.y - q.z * q.x);
    if abs(sinp) >= 1
        angles.y = copysign(PI / 2.0, sinp); // use 90 degrees if out of range
    else
        angles.y = asin(sinp);

    // yaw (z-axis rotation)
    siny_cosp:float = 2 * (q.w * q.z + q.x * q.y);
    cosy_cosp:float = 1 - 2 * (q.y * q.y + q.z * q.z);
    angles.z = atan2(siny_cosp, cosy_cosp);

    return angles * TO_DEGREES;
}

quaternion_from_euler :: (euler_angles: Vector3) -> Quaternion {
    euler := euler_angles * TO_RADIANS;

    roll  := euler.x;
    pitch := euler.y;
    yaw   := euler.z;

    // Abbreviations for the various angular functions
    cy := cos(yaw * 0.5);
    sy := sin(yaw * 0.5);
    cp := cos(pitch * 0.5);
    sp := sin(pitch * 0.5);
    cr := cos(roll * 0.5);
    sr := sin(roll * 0.5);

    q: Quaternion;
    q.w = cr * cp * cy + sr * sp * sy;
    q.x = sr * cp * cy - cr * sp * sy;
    q.y = cr * sp * cy + sr * cp * sy;
    q.z = cr * cp * sy - sr * sp * cy;
    return q;
}

TO_DEGREES :: 180.0 / PI;
TO_RADIANS :: PI / 180.0;

#scope_file
#import "Math";
#import "Sloppy_Math";
