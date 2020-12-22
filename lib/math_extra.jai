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
