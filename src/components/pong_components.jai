Bounce :: struct {
    using component: Component;

    velocity: rl.Vector2;
    speed: float = 10;

    dies_on_collide := false;
}

bottom :: inline (r: rl.Rectangle) -> float { return r.y + r.height; }
right  :: inline (r: rl.Rectangle) -> float { return r.x + r.width; }

update :: (using it: *Bounce, transform: *Transform) {
    using context.state;

    transform.position.xy += it.velocity * Time.delta_time * it.speed;

    p := *transform.position;
    radius := max(transform.scale.x, transform.scale.y);

    for *paddle: world._Pong_Paddle {
        ok, ent_ptr := get_entity(paddle.entity);
        if !ok continue;

        box := get_component(ent_ptr, BoxCollider);
        if box == null continue;

        r := worldspace_rect(box);

        if rl.CheckCollisionCircleRec(p.xy, radius, r) {
            delta := p.xy - midpoint(r);
            // this is wrong
            if abs(delta.x) > abs(delta.y) {
                it.velocity.x *= -1;
            } else {
                it.velocity.y *= -1;
            }
        }
    }

    if dies_on_collide
    for *other: world._Bounce {
        if it == other continue;
        other_t := get_transform(other);
        if !other_t continue;

        other_radius := max(other_t.scale.x, other_t.scale.y);

        if rl.CheckCollisionCircles(p.xy, radius, other_t.position.xy, other_radius) {
            logprint("boom", "BOOM");
            other.velocity += it.velocity;
            destroy_entity(it.entity);
        }
    }


    bounds := rl.make_Rectangle(0, 0, context.state.gameWidth, context.state.gameHeight);

    if p.y > bottom(bounds) {
        p.y = bottom(bounds);
        if dies_on_collide destroy_entity(entity);
        else it.velocity.y *= -1;
    }

    if p.x > right(bounds) {
        p.x = right(bounds);
        if dies_on_collide destroy_entity(entity);
        else it.velocity.x *= -1;
    }

    if p.x < bounds.x {
        p.x = bounds.x;
        if dies_on_collide destroy_entity(entity);
        else it.velocity.x *= -1;
    }

    if p.y < bounds.y {
        p.y = bounds.y;
        if dies_on_collide destroy_entity(entity);
        else it.velocity.y *= -1;
    }
}

#scope_file
screenlog :: #import "screenlog";
#import "Math";
rl :: #import "raylib";
