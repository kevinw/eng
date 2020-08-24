#import "Basic";
#import "raylib";

// TODO: generate these imports
#load "components/sprite_renderer.jai";
#load "components/box_collider.jai";
#load "components/rect_renderer.jai";

// goals

// be able to sketch an entity real fast without making a new file; so ideally it could just start
// as a struct with optional methods
// then move it to a module when you want to "solidify" it

// some inspiration maybe: https://github.com/skypjack/entt/wiki/Crash-Course:-entity-component-system

all_component_types :: Type.[
    SpriteRenderer,
    BoxCollider,
    RectRenderer,
];

Component :: struct {
    entity: *Entity;
}

Transform :: struct {
    position: Vector3;
    scale: Vector3;
    rotation: Quaternion;
}

Entity :: struct {
    Flags :: enum_flags u16 {
        None               :: (0 << 0);
        Has_Component_Rect :: (1 << 0);
    }

    using transform: Transform;
    components: [..]Any;
    _world: *World;
    flags: Flags;
}

entity_rect :: (entity: *Entity, verbose := false) -> Rectangle {
    if entity.flags & .Has_Component_Rect {
        for * entity.components {
            if it.type == type_info(SpriteRenderer) {
                spr := cast(*SpriteRenderer)it.value_pointer;
                assert(spr.canary == 42);
                ok, rect := get_entity_rect(spr);
                if ok return rect;
            }
        }
    }

    pos := entity.position.xy;
    sz := entity.scale.xy;
    return make_Rectangle(pos.x, pos.y, sz.x, sz.y);
}

get_component_buckets :: () -> string {
    sb: String_Builder;
    defer free_buffers(*sb);

    for all_component_types {
        print_to_builder(*sb, "_%: [..]BucketEntry(%);\n", it, it);
    }
    
    return builder_to_string(*sb);
}

BucketEntry :: struct(T: Type) {
    using value: T;
    dead: bool;
}

bucket_chooser :: () -> string {
    sb: String_Builder;
    defer free_buffers(*sb);

    for all_component_types {
        print_to_builder(*sb, "#if component_type == % bucket = *entity._world._%;\n", it, it);
    }

    print_to_builder(*sb, "assert(bucket != null);\n");

    return builder_to_string(*sb);
}

World :: struct {
    entities: [..]Entity;

    #insert #run get_component_buckets();
};

world_update :: (world: *World, delta_time: float) {
    for * world._SpriteRenderer update(it);
}

world_draw :: (world: *World) {
    for * world._SpriteRenderer  draw(it);
}

create_entity :: (world: *World) -> *Entity {
    assert(world != null);

    e := array_add(*world.entities);
    e._world = world;
    return e;
}

destroy_entity :: (world: *World, entity: *Entity) {
    assert(world != null);
    assert(entity != null);


    //array_unordered_remove_by_value(*world.entities, entity);

    for * entity.components {
        /*
        component_type := it.type;

        bucket: *[..]BucketEntry(*void);
        #insert #run bucket_chooser();

        assert(it.value_pointer >= bucket.data && it.value_pointer <= bucket.data + bucket.count);
        */
        print("TODO: mark component slot as free\n");
    }
}

add_component :: (entity: *Entity, $component_type: Type) -> *component_type {
    assert(entity != null, "entity cannot be null");
    assert(entity._world != null, "entity has a null *World");

    bucket: *[..]BucketEntry(component_type);

    #insert #run bucket_chooser();

    MAX :: 100;
    if bucket.allocated == 0
        array_reserve(bucket, MAX);

    bucket_entry := array_add(bucket);
    assert(bucket.count <= MAX, "TODO: implement a freelist and a generation index thing");

    c := cast(*component_type)bucket_entry;

    any: Any;
    any.value_pointer = c;
    any.type = type_info(component_type); // TODO: compiler generated Sum_Type thing

    array_add(*entity.components, any);
    c.entity = entity;

    return c;
}
