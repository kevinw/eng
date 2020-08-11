#import "Basic";
#import "raylib";

// goals

// be able to sketch an entity real fast without making a new file; so ideally it could just start
// as a struct with optional methods
// then move it to a module when you want to "solidify" it

// some inspiration maybe: https://github.com/skypjack/entt/wiki/Crash-Course:-entity-component-system

Worldspace_Text :: struct {
    using component: Component;

    message: string = "Foobar";
    position: Vector2 = .{42, 42};
    time: float64;
    
    update :: (using this: *Worldspace_Text, delta_time: float) {
        //position.y -= delta_time;
    }

    draw :: (using this: *Worldspace_Text) {
        DrawText(message, xx position.x, xx position.y, 12, RED);
    }
};

Component :: struct {
    entity: *Entity;
}

Entity :: struct {
    world: *World;
    components: [..]Any;
}

World :: struct {
    entities: [..]Entity;

    _Worldspace_Text: [..]Worldspace_Text;
};

world_update :: (world: *World, delta_time: float) {
    for * world._Worldspace_Text
        Worldspace_Text.update(it, delta_time);
}

world_draw :: (world: *World) {
    for * world._Worldspace_Text
        Worldspace_Text.draw(it);
}

create_entity :: (world: *World) -> *Entity {
    assert(world != null);

    e := array_add(*world.entities);
    e.world = world;
    return e;
}

add_component :: (entity: *Entity, $component_type: Type) -> *component_type {
    assert(entity != null, "entity cannot be null");
    assert(entity.world != null, "entity has a null *World");

    bucket: *[..]component_type;

    #if component_type == Worldspace_Text {
        bucket = *entity.world._Worldspace_Text;
    }

    MAX :: 100;
    if bucket.allocated == 0
        array_reserve(bucket, MAX);

    bucket_entry := array_add(bucket);
    print("add_component made count % of: %\n", bucket.count, bucket.data);
    assert(bucket.count <= MAX, "TODO: implement a freelist and a generation index thing");

    c := cast(*component_type)bucket_entry;
    array_add(*entity.components, c);
    return c;
}


/*
main :: () {
    e: Entity;

    //c := array_add(*all.one);
    c := add_component(e, Worldspace_Text);

    assert(c != null);
    print("c: %\n", <<c);
}
*/