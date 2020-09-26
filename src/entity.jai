/*

TODO

the our machinery blog mentions an interesting fact in this post --
https://ourmachinery.com/post/syncing-a-data-oriented-ecs/

-- that one way to view groups of entities and the systems that act on them are
as "types". an entity type defines which components it has. so (Transform, Rotater)
is a type.

the key takeaway from that post for me is that the entities of a certain type all
have their component data stored sequentially. that means that

velocity_system :: (td: *Transform, vd: *Velocity @const, n: u32, dt: float) {
    while n > 0 {
        td.pos = vec3_mul_add(td.pos, vd.vel, dt);
        td += 1;
        vd += 1;
        n -= 1;
    }
}


...that's cool. i wonder if there's an easy way to bridge the gap between what
we have now, and this kind of thing...


*/

#module_parameters(GAME_NAME := "");
#assert(GAME_NAME.count > 0);



#if GAME_NAME == "beat_platformer" {
    #load "components/sprite_renderer.jai";
    #load "components/box_collider.jai";
    #load "components/rect_renderer.jai";
    #load "components/enemy.jai";
    #load "components/player.jai";
    #load "components/shape_renderer.jai";
}
#if GAME_NAME == "pong" {
    #load "components/sprite_renderer.jai";
    #load "components/box_collider.jai";
    #load "components/rect_renderer.jai";
    #load "components/pong_paddle.jai";
    #load "components/shape_renderer.jai";
    #load "components/pong_components.jai";
}
#if GAME_NAME == "transform_test" {
    #load "components/sprite_renderer.jai";
    #load "components/box_collider.jai";
    #load "components/rect_renderer.jai";
    #load "components/enemy.jai";
    #load "components/player.jai";
    #load "components/shape_renderer.jai";
    #load "components/transform_test_components.jai";
}
#load "components/editor_selectable_rect.jai";
#load "components/camera.jai";
#load "components/follow.jai";

Transform :: struct {
    using component: Component;
    position: rl.Vector3 = .{0, 0, 0};
    rotation: rl.Quaternion = .{0, 0, 0, 1};
    scale: rl.Vector3 = .{1, 1, 1};
}

Link :: struct {
    using component: Component;
    parent: Entity_Handle;
}

TRS :: Transform;

// goals

// be able to sketch an entity real fast without making a new file; so ideally it could just start
// as a struct with optional methods
// then move it to a module when you want to "solidify" it

// some inspiration maybe: https://github.com/skypjack/entt/wiki/Crash-Course:-entity-component-system

// declare a list of all component type infos
#insert #run (() -> string {
    Compiler :: #import "Compiler";
    #import "Sort";

    all_components: [..]*Type_Info_Struct;
    for Compiler.get_type_table() {
        if Compiler.is_subclass_of(it, "Component") { // TODO: don't do this lookup by name
            ti_struct := cast(*Type_Info_Struct)it;
            array_add(*all_components, ti_struct);
        }
    }

    compare_type_info_names :: (a: *Type_Info_Struct, b: *Type_Info_Struct) -> s64 {
        return compare_strings(a.name, b.name);
    }

    // We need to sort the component names, since the compiler does not find them
    // in a determinate order.
    quick_sort(all_components, compare_type_info_names);

    sb: String_Builder;
    defer free_buffers(*sb);
    p :: print_to_builder;
    p(*sb, "all_component_types :: Type.[\n");
    for all_components
        p(*sb, "    %,\n", it.name);
    p(*sb, "];\n");

    // each component gets a bit.
    p(*sb, "Component_Bit :: enum_flags {\n");
    for all_components
        p(*sb, "    % :: (1 << %);\n", it.name, it_index);
    p(*sb, "}\n");

    p(*sb, "component_bit_to_ti :: (bit: Component_Bit) -> *Type_Info_Struct {\n");
    p(*sb, "    if bit == {\n");
    for all_components
        p(*sb, "        case .%; return type_info(%);\n", it.name, it.name);
    p(*sb, "    }\n");
    p(*sb, "}\n");

    p(*sb, "component_ti_to_bit :: (component_ti: *Type_Info_Struct) -> Component_Bit {\n");
    p(*sb, "    if component_ti.name == {\n");
    for all_components
        p(*sb, "        case \"%\"; return Component_Bit.%;\n", it.name, it.name);
    p(*sb, "    }\n");
    p(*sb, "}\n");


    return builder_to_string(*sb);
}());

