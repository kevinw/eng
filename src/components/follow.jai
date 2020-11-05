Follow :: struct {
    using component: Component;

    target: Entity_Handle;
    speed: float = 50;
}

update :: (using it: *Follow, transform: *Transform) {
    using context.state;

    target_transform := get_transform(target);
    if target_transform != null {
        delta := target_transform.position - transform.position;
        transform.position += normalized(delta) * speed * Time.delta_time;
    }
}


#scope_file
#import "raymath";
