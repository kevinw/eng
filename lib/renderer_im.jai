// forked from jai's builtin Render/Im_Draw

// To draw something, this needs to be provided by the user.
// renderer_im_impl.jai has an implementation using the "renderer" library.

Im_Draw_Callback :: #type (ctx: *Im_Context, index_array: [] u16, vertex_array: [] Im_Vertex, draw_array: [] Im_Draw_Command);

im_init :: (using ctx: *Im_Context, index_elements := 4096, vertex_elements := 4096, draw_elements:=64, callback: Im_Draw_Callback) {
    // Allocate buffers.
    array_reserve(*index_array,  index_elements);
    array_reserve(*vertex_array, vertex_elements);
    array_reserve(*draw_array,   draw_elements);

    dummy: Im_Draw_Command;
    array_add(*draw_array, dummy);

    draw_callback = callback;

    scale  = xy(1, 1);
    offset = xy(0, 0);
}

im_set_z :: inline (using ctx: *Im_Context, z: float) {
    current_depth_z = z;
}

im_push_z :: (using ctx: *Im_Context, z:float) #expand {
    old_z := ctx.current_depth_z;
    ctx.current_depth_z = z;
    `defer ctx.current_depth_z = old_z;
}

im_set_texture :: (using ctx: *Im_Context, texture: *void) {
    draw_cmd := *draw_array[draw_array.count - 1];
    if draw_cmd.texture == texture  return;                     // Nothing to do.
    if draw_cmd.index_count         im_flush(ctx);
    draw_cmd.texture = texture;
    current_texture = texture;
}

im_set_sampler :: (using ctx: *Im_Context, sampler: *void) {
    draw_cmd := *draw_array[draw_array.count - 1];
    if draw_cmd.sampler == sampler  return;                     // Nothing to do.
    if draw_cmd.index_count         im_flush(ctx);
    draw_cmd.sampler = sampler;

    current_sampler = sampler;
}

im_set_primitive :: (using ctx: *Im_Context, index_per_primitive: u8) {
    if !draw_array return;
    assert(index_per_primitive > 0 && index_per_primitive <= 3);
	
    draw_cmd := *draw_array[draw_array.count - 1];
    if draw_cmd.index_per_primitive == index_per_primitive return;    // Nothing to do.
    if draw_cmd.index_count         im_flush(ctx);
    draw_cmd.index_per_primitive = index_per_primitive;

    current_index_per_primitive = index_per_primitive;
}


// The default view transform is assumed to map the [-1,1] range to the extents of the viewport, with (-1,-1) at the bottom left corner.
// You can use this function to provide coordinates in a different range. This doesn't produce a flush, it only affects the upcoming vertex invocations.
im_set_viewport_transform :: (using ctx: *Im_Context, scale_x: float, scale_y: float, offset_x: float, offset_y: float) {
    scale.x = scale_x;
    scale.y = scale_y;
    offset.x = offset_x;
    offset.y = offset_y;
}


im_set_viewport :: (using ctx: *Im_Context, x: u32, y: u32, w: s32, h: s32) {
    // @@ 
}

im_set_clip_rect :: (using ctx: *Im_Context, x: u32, y: u32, w: s32, h: s32) {
    im_set_clip_rect(ctx, xyzw(xx x, xx y, xx w, xx h));
}

im_set_clip_rect :: (using ctx: *Im_Context, rect: Vector4) {
    draw_cmd := *draw_array[draw_array.count - 1];
    if draw_cmd.clip_rect == rect   return;                     // Nothing to do.
    if draw_cmd.index_count         draw_cmd = im_begin_draw(ctx, false); // Start a new draw.
    draw_cmd.clip_rect = rect;

    current_clip_rect = rect;
}

/*im_set_clip_rect :: (x:s32, y:s32, w:s32, h:s32) {
    rect: Im_Clip_Rect;
    rect.x = x; rect.y = y;                                     // @@ Initialization syntax.
    rect.w = w; rect.h = h;

    draw_cmd := *draw_array[draw_array.count];
    if draw_cmd.clip_rect == rect   return;                     // Nothing to do.
    if draw_cmd.index_count         draw_cmd = im_begin_draw(); // Start a new draw.
    draw_cmd.clip_rect = rect;
}*/


im_draw_circle :: (using ctx: *Im_Context, center: Vector2, radius: Vector2, color: Vector4, segments := 40) {
    im_draw_circle_sector(ctx, center, radius, start_angle=0, end_angle=TAU, segments=segments, color=color);
}

im_draw_circle_sector :: (using ctx: *Im_Context, center: Vector2, radius: Vector2, start_angle: float = 0, end_angle:float = TAU, segments := 40, color := Vector4.{1,1,1,1}) {
    r := radius;
    if r.x <= 0 r.x = 0.1;
    if r.y <= 0 r.y = 0.1;

    if end_angle < start_angle
        Swap(*end_angle, *start_angle);

    assert(segments >= 5, "TODO");

    step_length := cast(float)(end_angle - start_angle)/cast(float)segments;
    angle       := cast(float)start_angle;

    for i: 0..segments - 1 {
        im_draw_triangle(ctx,
            center,
            center + make_vector2(sin(angle) * r.x,               cos(angle) * r.y),
            center + make_vector2(sin(angle + step_length) * r.x, cos(angle + step_length) * r.y),
            make_vector2(0, 0),
            make_vector2(1, 1),
            make_vector2(1, 1),
            color);
        angle += step_length;

        //print("drawing circle segment % %\n", i, r);
    }
}

im_draw_quad :: (using ctx: *Im_Context, p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t0: Vector2, t1: Vector2, t2: Vector2, t3: Vector2, c: Vector4) {
    im_set_primitive(ctx, 3);
    im_ensure_space_for(ctx, 6, 4);

    v0 := im_vertex(ctx, p0, t0, c);
    v1 := im_vertex(ctx, p1, t1, c);
    v2 := im_vertex(ctx, p2, t2, c);
    v3 := im_vertex(ctx, p3, t3, c);

    im_indices(ctx, v0, v1, v2, v2, v0, v3);
}

im_draw_rect :: inline (using ctx: *Im_Context, p0: Vector2, p1: Vector2, t0 := Vector2.{0, 0}, t1 := Vector2.{1, 1}, c := Vector4.{1, 0, 0, 1}) {

    /*draw_cmd := *draw_array[draw_array.count - 1];

    // Cull quad against clip rect. @@ Not sure how this interacts with the scale/offset. In what space is clip_rect?
    if draw_cmd.clip_rect.x != draw_cmd.clip_rect.y {
        if x1 < draw_cmd.clip_rect.x return;
        if x0 > draw_cmd.clip_rect.z return;
        if y1 < draw_cmd.clip_rect.y return;
        if y0 > draw_cmd.clip_rect.w return;
    }*/

    p01 := xy(p0.x, p1.y);
    p10 := xy(p1.x, p0.y);

    t01 := xy(t0.x, t1.y);
    t10 := xy(t1.x, t0.y);

    im_draw_quad(ctx, p0, p01, p1, p10, t0, t01, t1, t10, c);
}

im_draw_rect :: inline (using ctx: *Im_Context, x0: float, y0: float, x1: float, y1: float, u0:=0.0, v0:=0.0, u1:=1.0, v1:=1.0, c:=Vector4.{1, 1, 1, 1}) {

    p0 := xy(x0, y0); p1 := xy(x1, y1);
    t0 := xy(u0, v0); t1 := xy(u1, v1);

    im_draw_rect(ctx, p0, p1, t0, t1, c);
}

im_draw_triangle :: (using ctx: *Im_Context, p0: Vector2, p1: Vector2, p2: Vector2, t0: Vector2, t1: Vector2, t2: Vector2, c: Vector4) {
    im_set_primitive(ctx, 3);
    im_ensure_space_for(ctx, 3, 3);

    v0 := im_vertex(ctx, p0, t0, c);
    v1 := im_vertex(ctx, p1, t1, c);
    v2 := im_vertex(ctx, p2, t2, c);

    im_indices(ctx, v0, v1, v2);
}

im_draw_triangle :: (using ctx: *Im_Context, p0: Vector2, p1: Vector2, p2: Vector2, t0: Vector2, t1: Vector2, t2: Vector2, c0: Vector4, c1: Vector4, c2: Vector4) {
    im_set_primitive(ctx, 3);
    im_ensure_space_for(ctx, 3, 3);

    v0 := im_vertex(ctx, p0, t0, c0);
    v1 := im_vertex(ctx, p1, t1, c1);
    v2 := im_vertex(ctx, p2, t2, c2);

    im_indices(ctx, v0, v1, v2);
}

im_draw_line :: (using ctx: *Im_Context, x0: float, y0: float, x1: float, y1: float, c: Vector4) {
    im_set_primitive(ctx, 2);
    im_ensure_space_for(ctx, 2, 2);

    v0 := im_vertex(ctx, xy(x0,y0), xy(0,0), c);
    v1 := im_vertex(ctx, xy(x1,y1), xy(1,1), c);

    im_indices(ctx, v0, v1);
}


/*im_draw_triangles :: (p: *Vector3, t: *Vector2, c: *Vector4, triangle_count: int) {

}*/

/*im_draw_primitive :: (primitive_type: Primitive_Type, primitive_count: int, vertex_data: *$T, vertex_stride:=0) {
    // @@ Use metaprogramming to determine how to bind each of the vertex attributes based on their annotation.
    // Vertex :: struct {
    //     pos: Vector2;   @position0
    //     tex: Vector2;   @texcoord0
    //     col: Vector4;   @color0
    // }
}*/

// Make sure there's enough space for these in the current buffers, otherwise flush them.
im_ensure_space_for :: (using ctx: *Im_Context, index_count: int, vertex_count: int) {
    assert(index_count <= index_array.allocated);
    assert(vertex_count <= vertex_array.allocated);

    if (index_array.count + index_count > index_array.allocated) || (vertex_array.count + vertex_count > vertex_array.allocated) {
        im_flush(ctx);
    }
}


// @Speed: We probably want to disable abc in all these functions.

im_index :: (using ctx: *Im_Context, idx: u16) {
    assert(index_array.count < index_array.allocated);
    inline array_add(*index_array, idx);
}

im_indices :: (using ctx: *Im_Context, indices: ..u16) {
    assert(index_array.count + indices.count <= index_array.allocated);
    
    for indices  inline array_add(*index_array, it);
    
    draw_cmd := *draw_array[draw_array.count - 1];
    draw_cmd.index_count += xx indices.count;
}

im_vertex :: (using ctx: *Im_Context, p: Vector2, t: Vector2, c: Vector4) -> u16 {
    assert(vertex_array.count < vertex_array.allocated);

    v := inline array_add(*vertex_array);
    v.pos.xy = p * scale + offset;
    v.pos.z = current_depth_z;
    v.tex = t;
    v.col = c;
    return cast(u16) (vertex_array.count - 1);
}


// You want to flush *only* if you change shaders or shader parameters.
im_flush :: (using ctx: *Im_Context) {
    if draw_array.count {
        draw_callback(ctx, index_array, vertex_array, draw_array);
    }
    
    index_array.count  = 0;
    vertex_array.count = 0;
    draw_array.count   = 0;

    push_fresh_command(ctx);
}



Im_Draw_Command :: struct {
    index_count : u32;
    index_per_primitive: u8; // 1, 2 or 3.
    clip_rect: Vector4;
    texture: *void;
    sampler: *void;
}

Im_Vertex :: struct {
    // TODO: Is there a way to verify at compile time that the pipeline created
    // actually matches a struct like this? If the shader has float2 for
    // position, for example, we get no warnings or errors--just junk rendering.
    pos: Vector3;
    tex: Vector2;
    col: Vector4;
}


Im_Context :: struct {
    draw_callback: Im_Draw_Callback;

    scale  : Vector2;
    offset : Vector2;

    index_array  : [..] u16;
    vertex_array : [..] Im_Vertex;
    draw_array   : [..] Im_Draw_Command;

    current_texture: *void;
    current_sampler: *void;
    current_index_per_primitive: u8 = 3;
    current_clip_rect: Vector4;
    current_depth_z: float;
}

#scope_file

#import "Math";
#import "Basic";

// @@ Group draw data in channels?

im_begin_draw :: (using ctx: *Im_Context, reset := true) -> *Im_Draw_Command {
    if draw_array.count == draw_array.allocated - 1 {
        im_flush(ctx);
    }

    if reset {
        current_index_per_primitive = 3;
        current_clip_rect = .{};
        current_texture = null;
        current_sampler = null;
    }

    return push_fresh_command(ctx);
}

push_fresh_command :: (using ctx: *Im_Context) -> *Im_Draw_Command {
    draw := array_add(*draw_array);
    draw.index_count = 0;
    draw.clip_rect = current_clip_rect;
    draw.index_per_primitive = current_index_per_primitive;
    draw.texture = current_texture;
    draw.sampler = current_sampler;

    return draw;
}