get_entity :: (entity_handle: Entity_Handle) -> (bool, *Entity) {
    if entity_handle.id == 0 return false, null; // TODO: not sure if this should be down in get_item_ptr

    entity := get_item_ptr(*context.state.world.entities, entity_handle);
    return entity != null, entity;
}

get_component_ti_from_name :: (name: string) -> *Type_Info_Struct {

    #insert #run (() -> string {
        cases := foreach_component_type(#string END
            case "<type>"; return type_info(<type>);
        END);
        name_switch_code_str := tprint("if name == {\n%}\n", cases);
        return name_switch_code_str;
    }());

    assert(false, tprint("no component named %", name));
    return null;
}

Component :: struct {
    entity: Entity_Handle;
}

Entity :: struct {
    Flags :: enum_flags u16 {
        None               :: (0 << 0);
        Has_Component_Rect :: (1 << 0);
        Pivot_Center       :: (1 << 1);
    }

    flags: Flags;
    name: string; @free_in_deinit // TODO

    Component_Entry :: struct {
        component_handle: Handle_Type;
        bit: Component_Bit;
    }

    // TODO: Small_Array here could be a big win
    components: [..]Component_Entry;  @noserialize
}

get_components :: ($component_type: Type) -> []*component_type {
    all: [..]*component_type;
    all.allocator = __temporary_allocator;

    bucket: *Array_With_Holes(component_type);
    #insert #run bucket_chooser();
    for * bucket array_add(*all, it);

    return all;
}

get_component :: (entity_handle: Entity_Handle, $component_type: Type) -> *component_type {
    ok, entity := get_entity(entity_handle);
    if !ok return null;

    return get_component(entity, component_type);
}

get_component :: (component: *Component, $component_type: Type) -> *component_type {
    return get_component(component.entity, component_type);
}

get_component :: (entity: *Entity, $component_type: Type) -> *component_type {
    assert(entity != null);

    #assert(type_info(component_type).type == .STRUCT);
    component_bit :: #run component_ti_to_bit(cast(*Type_Info_Struct)type_info(component_type));

    for * entity.components {
        if it.bit == component_bit {
            sibling_handle := it.component_handle;

            bucket: *Array_With_Holes(component_type);
            #insert #run bucket_chooser();
            assert(bucket != null);

            sibling_ptr := get_item_ptr(bucket, sibling_handle);
            if sibling_ptr != null return sibling_ptr;
        }
    }

    return null;
}


get_transform :: (component: *Component) -> *Transform { return get_component(component.entity, Transform); }
get_transform :: (entity: *Entity) -> *Transform { return get_component(entity, Transform); }
get_transform :: (entity_handle: Entity_Handle) -> *Transform { return get_component(entity_handle, Transform); }

get_transform_or_null :: (entity_handle: Entity_Handle) -> *Transform { return get_component(entity_handle, Transform); }

get_component :: (entity: *Entity, component_ti: *Type_Info_Struct) -> *Component {
    assert(entity != null);

    component_bit := component_ti_to_bit(component_ti);

    for * entity.components {
        if it.bit == component_bit {
            sibling_handle := it.component_handle;
            #insert #run runtime_bucket_chooser(#string END
                return get_item_ptr(bucket, sibling_handle);
            END);
        }
    }

    return null;
}

entity_rect :: (entity_handle: Entity_Handle) -> rl.Rectangle {
    ok, entity := get_entity(entity_handle);
    assert(ok && entity != null);
    return entity_rect(entity);
}

operator + :: inline (rect: rl.Rectangle, pos: rl.Vector2) -> rl.Rectangle {
    return rl.make_Rectangle(rect.x + pos.x, rect.y + pos.y, rect.width, rect.height);
}


