#scope_file
screenlog :: #import "screenlog";
#import "Math";
#scope_export

Bounce :: struct {
    using component: Component;

    velocity: Vector2;
    speed: float = 10;
}

on_enable :: (it: *Bounce, entity: *Entity) { }

bottom :: inline (r: Rectangle) -> float { return r.y + r.height; }
right  :: inline (r: Rectangle) -> float { return r.x + r.width; }

// TODO: this can go aways
draw :: (it: *Bounce) {
    for *paddle: context.state.world._Pong_Paddle {
        #import "Debug";

        ok, ent_ptr := get_entity(paddle.entity);
        if !ok continue;

        box := get_component(ent_ptr, BoxCollider);
        if box != null {
            r := worldspace_rect(box);
            //r := entity_rect(paddle.entity);
            //draw_rect_outline(r, 2, GREEN);
        }
        //scrlog(it, "%", r);
    }

}

update :: (it: *Bounce, transform: *Transform) {
    using context.state;

    transform.position.xy += it.velocity * Time.delta_time * it.speed;

    p := *transform.position;

    for *paddle: world._Pong_Paddle {
        ok, ent_ptr := get_entity(paddle.entity);
        if !ok continue;

        box := get_component(ent_ptr, BoxCollider);
        if box == null continue;

        r := worldspace_rect(box);
        radius := max(transform.scale.x, transform.scale.y);

        if CheckCollisionCircleRec(transform.position.xy, radius, r) {
            delta := transform.position.xy - midpoint(r);
            if abs(delta.x) > abs(delta.y) {
                it.velocity.x *= -1;
            } else {
                it.velocity.y *= -1;
            }
        }
    }

    bounds := make_Rectangle(0, 0, gameWidth, gameHeight);

    if p.y > bottom(bounds) {
        p.y = bottom(bounds);
        it.velocity.y *= -1;
    }

    if p.x > right(bounds) {
        p.x = right(bounds);
        it.velocity.x *= -1;
    }

    if p.x < bounds.x {
        p.x = bounds.x;
        it.velocity.x *= -1;
    }

    if p.y < bounds.y {
        p.y = bounds.y;
        it.velocity.y *= -1;
    }
}
