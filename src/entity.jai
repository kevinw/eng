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
};

update :: (using it: *Worldspace_Text) {
    //position.y -= delta_time;
}

draw :: (using it: *Worldspace_Text) {
    //DrawText(message, xx position.x, xx position.y, 12, RED);
}

#load "components/sprite_renderer.jai";

Component :: struct {
    entity: *Entity;
}

Transform :: struct {
    position: Vector3;
    scale: Vector3;
    rotation: Quaternion;
}

Entity :: struct {
    transform: Transform;
    components: [..]Any;

    world: *World;
}

all_component_types :: Type.[
    Worldspace_Text,
    SpriteRenderer,
];

get_component_buckets :: () -> string {
    sb: String_Builder;
    defer free_buffers(*sb);

    for all_component_types {
        print_to_builder(*sb, "_%: [..]%;\n", it, it);
    }
    
    return builder_to_string(*sb);
}

World :: struct {
    entities: [..]Entity;

    #insert #run get_component_buckets();
};

world_update :: (world: *World, delta_time: float) {
    for * world._Worldspace_Text update(it);
    for * world._SpriteRenderer update(it);
}

world_draw :: (world: *World) {
    for * world._Worldspace_Text draw(it);
    for * world._SpriteRenderer  draw(it);
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
    } else if component_type == SpriteRenderer {
        bucket = *entity.world._SpriteRenderer;
    }

    MAX :: 100;
    if bucket.allocated == 0
        array_reserve(bucket, MAX);

    bucket_entry := array_add(bucket);
    assert(bucket.count <= MAX, "TODO: implement a freelist and a generation index thing");

    c := cast(*component_type)bucket_entry;
    array_add(*entity.components, c);
    c.entity = entity;

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