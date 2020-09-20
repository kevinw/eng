Rotater :: struct {
    using component: Component;

    speed: Vector3;
}

on_enable :: (rotater: *Rotater, entity: *Entity) {
}

update :: (it: *Rotater, transform: *Transform) {
    print("TODO: rotate!\n");
}