entity_rect :: (entity: *Entity, verbose := false) -> rl.Rectangle {
    if entity.flags & .Has_Component_Rect {

        // TODO: this is the kind of thing where we might be able to know based on the bitflag in the entity,
        // which method to call, and what to cast to. static dispatch ~!

        spr := get_component(entity, SpriteRenderer);
        if spr != null {
            assert(spr.canary == 42);
            ok, rect := get_entity_rect(spr);
            if ok return rect;
        }

        #if GAME_NAME == "beat_platformer" {
            enemy := get_component(entity, Enemy);
            if enemy != null
                return enemy_rect(enemy);
        }

        editor_selectable_rect := get_component(entity, Editor_Selectable_Rect);
        if editor_selectable_rect != null {
            r := editor_selectable_rect.rect + get_transform(entity).position.xy;
            //logprint("editor", "entity rect % for %\n", r, entity);
            return r;
        }
    }


    trs := get_transform(entity);
    if trs == null {
        logprint("=entity_rect", "no Transform in % %\n", entity.name, entity);
        return .{};
    }

    pos := trs.position.xy;
    sz := trs.scale.xy;

    if entity.flags & .Pivot_Center
        pos -= sz * 0.5;

    return rl.make_Rectangle(pos.x, pos.y, sz.x, sz.y);
}

get_component_buckets :: () -> string {
    return buf_string((sb: *String_Builder) {
        for all_component_types
        print_to_builder(sb, "_%: Array_With_Holes(%);\n", it, it);
    });
}

bucket_chooser :: () -> string {
    return buf_string((sb: *String_Builder) {
        for all_component_types
        print_to_builder(sb, "#if component_type == % bucket = *context.state.world._%;\n", it, it);
    });
}

foreach_component_type :: (inner_code_string: string) -> string {
    sb: String_Builder;
    defer free_buffers(*sb);
    for all_component_types {
        replaced := String.replace(inner_code_string, "<type>", tprint("%", it)); // @Leak compile-time
        defer free(replaced);

        print_to_builder(*sb, "%\n", replaced);
    }
    return builder_to_string(*sb);
}

runtime_bit_bucket_chooser :: (inner_code_string: string) -> string {
    sb: String_Builder;
    defer free_buffers(*sb);

    print_to_builder(*sb, "if component_bit == {\n");
    for all_component_types {
        print_to_builder(*sb, "    case .%;\n", it);
        print_to_builder(*sb, "        bucket := *context.state.world._%;\n", it);
        print_to_builder(*sb, "        %\n", inner_code_string);
    }

    print_to_builder(*sb, "    case; assert(false, \"unknown component bit\");\n");
    print_to_builder(*sb, "}\n");

    return builder_to_string(*sb);
}

runtime_bucket_chooser :: (inner_code_string: string) -> string {
    sb: String_Builder;
    defer free_buffers(*sb);

    for all_component_types {
        print_to_builder(*sb, "if component_ti == type_info(%) {\n", it);
        print_to_builder(*sb, "    bucket := *context.state.world._%;\n", it);
        print_to_builder(*sb, "    %\n", inner_code_string);
        print_to_builder(*sb, "}\n");
    }

    return builder_to_string(*sb);
}

_return_component_array_add :: () -> string {
    return buf_string((sb: *String_Builder) {
        for all_component_types {
            maybe_else := ifx it_index > 0 then "else " else "";
            print_to_builder(sb, "%if component_ti.name == \"%\" {\n", maybe_else, it);
            print_to_builder(sb, "    ptr: *%;\n", it);
            print_to_builder(sb, "    component_handle, ptr = allocate_slot(*context.state.world._%, undo=undo);\n", it);
            print_to_builder(sb, "    component_type_info = type_info(%);\n", it);
            print_to_builder(sb, "    ptr.entity = entity_handle;\n");
            print_to_builder(sb, "    run_on_enable(ptr, entity);\n", it);
            print_to_builder(sb, "    c = ptr;\n", it);
            print_to_builder(sb, "}\n", it);
        }
    });
}

buf_string :: (f: (sb: *String_Builder)) -> string {
    sb: String_Builder;
    defer free_buffers(*sb);

    f(*sb);

    return builder_to_string(*sb);
}

Entity_Handle :: Handle_Type;

