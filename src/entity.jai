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

#load "components/camera.jai";
#load "components/sprite_renderer.jai";
#load "components/box_collider.jai";
#load "components/rect_renderer.jai";
#load "components/enemy.jai";
#load "components/player.jai";
#load "components/shape_renderer.jai";
#load "components/pong_paddle.jai";
#load "components/pong_components.jai";
#load "components/transform_test_components.jai";
#load "components/editor_selectable_rect.jai";
#load "components/follow.jai";
#load "components/Simple_Image_Renderer.jai";

Transform :: struct {
    using component: Component;

    position: rl.Vector3    = .{0, 0, 0};
    rotation: rl.Quaternion = .{0, 0, 0, 1};
    scale:    rl.Vector3    = .{1, 1, 1};
}

Link :: struct {
    using component: Component;

    parent: Entity_Handle;
}

TRS :: Transform; // an alias until Raylib is entirely gone

#load "entity_meta.jai"; // contains compile-time Entity infrastructure code.

get_entity :: (entity_handle: Entity_Handle) -> (bool, *Entity) {
    if entity_handle.id == 0 return false, null; // TODO: not sure if this should be down in get_item_ptr

    entity := get_item_ptr(*context.state.world.entities, entity_handle);
    return entity != null, entity;
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
    prefab_filename: string; @free_in_deinit

    Component_Entry :: struct {
        component_handle: Handle_Type;
        bit: Component_Bit;
    }

    // TODO: Small_Array here could be a big win
    components: [..]Component_Entry;  @noserialize
}

find_component :: ($component_type: Type) -> *component_type {
    bucket: *Array_With_Holes(component_type);
    #insert #run bucket_chooser();
    for * bucket return it;
    return null;
}

get_components :: ($component_type: Type) -> []*component_type {
    all: [..]*component_type;
    all.allocator = __temporary_allocator;

    bucket: *Array_With_Holes(component_type);
    #insert #run bucket_chooser();
    for * bucket array_add(*all, it);

    return all;
}

get_component :: (entity_handle: Entity_Handle, component_ti: *Type_Info_Struct) -> *Component {
    ok, entity := get_entity(entity_handle);
    if !ok return null;

    return get_component(entity, component_ti);
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


Entity_Handle :: Handle_Type;

World :: struct {
    canary1 := 101;
    entities: Array_With_Holes(Entity);
    #insert #run (() -> string {
        return buf_string((sb: *String_Builder) {
            for all_component_types
            print_to_builder(sb, "_%: Array_With_Holes(%);\n", it, it);
        });
    }());

    canary2 := 999;

    prefab_cache: [..]Prefab_Cache_Entry;

    defaults_nodes: [..]*wbml.Node; // in component order

    deinit :: (world: *World) {
    }
};

Prefab_Cache_Entry :: struct {
    filename: string;
    components: [..]struct {
        component_bit: Component_Bit;
        object_node:   *wbml.Node;
    };
}

init_world :: (world: *World) {
    init_array_with_holes(*world.entities, "all-entities");
    #insert #run(() -> string {
        return buf_string((sb: *String_Builder) {
            for all_component_types {
                print_to_builder(sb, "init_array_with_holes(*context.state.world._%, \"all-%\");\n", it, it);
            }
        });
    }());

    // Here we create empty stack variables for each component type, and then
    // serialize them into in-memory WBML nodes. This will give us ndoes to
    // use as "prototype" objects for when we're writing out WBML, so that
    // we don't serialize defaults.
    #insert #run foreach_component_type(#string END
        {
            component_on_stack: <type>;
            defaults_node := wbml.get_defaults_node(*component_on_stack, component_on_serialize);
            assert(defaults_node != null);
            default_obj_str := wbml.node_object_to_string(*defaults_node._object);
            File.write_entire_file(
                tprint("temp/%.wbml", <type>),
                default_obj_str);

            array_add(*world.defaults_nodes, defaults_node);
        }
    END);
}

