Vector2Add :: (v1: Vector2, v2: Vector2) -> Vector2
{
    return rl.make_Vector2(v1.x + v2.x, v1.y + v2.y);
}

Vector2Subtract :: (v1: Vector2, v2: Vector2) -> Vector2
{
    return rl.make_Vector2(v1.x - v2.x, v1.y - v2.y);
}

Vector2Scale :: (v: Vector2, scale: float) -> Vector2
{
    return rl.make_Vector2(v.x*scale, v.y*scale);
}

Vector2Scale :: (a: Vector2, b: Vector2) -> Vector2 {
    return rl.make_Vector2(a.x * b.x, a.y * b.y);
}

Vector2Length :: (v: Vector2) -> float {
    return sqrt((v.x*v.x) + (v.y*v.y));
}

Vector2Normalize :: (v: Vector2) -> Vector2 {
    return Vector2Scale(v, 1/Vector2Length(v));
}

operator + :: (a: Vector2, b: s64) -> Vector2 {
    r: Vector2 = ---;
    r.x = a.x + cast(float)b;
    r.y = a.y + cast(float)b;
    return r;
}


operator - :: (a: Vector2, b: s64) -> Vector2 {
    r: Vector2 = ---;
    r.x = a.x - cast(float)b;
    r.y = a.y - cast(float)b;
    return r;
}

operator == :: (v1: Vector2, v2: Vector2) -> bool { return v1.x == v2.x && v1.y == v2.y; }
operator != :: (v1: Vector2, v2: Vector2) -> bool { return v1.x != v2.x || v1.y != v2.y; }

normalized :: (using v: Vector3, epsilon := 0, fallback := Vector3.{}) -> Vector3 {
    sq := sqrt(x*x + y*y + z*z);
    if sq == 0 return fallback;

    factor := 1.0 / sq;
    x *= factor;
    y *= factor;
    z *= factor;

    return v;
}


#scope_file
#import "Math";
rl :: #import "raylib";

