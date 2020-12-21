Vector2Int :: struct {
    x: s32;
    #place x; width: s32;

    y: s32;
    #place y; height: s32;
}

v2int :: (x: $X, y: $Y) -> Vector2Int {
    v: Vector2Int = ---;
    v.x = cast(s32)x;
    v.y = cast(s32)y;
    return v;
}
