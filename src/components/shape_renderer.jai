
Shape_Renderer :: struct {
    using component: Component;

    Shape :: enum u8 {
        Circle   :: 0;
        Square   :: 1;
    }

    shape: Shape = .Circle;
    color: rl.Color = rl.MAGENTA;
}

draw :: (using shape_renderer: *Shape_Renderer, transform: *Transform) {
    scl := transform.scale.xy;
    if shape == {
        case .Circle;
            radius := max(scl.x, scl.y);
            rl.DrawCircleV(transform.position.xy, radius, color);
        case .Square;
            p := transform.position.xy - scl * 0.5;
            rl.DrawRectangleV(p, scl, color);
    }

} @draw

on_enable :: (it: *Shape_Renderer, entity: *Entity) {
    entity.flags |= .Pivot_Center;
}

#scope_file
rl :: #import "raylib";
