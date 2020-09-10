// TODO: generate these imports
#load "components/sprite_renderer.jai";
#load "components/box_collider.jai";
#load "components/rect_renderer.jai";
#load "components/enemy.jai";

// goals

// be able to sketch an entity real fast without making a new file; so ideally it could just start
// as a struct with optional methods
// then move it to a module when you want to "solidify" it

// some inspiration maybe: https://github.com/skypjack/entt/wiki/Crash-Course:-entity-component-system

all_component_types :: Type.[
    SpriteRenderer,
    BoxCollider,
    RectRenderer,
    Enemy,
];

get_entity :: (entity_handle: Entity_Handle) -> (bool, *Entity) {
    entity := get_item_ptr(*context.state.world.entities, entity_handle);
    return entity != null, entity;
}

get_component_ti_from_name :: (name: string) -> *Type_Info_Struct {
    #insert #run foreach_component_type(#string END
        if name == "<type>" return type_info(<type>);
    END);

    assert(false, tprint("no component named %", name));
    return null;
}

Component :: struct {
    entity: Entity_Handle;
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
    _world: *World;
    flags: Flags;

    Component_Entry :: struct {
        component_handle: Handle_Type;
        type_name: string; // TODO. maybe a bit?
    }

    components: [..]Component_Entry; // TODO: Small_Array
}

get_component :: (entity: *Entity, $component_type: Type) -> *component_type {
    #assert(type_info(component_type).type == .STRUCT);

    assert(entity != null);

    ti_struct := cast(*Type_Info_Struct)type_info(component_type);
    for * entity.components {
        if it.type_name == ti_struct.name {
            sibling_handle := it.component_handle;

            bucket: *Array_With_Holes(component_type);
            #insert #run bucket_chooser();

            assert(bucket != null);
            sibling_ptr := get_item_ptr(bucket, sibling_handle);
            if sibling_ptr != null
            return sibling_ptr;
        }
    }

    return null;
}

entity_rect :: (entity_handle: Entity_Handle) -> Rectangle {
    ok, entity := get_entity(entity_handle);

    if ok
    return entity_rect(entity);
    else
    return .{};
}

entity_rect :: (entity: *Entity, verbose := false) -> Rectangle {
    if entity.flags & .Has_Component_Rect {
        spr := get_component(entity, SpriteRenderer);
        if spr != null {
            assert(spr.canary == 42);
            ok, rect := get_entity_rect(spr);
            if ok return rect;
        }
    }

    pos := entity.position.xy;
    sz := entity.scale.xy;
    return make_Rectangle(pos.x, pos.y, sz.x, sz.y);
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
            print_to_builder(sb, "    component_handle, ptr = allocate_slot(*context.state.world._%);\n", it);
            print_to_builder(sb, "    component_type_info = type_info(%);\n", it);
            print_to_builder(sb, "    on_enable(ptr, entity);\n", it);
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
    entities: Array_With_Holes(Entity);
    #insert #run get_component_buckets();

    prefab_cache: Prefab_Cache;

    deinit :: (using world: *World) {
        Prefab_Cache.deinit(*prefab_cache);
    }
};

init_world :: (world: *World) {
    init_array_with_holes(*world.entities);
    #insert #run(() -> string {
        return buf_string((sb: *String_Builder) {
            for all_component_types {
                print_to_builder(sb, "init_array_with_holes(*context.state.world._%);\n", it);
            }
        });
    }());
}

world_update :: (world: *World, delta_time: float) {
    for * world._SpriteRenderer update(it);
    enemy_update_all();
}

world_draw :: (world: *World) {
    for * world._RectRenderer {
        color2 := it.color;
        color2.r -= 100; color2.g -= 100; color2.b -= 100;
        DrawRectangleGradientEx(entity_rect(it.entity), it.color, color2, color2, it.color);
    }

    for * world._SpriteRenderer {
        // TODO: here we need to pass the transform as well.
        // perhaps we note functions like draw which require
        // multiple entities, and store relative pointers to them somewhere?
        //
        // research the concept of systems. this is really about
        // desigining a database and might be overkill for now.
        ok, entity := get_entity(it.entity);
        assert(ok);
        draw(it, *entity.transform);
    }

    for * world._Enemy {
        ok, entity := get_entity(it.entity);
        assert(ok);
        draw(it, *entity.transform);
    }
}

create_entity :: (world: *World, name: string = "", id: s32 = -1) -> *Entity, Entity_Handle {
    assert(world != null);

    handle, e := allocate_slot(*world.entities);
    e._world = world;

    //print("create_entity -> %\n", e);
    return e, handle;
}

