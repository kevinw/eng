#scope_file
#scope_export

Shape_Renderer :: struct {
    using component: Component;

    Shape :: enum u8 {
        Circle :: 0;
    }

    shape: Shape = .Circle;
    color: Color = MAGENTA;
}

draw :: (using shape_renderer: *Shape_Renderer, transform: *Transform) {
    radius := max(transform.scale.x, transform.scale.y);
    //logprint("=foob", "DrawCircleV(%, %, %)\n", transform.position.xy, radius, color);
    DrawCircleV(transform.position.xy, radius, color);
} @draw

on_enable :: (it: *Shape_Renderer, entity: *Entity) {
}
