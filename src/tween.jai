Tween :: struct {
    target: Any;

    from: Any;
    to: Any;

    timer: float;
    duration: float;
}

apply_tweens :: (tweens: []Tween) {
    dt := context.state.Time.delta_time;

    for * tweens {
        using it;
        timer += dt;
        factor := timer / duration;
        lerp_into(target, from, to, factor);
        if factor >= 1 {
            print("Tween done.\n");
            remove it;
        }
    }
}

lerp_into :: (target: Any, from: Any, to: Any, factor: float) {
    assert(factor >= 0);
    assert(factor <= 1);
}

Tweens :: struct {
    active: [..]Tween;
}


#scope_file
#import "Basic";
