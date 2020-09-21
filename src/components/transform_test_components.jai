Rotater :: struct {
    using component: Component;
    speed: Vector3;
    count := 10;
}

update :: (using it: *Rotater, transform: *Transform) {
    if count > 0 {
        count -= 1;
        print("TODO: rotate!\n");
    }
}