World :: struct {
    canary1 := 101;
    entities: Array_With_Holes(Entity);
    #insert #run get_component_buckets();


    canary2 := 999;

    prefab_cache: Prefab_Cache;

    deinit :: (using world: *World) {
        Prefab_Cache.deinit(*prefab_cache);
    }
};

init_world :: (world: *World) {
    init_array_with_holes(*world.entities, "all-entities");
    #insert #run(() -> string {
        return buf_string((sb: *String_Builder) {
            for all_component_types {
                print_to_builder(sb, "init_array_with_holes(*context.state.world._%, \"all-%\");\n", it, it);
            }
        });
    }());
}

world_update :: (world: *World, delta_time: float) {
    #if GAME_NAME == "beat_platformer"
        enemy_update_all();
    run_all(world, .update);
}

world_draw :: (world: *World = null) {
    if world == null world = *context.state.world;

    assert(world.canary1 == 101, tprint("world canary1 was not 101: %", world.canary1));
    assert(world.canary2 == 999, tprint("world canary1 was not 999: %", world.canary2));

    run_all(world, .draw);
}

#placeholder run_all;
#placeholder run_on_enable;

create_entity :: (world: *World = null, name: string = "", id: s32 = -1,
    undo: *Undo.Impl = null, create_transform_component := true
) -> *Entity, Entity_Handle {
    if world == null
        world = *context.state.world;
    assert(world != null);

    handle, e := allocate_slot(*world.entities, undo=undo);

    name_to_use: string;
    if name.count == 0
        name_to_use = "Unnamed Entity";
    else
        name_to_use = name;

    e.name = copy_string_z(name_to_use); // @Leak

    if create_transform_component
        add_component(handle, Transform, undo=undo);

    return e, handle;
}

get_entity_handle :: inline (entity: *Entity) -> Entity_Handle {
    return get_handle_for_value_ptr(*context.state.world.entities, entity);
}

destroy_entity :: inline (entity_ptr: *Entity, undo: *Undo.Impl = null) {
    destroy_entity(get_entity_handle(entity_ptr), undo);
}

destroy_entity :: (e: Entity_Handle, undo: *Undo.Impl = null) {
    other_e := e;
    assert(other_e.id == e.id, "simple assignment of entity handle failed");

    entity := get_item_ptr(*context.state.world.entities, e);
    if !entity return;

    assert(other_e.id == e.id, "simple assignment of entity handle failed #2");
    for entity.components {
        component_bit := it.bit;
        component_handle := it.component_handle;
        {
            #insert #run runtime_bit_bucket_chooser(#string END
                did_delete := delete_item(bucket, component_handle, undo);
                assert(did_delete, "delete_item for component failed");
            END);
        }
    }

    did_delete := delete_item(*context.state.world.entities, other_e, undo);

    // TODO: this has to come AFTER the delete_item(entities) call directly above us.
    // this is because the address of the array we're resetting is in the bounds
    // of the thing we "noted" in delete_item. that means we want to restore the array
    // here after restoring the rest of the entity state upon undo.
    //
    // There might be some kind of sorting inside the Undo module we can do to
    // make this ordering unimportant and "just work," but it needs more thought I think and for now
    // we'll just be careful.
    Undo.array_reset(undo, *entity.components);

    assert(did_delete, "delete_item for entity failed");
}

add_or_get_component :: (entity_handle: Entity_Handle, component_ti: *Type_Info_Struct) -> *Component {
    return add_component(entity_handle, component_ti);
}

add_component :: (entity_handle: Entity_Handle, component_ti: *Type_Info_Struct, undo: *Undo.Impl=null) -> *Component {
    ok, entity := get_entity(entity_handle);
    assert(ok);

    c: *Component;
    component_type_info: *Type_Info_Struct;
    component_handle: Handle_Type;

    #insert #run _return_component_array_add();
    assert(component_type_info != null);
    assert(component_handle.id >= 0);
    assert(component_handle.generation >= 0);

    if undo Undo.push_array(undo, *entity.components);

    entry := array_add(*entity.components);
    entry.bit = component_ti_to_bit(component_type_info);
    entry.component_handle = component_handle;

    assert(c != null);
    // c.entity = entity_handle; // this is seet in _return_component_array_add
    return c;
}