get_defaults_node_for_component_bit :: (world: *World, component_bit: Component_Bit) -> *wbml.Node {
    index := -1;
    for type_info(Component_Bit).values {
        if component_bit == cast(Component_Bit)it
            index = it_index;
    }

    assert(index != -1);

    return world.defaults_nodes[index];
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

create_entity :: (world: *World = null, name: string = "",
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
    component_ptr := get_component(entity_handle, component_ti);
    if component_ptr != null return component_ptr;

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

//
// Return a heap allocated block of memory that we can use as a source of the
// #initializer_of defaults from Component subclass code.
//
alloc_component_defaults :: (component_ti: *Type_Info_Struct) -> Any {
    #insert #run runtime_bucket_chooser(#string END
        any: Any;
        any.value_pointer = New(bucket.Value_Type, initialized=true);
        any.type = type_info(bucket.Value_Type);

        return any;
    END);

    assert(false, tprint(
        "alloc_component_defaults did not find a component for the given Type_Info_Struct %",
        component_ti));
    return null;
}

component_on_serialize :: (any: *Any, added_fields: *[..]wbml.Added_Field_Entry) {
    if added_fields != null {
        if any.type == type_info(Entity) {
            // I don't like this at all. Maybe we need a "possibly-local" Any?
            // Or maybe the temporary allocator here is good enough.
            my_int  := cast(*int)talloc(size_of(int));

            // I don't like this either. Above us, when we're iterating over
            // the entities bucket, we definitely already know the entity id.
            // This feels like the wrong place to be looking it up again.
            <<my_int = get_entity_handle((cast(*Entity)any.value_pointer)).id;

            entry := array_add(added_fields);
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
        
        heap_string := New(string); // @Leak
        if has_value(<<live_sprite) {
            <<heap_string = copy_string(get_asset_name(live_sprite.filename)); // @Leak
        }

        any.value_pointer = heap_string;
    }
}


Entity_Handle_Map_Entry :: struct {
    live: Entity_Handle;
    on_disk: u32;
}

Entity_Handle_Map :: [..]Entity_Handle_Map_Entry;

on_component_deserialize :: (any: *Any, node: *wbml.Node, userdata: *void) -> (handled: bool) {
    assert(any != null);

    if any.type.type == .STRUCT {
        if any.type == type_info(Entity_Handle) {
            // here we're remapping entity ids since the ones stored on disk
            // will almost certainly be different than the ones in memory.
            handle_ptr := cast(*Entity_Handle)any.value_pointer;

            number_node := wbml.get(node, "id", .Number, do_remove=false);
            assert(number_node != null, "expected node id for an Entity_Handle.id to have a number");
            wbml_entity_id := number_node._number.int_value;

            assert(userdata != null);
            for <<cast(*Entity_Handle_Map)userdata {
                print("  % vs %\n", it.on_disk, wbml_entity_id);
                if it.on_disk == wbml_entity_id {
                    <<handle_ptr = it.live;
                    return true;
                }
            }
            print("WARNING: handle could not be remapped: %\n", <<handle_ptr);
        } else if any.type == type_info(SpriteRenderer) {
            filename := wbml.get(node, "sprite_anim", .String);
            if filename != null && filename._string.count > 0 {
                //print("on_component_deserialize sprite_anim filename is %\n", filename._string);

                field := get_field(cast(*Type_Info_Struct)any.type, "sprite_anim");
                assert(field != null);
                live_sprite_ptr := cast(*LiveSprite)(cast(*u8)any.value_pointer + field.offset_in_bytes);
                
                was_new: bool;
                asset_path := tprint("resources/sprites/%.aseprite", filename._string); // TODO: move this path lookup elsewhere
                <<live_sprite_ptr, was_new = LoadLiveSprite(asset_path);
            }
        }
    }

    return false;
}

load_world :: (world: *World, wbml_string: string, filename: string, create_transform := false, save_in_cache := false) -> [..]Entity_Handle {
    lexer := laas.make_lexer(wbml_string);

    new_entity_handles: Entity_Handle_Map;
    defer array_free(new_entity_handles);
    prefab_cache_entry: *Prefab_Cache_Entry;

    if save_in_cache {
        for world.prefab_cache {
            if it.filename == filename {
                // don't need to save again if we've already got the thing in cache
                save_in_cache = false;
                break;
            }
        }
    }

    while true {
        while laas.is_token(*lexer, .New_Line) laas.eat(*lexer);

        name_token, name_ok := laas.expect(*lexer, .Identifier);
        if !name_ok break;

        // TODO: nocheckin ensure we've parsed the whole text here.
        class_name := copy_string(name_token.text); // @Leak

        value := wbml.parse_value(*lexer);
        assert(value.type == .Object);


        if class_name == {
            case "Entity";
                prefab_filename: string;
                {
                    prefab_filename_val := wbml.get(value, "prefab_filename", .String, do_remove=true);
                    if prefab_filename_val != null {
                        defer wbml.delete_node(prefab_filename_val);
                        if prefab_filename_val._string.count > 0 {
                            print("entity has prefab link: %\n", prefab_filename_val._string);
                            prefab_filename = tprint("%", prefab_filename_val._string);
                        }
                    }
                }

                entity_id := cast(s32)wbml.get(value, "id", .Number)._number.int_value;
                assert(entity_id != 0);

                entity_name: string;
                string_node := wbml.get(value, "name", .String);
                if string_node != null {
                    entity_name = copy_string(string_node._string); // @Leak
                } else {
                    entity_name = copy_string("unnamed"); // @Leak
                }


                new_entity_ptr: *Entity;
                new_entity_handle: Entity_Handle;
                if prefab_filename.count > 0 {
                    new_entity_ptr, new_entity_handle = spawn_prefab_from_filename(prefab_filename);
                    new_entity_ptr.name = entity_name;
                } else {
                    new_entity_ptr, new_entity_handle = create_entity(world, entity_name, create_transform_component=create_transform);
                }
                wbml.write_value(value, new_entity_ptr, "Entity");

                // TODO: this should just be done by the write_value above.
                // it requires changing the wbml.get for prefab_filename to
                // do_remove=false
                if prefab_filename.count > 0 
                    new_entity_ptr.prefab_filename = copy_string(prefab_filename);

                entry := array_add(*new_entity_handles);
                entry.live = new_entity_handle;
                entry.on_disk = cast(u32)entity_id;

                prefab_cache_entry = null;
                if save_in_cache {
                    prefab_cache_entry = array_add(*world.prefab_cache);
                    prefab_cache_entry.filename = copy_string(filename);
                    print("added new prefab cache entry for '%'\n", filename);
                }
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
                component_ptr := add_or_get_component(found_handle, component_ti);

                if save_in_cache && prefab_cache_entry != null {
                    entry := array_add(*prefab_cache_entry.components);
                    entry.component_bit = component_bit;
                    entry.object_node = wbml.deep_copy(value);
                    entry.object_node._object.prototype = *get_defaults_node_for_component_bit(world, component_bit)._object;
                }

                assert(value.type == .Object);
                wbml.write_value(value, component_ptr, component_ti, class_name,
                    on_deserialize=on_component_deserialize, userdata=*new_entity_handles);
        }
    }


    handles: [..]Entity_Handle;
    for new_entity_handles array_add(*handles, it.live);
    return handles;
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

save_prefab :: (filename: string, entity_selection: *Entity_Handle = null) {
    // Currently just writing out the denormalized data...not the most
    // human-readable thing, though. Maybe that's...ok? I know trying
    // to eyeball Unity YAML merges is a nightmare because it's a bit
    // incomprehensible.

    world := *context.state.world;

    sb: String_Builder;
    defer free_buffers(*sb);

    for handles(*world.entities) {
        ok, entity := get_entity(it);
        assert(ok);

        if entity_selection != null && it != <<entity_selection
            continue;

        // TODO merge this wbml.serialize call with the one below.
        // really we just want to serialize all the buckets!
        ti := cast(*Type_Info_Struct)type_info(type_of(<<entity));

        entity_defaults: Entity;
        if entity.prefab_filename.count > 0 {
            //here's the hard work. where do we "fake instantiate"
            //the prefab to see its defaults? they should maybe already be in memory
            //from spawn_prefab. maybe each entity could keep a pointer to a WBML node that
            //has its prefab defaults? then here we could write that node to the default object here...

            //note! we already have the prefab cache.
        }

        // TODO: I'm not sure that using this on_serialize function to add the 'id' field to
        // entities is a good idea. We know that at the top level, we want entities to have
        // an extra 'id' thing. Maybe serialize() should take an extra set of things and that's it?
        // Then we don't pay the cost for each node. @Speed
        wbml.serialize_with_type_info(ti.name, entity, ti, *sb,
            on_serialize=component_on_serialize, default=null);
    }

    for bit_s64: type_info(Component_Bit).values {
        component_bit := cast(Component_Bit)bit_s64;
        #insert #run runtime_bit_bucket_chooser(#string END
            for handles(bucket) {
                component_ptr := get_item_ptr(bucket, it);
                if entity_selection != null && component_ptr.entity != <<entity_selection
                    continue;

                ti := cast(*Type_Info_Struct)type_info(type_of(<<component_ptr));
                component_bit := get_component_bit_for_name(ti.name);

                // If we have a prefab cache entry from the entity's prefab link above,
                // we fill in the "defaults" object that we pass to wbml, so that only
                // actual changes compared to the parent prefab are written.

                defaults_node: *wbml.Node;

                ok, my_ent := get_entity(component_ptr.entity);
                assert(ok);
                print("serializing %.% (prefab_filename=%)\n", my_ent.name, component_bit, my_ent.prefab_filename);

                if my_ent.prefab_filename.count > 0 {
                    for * world.prefab_cache {
                        if it.filename == my_ent.prefab_filename { // @Slow @Speed
                            print("found cache entry for %\n", it.filename);
                            for * it.components {
                                if it.component_bit == component_bit {
                                    assert(it.object_node != null);
                                    defaults_node = it.object_node;
                                }
                            }
                            if defaults_node == null {
                                defaults_node = get_defaults_node_for_component_bit(world, component_bit);
                            }
                        }
                    }
                    if defaults_node == null {
                        logprint("ent", "error: no cache entry for %", my_ent.prefab_filename);
                    }
                }

                wbml.serialize_with_type_info(ti.name, component_ptr, ti, *sb,
                    on_serialize=component_on_serialize, debug_name=ti.name, default=defaults_node);
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

spawn_prefab :: (prefab_name: string, world_pos: rl.Vector2) -> (*Entity, Entity_Handle) {
    entity, entity_handle := spawn_prefab(prefab_name, v3(world_pos));
    return entity, entity_handle;
}

spawn_prefab :: (prefab_name: string, world_pos: Vector3 = Vector3.{0, 0, 0}) -> (*Entity, Entity_Handle) {
    assert(prefab_name.count > 0, "cannot pass an empty string to spawn_prefab");
    filename := tprint("prefabs/%.wbml", prefab_name);
    entity, entity_handle := spawn_prefab_from_filename(filename, world_pos);
    return entity, entity_handle;
}

spawn_prefab_from_filename :: (filename: string, world_pos: Vector3=.{}) -> (*Entity, Entity_Handle) {
    entity_file_text, ok := File.read_entire_file(filename);
    if !ok {
        logprint("error", "no prefab at %", filename);
        return null, .{};
    }
    defer free(entity_file_text);
    print("read % bytes from '%'\n", entity_file_text.count, filename);

    new_handles := load_world(*context.state.world, entity_file_text, filename, create_transform=true, save_in_cache=true);
    assert(new_handles.count == 1, tprint("expecting exactly one handle from a prefab file, got %: %", new_handles.count, filename));

    e_ok, entity := get_entity(new_handles[0]);
    assert(e_ok);

    trs := get_transform(entity);
    if trs != null {
        trs.position = world_pos;
    }

    return entity, new_handles[0];
}

#scope_file

#import "Basic";
File :: #import "File";
wbml :: #import "wbml";
laas :: #import "laas";
Undo :: #import "undo";
rl :: #import "raylib";
Vector3 :: rl.Vector3;
Debug :: #import "Debug";

#import "live_raylib";

#import "Array_With_Holes";
