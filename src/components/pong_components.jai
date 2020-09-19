#scope_file
screenlog :: #import "screenlog";
#scope_export

Bounce :: struct {
    using component: Component;

    velocity: Vector2;
    speed: float = 10;
}

on_enable :: (it: *Bounce, entity: *Entity) { }

bottom :: inline (r: Rectangle) -> float { return r.y + r.height; }
right  :: inline (r: Rectangle) -> float { return r.x + r.width; }

update :: (it: *Bounce, transform: *Transform) {
    using context.state;
    transform.position.xy += it.velocity * Time.delta_time * it.speed;

    bounds := make_Rectangle(0, 0, gameWidth, gameHeight);

    p := *transform.position;

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