add_component :: (entity_handle: Entity_Handle, $component_type: Type, undo: *Undo.Impl=null) -> *component_type {
    ok, entity := get_entity(entity_handle);
    assert(ok);

    bucket: *Array_With_Holes(component_type);
    #insert #run bucket_chooser();

    component_handle, component_ptr := allocate_slot(bucket, undo=undo);
    c := cast(*component_type)component_ptr;

    if undo Undo.push_array(undo, *entity.components);
    entry := array_add(*entity.components);
    entry.bit = component_ti_to_bit(cast(*Type_Info_Struct)type_info(component_type));
    entry.component_handle = component_handle;

    c.entity = entity_handle;
    run_on_enable(c, entity);

    return c;
}

Prefab_Cache :: struct {
    Entry :: struct {
        // key
        filename: string; @owned

        // value
        entity_name: string; @owned
        entity_id: s32;

        components: [..]struct {
            component_type_name: string; @owned
            object_node: *wbml.Node; @owned
        };

        transform_node: *wbml.Node;
    }

    entries: [..]Entry;

    deinit :: (using self: *Prefab_Cache) { // TODO: autogen this function from @owned
        for entries {
            for it.components {
                free(it.component_type_name);
                wbml.delete_node(it.object_node);
            }

            if it.transform_node wbml.delete_node(it.transform_node);
        }
    }
}

get_prefab_cache_entry :: (filename: string) -> *Prefab_Cache.Entry {
    for * context.state.world.prefab_cache.entries
        if it.filename == filename
            return it;

    entity_file_text, ok := File.read_entire_file(filename);
    if !ok {
        logprint("error", "no prefab at %", filename);
        return null;
    }
    defer free(entity_file_text);
    print("read % bytes from '%'\n", entity_file_text.count, filename);

    // entity id
    lexer := laas.make_lexer(entity_file_text);
    entity_id_token, ok2 := laas.expect(*lexer, .Number);
    assert(ok2, "did not find an entity id");
    entity_id := cast(s32)string_to_int(entity_id_token.text);

    // entity name
    name_token, name_ok := laas.expect(*lexer, .Identifier);
    assert(name_ok);
    entity_name := copy_string(name_token.text);

    cache_entry: Prefab_Cache.Entry;
    cache_entry.filename = copy_string(filename);
    cache_entry.entity_name = entity_name;
    cache_entry.entity_id   = entity_id;

    // load the component data
    while true {
        while laas.is_token(*lexer, .New_Line) laas.eat(*lexer);
        component_name_ident, component_name_ok := laas.expect(*lexer, .Identifier);
        if !component_name_ok break;

        nl, nl_ok := laas.expect(*lexer, .New_Line);
        assert(nl_ok, "expected a newline after the component name '%'", component_name_ident.text);

        value := wbml.parse_value(*lexer);
        assert(value != null, "could not parse value as wbml");
        assert(value.type == .Object);
        value = wbml.deep_copy(value);

        if component_name_ident.text == "Transform" {
            // TODO: this goes away once Transform is just another component.
            cache_entry.transform_node = value;
        } else {
            ti := get_component_ti_from_name(component_name_ident.text);

            component_cache_entry := array_add(*cache_entry.components);
            component_cache_entry.component_type_name = copy_string(ti.name);
            component_cache_entry.object_node = value;
        }
    }

    ptr := array_add(*context.state.world.prefab_cache.entries);
    <<ptr = cache_entry;
    return ptr;
}

component_on_serialize :: (any: *Any, added_fields: *[..]wbml.Added_Field_Entry) {
    if added_fields != null {
        if any.type == type_info(Entity) {
            entry := array_add(added_fields);

            // I don't like this at all. Maybe we need a "possibly-local" Any?
            // Or maybe the temporary allocator here is good enough.
            my_int  := cast(*int)talloc(size_of(int));


            // I don't like this either. Above us, when we're iterating over
            // the entities bucket, we definitely already know the entity id.
            // This feels like the wrong place to be looking it up again.
            <<my_int = get_entity_handle((cast(*Entity)any.value_pointer)).id;

            entry.name = "id";
            entry.any.value_pointer = my_int;
            entry.any.type = type_info(int);
        }
    }

    //
    // Used during serialization to change "in memory" data to "on disk" data.
    //
    if any.type == type_info(LiveSprite) {
        // just serialize the LiveSprite's filename
        live_sprite := cast(*LiveSprite)any.value_pointer;
        any.type = type_info(string);
        any.value_pointer = *live_sprite.filename;
    }
}


