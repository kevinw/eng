#import "Compiler";

#load "lib/Array_With_Holes.jai";
#load "lib/Small_Array.jai";

Component :: struct {
    entity: Entity_Handle;
}

Vec3 :: struct {
    x: float;
    y: float;
    z: float;
}

Vec4 :: struct {
    x: float;
    y: float;
    z: float;
    w: float;
}

Component_Entry :: struct {
    component_type_bit: Component_Bits;
    handle: Handle_Type;
}

Entity_Entry :: struct {
    component_bits: Component_Bits;
    components: Small_Array(Component_Entry);
}

Entity_Handle :: Array_With_Holes(Entity_Entry).Handle;

World :: struct {
    entities: Array_With_Holes(Entity_Entry);
    components: Component_Storage;
}

create_Entity :: (world: *World) -> Entity_Handle {
    slot := allocate_slot(*world.entities);
    //print("create_Entity returning %\n", slot);
    return slot;
}

get_component_bucket :: (world: *World, component_bucket: **$A/Array_With_Holes, $Component_Type: Type) #expand {
    #insert #run (($Component_Type: Type) -> string {
        sb: String_Builder;
        defer free_buffers(*sb);

        print_to_builder(*sb,
            "<< component_bucket = *world.components._%;",
            Component_Type);
        
        return builder_to_string(*sb);

    })(Component_Type);
}

get_sibling_component_ptr :: (e: Entity_Handle, $Component_Type: Type) -> *Component_Type {
    //print("get_sibling_component_ptr(e=%, %)\n", e, Component_Type);
    world := _world; // TODO: see _world note

    ok, entry := get_item(*world.entities, e);
    if !ok {
        print("couldn't find entity for %\n", e);
        return null;
    }

    bit :: #run Bit(Component_Type);
    if entry.component_bits & bit == 0 return null;

    component_bucket: *Array_With_Holes(Component_Type);
    get_component_bucket(world, *component_bucket, Component_Type);

    for * entry.components
        if it.component_type_bit == bit
            return get_item_ptr(component_bucket, it.handle);

    assert(false, "should have found a handle for the component, because the bits said we would");
    return null;
}

add_component :: (world: *World, e: Entity_Handle, $Component_Type: Type) -> *Component_Type {
    //print("add_component(e=%, %)\n", e, Component_Type);
    entry := get_item_ptr(*world.entities, e);
    assert(entry != null, "not a valid entity handle");

    bit :: #run Bit(Component_Type);
    assert(entry.component_bits & bit == 0);
    entry.component_bits |= bit;

    component_bucket: *Array_With_Holes(Component_Type);
    get_component_bucket(world, *component_bucket, Component_Type);

    component_entry: Component_Entry;
    component_entry.component_type_bit = bit;

    ptr: *Component_Type;
    component_entry.handle, ptr = allocate_slot(component_bucket);
    assert(ptr != null);

    ptr.entity = e;

    array_add(*entry.components, component_entry);

    return ptr;
}



// Components

Transform :: struct {
    using component: Component;
    pos: Vec3;
    scale: Vec3 = .{1, 1, 1};
    rotation: Vec4;
} @Component

Velocity :: struct {
    using component: Component;
    vel: Vec3;
} @Component

update :: (velocity: Velocity, transform: *Transform) {
    transform.pos.x += velocity.vel.x;
    transform.pos.y += velocity.vel.y;
    transform.pos.z += velocity.vel.z;
} @Updater

/*
for velocity component in velocity array
    if not alive continue
    e = velocity.entity
    if e.has_bit Transform
        vel_update(velocity, e.GetComponent<Transform>())
*/

/////

// TODO: generate from @Component notes

Components :: Type.[
    Transform,
    Velocity,
];

Component_Storage :: struct {
    #insert #run get_component_storage_code_string();
}

get_component_storage_code_string :: () -> string {
    sb: String_Builder;
    defer free_buffers(*sb);

    for Components
        print_to_builder(*sb, "_%: Array_With_Holes(%);\n", it, it);

    return builder_to_string(*sb);
}

print_component_to_builder :: (sb: *String_Builder, type: Type, bit: int) {
    print_to_builder(sb, "% :: (1 << %);\n", type, bit);
}

create_bit_flags :: () -> string {
    sb: String_Builder;
    defer free_buffers(*sb);

    for Components
        print_component_to_builder(*sb, it, it_index);

    return builder_to_string(*sb);
}

Component_Bits :: enum_flags u64 {
    // TODO: if we have more than 64 components we can just use Bit_Array maybe?
    #insert #run create_bit_flags();
}

Bit :: ($Component_Type: $Type) -> Component_Bits {
    bit: Component_Bits;
    for Components
        if Component_Type == it
            return cast(Component_Bits)(1 << it_index);
    assert(false, "component not found");
    return 0;
}

register_updater :: ($$proc: $ProcType) {
    assert(type_info(ProcType).type == .PROCEDURE, "must pass a procedure");
    ti_proc := cast(*Type_Info_Procedure)type_info(ProcType);
    print("updater: % %\n", proc, ti_proc.procedure_flags);
    {
        assert(ti_proc.return_types.count == 0);
        for arg_ti: ti_proc.argument_types {
            if arg_ti.type == {
                case .POINTER;
                    arg_ti_ptr := cast(*Type_Info_Pointer)arg_ti;

                    ptr_to_ti := arg_ti_ptr.pointer_to;
                    print("read-write arg: %\n", <<ptr_to_ti);
                    // read-write argument
                case .STRUCT;
                    // read-only argument

                    print("read-only arg: %\n", <<arg_ti);
            }
        }
    }
}

procs: [..]Any;
world_updaters :: () -> []Any { // TODO: this is going to be overwritten
    if procs.count == 0 {
        any: Any;
        any.value_pointer = cast(*void)update;
        any.type = type_info(type_of(update));
        array_add(*procs, any);
    }

    return procs;
}

update_world :: (world: *World) {
    for updater: world_updaters() {
        for vel: world.components._Velocity {
            transform_ptr := get_sibling_component_ptr(vel.entity, Transform);
            if transform_ptr != null
                update(vel, transform_ptr);

        }
    }

    /*
    #insert #run world_updaters();

    world_updaters :: () -> string {
        sb: String_Builder;
        defer free_buffers(*sb);


        return builder_to_string(*sb);
    }
    */
    

}

_world: *World; // TODO: index worlds as u4s hidden in one of the handles?

init_world :: (world: *World) {
    _world = world;
    init_array_with_holes(*world.entities);
    #insert #run (() -> string {
        sb: String_Builder;
        defer free_buffers(*sb);
        for Components {
            print_to_builder(*sb, "init_array_with_holes(*world.components._%);\n",
                it);
        }
        return builder_to_string(*sb);
    })();
}

#scope_module
#import "Basic";

main :: () {
    print("running ecs...\n");
    world: World;
    init_world(*world);
    e := create_Entity(*world);

    transform := add_component(*world, e, Transform);
    velocity := add_component(*world, e, Velocity);

    assert(transform.pos.x == 0);

    velocity.vel = Vec3.{1, 1, 0};

    transform_bit :: #run Bit(Transform);

    assert(transform_bit == cast(Component_Bits)(1 << 0), "expected Transform bit to be %, but it was %", (1<<0), transform_bit);
    assert(Bit(Velocity) == cast(Component_Bits)(1 << 1));

    update_world(*world);

    assert(transform.pos.x == 1, "update_world should have run the velocity updater");

    print("ecs ran ok\n");
}