destroy_entity :: (e: Entity_Handle) {
    other_e := e;
    assert(other_e.id == e.id);

    entity := get_item_ptr(*context.state.world.entities, e);
    assert(other_e.id == e.id);
    for entity.components {
        component_ti := get_component_ti_from_name(it.type_name);
        free(it.type_name);
        component_handle := it.component_handle;
        {
            #insert #run runtime_bucket_chooser(#string END
                assert(other_e.id == e.id);
                did_delete := delete_item(bucket, component_handle);

                //assert(other_e.id == e.id); // TODO: @CompilerBug

                // The above line fails.
                // It does nothing with the argument e to this function, so it
                // appears to be a codegen bug.

                assert(did_delete);
            END);
        }
    }
    array_reset(*entity.components);
    delete_item(*context.state.world.entities, other_e);
}

add_or_get_component :: (entity_handle: Entity_Handle, component_ti: *Type_Info_Struct) -> *Component {
    return add_component(entity_handle, component_ti);
}

add_component :: (entity_handle: Entity_Handle, component_ti: *Type_Info_Struct) -> *Component {
    ok, entity := get_entity(entity_handle);
    assert(ok);

    c: *Component;
    component_type_info: *Type_Info_Struct;
    component_handle: Handle_Type;

    #insert #run _return_component_array_add();
    assert(component_type_info != null);
    assert(component_handle.id != 0);

    entry := array_add(*entity.components);
    entry.type_name = copy_string(component_type_info.name);
    entry.component_handle = component_handle;

    assert(c != null);
    c.entity = entity_handle;
    return c;
}

add_component :: (entity_handle: Entity_Handle, $component_type: Type) -> *component_type {
    bucket: *Array_With_Holes(component_type);
    #insert #run bucket_chooser();

    component_handle, component_ptr := allocate_slot(bucket);
    c := cast(*component_type)component_ptr;

    ok, entity := get_entity(entity_handle);
    assert(ok);

    entry := array_add(*entity.components);
    entry.type_name = copy_string((cast(*Type_Info_Struct)type_info(component_type)).name); // @Leak
    entry.component_handle = component_handle;

    c.entity = entity_handle;
    on_enable(c, entity);

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
    }

    entries: [..]Entry;

    deinit :: (using self: *Prefab_Cache) { // TODO: autogen this function from @owned
        for entries {
            for it.components {
                free(it.component_type_name);
                wbml.delete_node(it.object_node);
            }
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
    print("read % bytes from '%'", entity_file_text.count, filename);

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

        ti := get_component_ti_from_name(component_name_ident.text);

        component_cache_entry := array_add(*cache_entry.components);
        component_cache_entry.component_type_name = copy_string(ti.name);

        value := wbml.parse_value(*lexer);
        assert(value != null, "could not parse value as wbml");
        assert(value.type == .Object);
        component_cache_entry.object_node = value;
    }

    ptr := array_add(*context.state.world.prefab_cache.entries);
    <<ptr = cache_entry;
    return ptr;
}

spawn_prefab :: (name: string, world_pos: Vector3) -> *Entity {
    filename := tprint("prefabs/%.wbml", name);
    prefab_cache_entry := get_prefab_cache_entry(filename);

    // make the entitty
    // TODO: need to actually use the entity_id paramenter here, or get rid of it.

    entity, entity_handle := create_entity(*context.state.world, prefab_cache_entry.entity_name, prefab_cache_entry.entity_id);
    entity.transform.position = world_pos;

    for prefab_cache_entry.components {
        component_type_name := it.component_type_name;
        component_ti := get_component_ti_from_name(component_type_name);
        comp := add_or_get_component(entity_handle, component_ti);

        // here we use the runtime type info to dynamically poke bits into the
        // struct, which we don't know the layout of at compile time.
        // TODO: (or do we??? in a non-development build???)
        for it.object_node._object.fields {
            assert(it.value != null);

            if it.name == "sprite_anim" {
                asset_path := tprint("resources/sprites/%.aseprite", it.value._string.value);

                field := get_field(component_ti, "sprite_anim");
                assert(field != null);
                live_sprite_ptr := cast(*LiveSprite)(cast(*u8)comp + field.offset_in_bytes);

                was_new: bool;
                <<live_sprite_ptr, was_new = LoadLiveSprite(asset_path);
            }
        }

        wbml.write_value(it.object_node, comp, component_ti);
    }

    return entity;
}

#scope_file

#import "Basic";
#import "raylib";

File :: #import "File";
wbml :: #import "wbml";
laas :: #import "laas";
String :: #import "String";

#import "live_raylib";

#import "Array_With_Holes";