Entity_Handle_Map_Entry :: struct {
    live: Entity_Handle;
    on_disk: u32;
}

Entity_Handle_Map :: [..]Entity_Handle_Map_Entry;

on_component_deserialize :: (any: *Any, node: *wbml.Node, userdata: *void) -> (handled: bool) {
    assert(any != null);
    assert(userdata != null);

    if any.type.type == .STRUCT && any.type == type_info(Entity_Handle) {
        handle_ptr := cast(*Entity_Handle)any.value_pointer;

        number_node := wbml.get(node, "id", .Number, do_remove=false);
        assert(number_node != null, "expected node id for an Entity_Handle.id to have a number");
        wbml_entity_id := number_node._number.int_value;

        for <<cast(*Entity_Handle_Map)userdata {
            print("  % vs %\n", it.on_disk, wbml_entity_id);
            if it.on_disk == wbml_entity_id {
                <<handle_ptr = it.live;
                return true;
            }
        }
        print("WARNING: handle could not be remapped: %\n", <<handle_ptr);
    }

    return false;
}


load_world :: (world: *World, wbml_string: string) {
    lexer := laas.make_lexer(wbml_string);

    new_entity_handles: Entity_Handle_Map;
    defer array_free(new_entity_handles);

    while true {
        while laas.is_token(*lexer, .New_Line) laas.eat(*lexer);

        name_token, name_ok := laas.expect(*lexer, .Identifier);
        if !name_ok break;
        // TODO: nocheckin ensure we've parsed the whole text here.
        class_name := copy_string(name_token.text);

        value := wbml.parse_value(*lexer);
        if class_name == {
            case "Entity";
                assert(value.type == .Object);
                entity_id := cast(s32)wbml.get(value, "id", .Number)._number.int_value;
                entity_name := copy_string(wbml.get(value, "name", .String)._string); // @Leak
                assert(entity_id != 0);
                new_entity_ptr, new_entity_handle := create_entity(world, entity_name, entity_id, create_transform_component=false);
                wbml.write_value(value, new_entity_ptr, "Entity");

                entry := array_add(*new_entity_handles);
                entry.live = new_entity_handle;
                entry.on_disk = cast(u32)entity_id;
            case;
                // It's a component.
                c := wbml.get_obj(value, "component");
                e := wbml.get_obj(c, "entity");
                id_node := wbml.get(e, "id", .Number);
                assert(id_node != null);
                entity_id := cast(u32)id_node._number.int_value;

                found_handle: Entity_Handle;
                for new_entity_handles {
                    if it.on_disk == entity_id {
                        found_handle = it.live;
                        break;
                    }
                }
                assert(found_handle.id != 0, "could not find a handle for entity_id %", entity_id);

                component_bit := get_component_bit_for_name(class_name);
                component_ti := component_bit_to_ti(component_bit);

                component_ptr := add_component(found_handle, component_ti);


                wbml.write_value(value, component_ptr, component_ti, class_name,
                    on_deserialize=on_component_deserialize, userdata=*new_entity_handles); // , verbose=true);
        }
    }



}

get_component_bit_for_name :: (name: string) -> Component_Bit {
    ti := type_info(Component_Bit);
    for ti.names
        if it == name
            return cast(Component_Bit)ti.values[it_index];
    
    assert(false, tprint("No Component bit for name '%'", name));
    return 0;
}

reset_world :: (world: *World) {
    reset(*world.entities);

    for bit_s64: type_info(Component_Bit).values {
        component_bit := cast(Component_Bit)bit_s64;
        #insert #run runtime_bit_bucket_chooser(#string END
            reset(bucket);
        END);
    }
}

save_prefab :: (filename: string) {
    // Currently just writing out the denormalized data...not the most
    // human-readable thing, though. Maybe that's...ok? I know trying
    // to eyeball Unity YAML merges is a nightmare because it's a bit
    // incomprehensible.

    sb: String_Builder;
    defer free_buffers(*sb);

    for handles(*context.state.world.entities) {
        ok, entity := get_entity(it);
        assert(ok);

        // TODO merge this wbml.serialize call with the one below.
        // really we just want to serialize all the buckets!

        ti := cast(*Type_Info_Struct)type_info(type_of(<<entity));

        //
        // TODO: I'm not sure that using this on_serialize function to add the 'id' field to
        // entities is a good idea. We know that at the top level, we want entities to have
        // an extra 'id' thing. Maybe serialize() should take an extra set of things and that's it?
        // Then we don't pay the cost for each node.
        //

        wbml.serialize_with_type_info(ti.name, entity, ti, *sb, on_serialize=component_on_serialize);
    }

    for bit_s64: type_info(Component_Bit).values {
        component_bit := cast(Component_Bit)bit_s64;
        #insert #run runtime_bit_bucket_chooser(#string END
            for * bucket {
                ti := cast(*Type_Info_Struct)type_info(type_of(<<it));
                wbml.serialize_with_type_info(ti.name, it, ti, *sb,
                    on_serialize=component_on_serialize, debug_name=ti.name);
            }
        END);
    }
    
    File.write_entire_file(filename, builder_to_string(*sb));
}

get_component_in_entity_named :: (entity_name: string, $component_type: Type) -> *component_type {
    for handles(*context.state.world.entities) {
        ok, entity := get_entity(it);
        assert(ok);
        if entity.name == entity_name
            return get_component(entity, component_type);
    }

    return null;
}

spawn_prefab :: (name: string, world_pos: rl.Vector2) -> (*Entity, Entity_Handle) {
    entity, entity_handle := spawn_prefab(name, v3(world_pos));
    return entity, entity_handle;
}

spawn_prefab :: (name: string, world_pos: Vector3 = Vector3.{0, 0, 0}) -> (*Entity, Entity_Handle) {
    VERBOSE :: true;
    filename := tprint("prefabs/%.wbml", name);
    prefab_cache_entry := get_prefab_cache_entry(filename);

    // make the entitty
    // TODO: need to actually use the entity_id paramenter here, or get rid of it.
    entity, entity_handle := create_entity(*context.state.world, prefab_cache_entry.entity_name, prefab_cache_entry.entity_id);

    transform := get_transform(entity);
    assert(transform != null);

    if prefab_cache_entry.transform_node
        wbml.write_value(prefab_cache_entry.transform_node, transform);

    transform.position = world_pos;

    for prefab_cache_entry.components {
        component_type_name := it.component_type_name;
        component_ti := get_component_ti_from_name(component_type_name);
        comp := add_or_get_component(entity_handle, component_ti);
        assert(comp != null);

        // here we use the runtime type info to dynamically poke bits into the
        // struct, which we don't know the layout of at compile time.
        // (now that I know more, the above statement is not entirely true)
        // TODO: (or do we??? in a non-development build???)

        wbml.write_value(it.object_node, comp, component_ti, component_type_name);

        for it.object_node._object.fields {
            assert(it.value != null);

            KEY :: "sprite_anim";

            if it.name == KEY {
                assert(it.value.type == .String);
                assert(it.value._string.count > 0, tprint("node object string for 'sprite_anim' has empty string"));

                asset_path := tprint("resources/sprites/%.aseprite", it.value._string);

                field := get_field(component_ti, KEY);
                assert(field != null);
                live_sprite_ptr := cast(*LiveSprite)(cast(*u8)comp + field.offset_in_bytes);

                was_new: bool;
                <<live_sprite_ptr, was_new = LoadLiveSprite(asset_path);
            }
        }

    }

    return entity, entity_handle;
}

#scope_file

#import "Basic";
File :: #import "File";
wbml :: #import "wbml";
laas :: #import "laas";
String :: #import "String";
Undo :: #import "undo";
rl :: #import "raylib";
Vector3 :: rl.Vector3;

#import "live_raylib";

#import "Array_With_Holes";
