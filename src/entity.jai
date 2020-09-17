#module_parameters(GAME_NAME := "");
#assert(GAME_NAME.count > 0);

#if GAME_NAME == "beat_platformer" {
    #load "components/sprite_renderer.jai";
    #load "components/box_collider.jai";
    #load "components/rect_renderer.jai";
    #load "components/enemy.jai";
    #load "components/player.jai";
}
#if GAME_NAME == "pong" {
    #load "components/sprite_renderer.jai";
    #load "components/box_collider.jai";
    #load "components/rect_renderer.jai";
    #load "components/pong_paddle.jai";
}
#load "components/editor_selectable_rect.jai";

// goals

// be able to sketch an entity real fast without making a new file; so ideally it could just start
// as a struct with optional methods
// then move it to a module when you want to "solidify" it

// some inspiration maybe: https://github.com/skypjack/entt/wiki/Crash-Course:-entity-component-system

// declare a list of all component type infos
#insert #run (() -> string {
    sb: String_Builder;
    defer free_buffers(*sb);
    Compiler :: #import "Compiler";
    print_to_builder(*sb, "all_component_types :: Type.[\n");
    total := 0;
    for Compiler.get_type_table() {
        if Compiler.is_subclass_of(it, "Component") { // TODO: don't do this lookup by name
            ti_struct := cast(*Type_Info_Struct)it;
            print_to_builder(*sb, "    %,\n", ti_struct.name);
            total += 1;
        }
    }
    //print("num Components: %\n", total);
    print_to_builder(*sb, "];\n");
    return builder_to_string(*sb);
}());

get_transform :: (component: *Component) -> *Transform {
    ok, entity := get_entity(component.entity);
    assert(ok);
    return *entity.transform;
}

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
    position: Vector3 = Vector3.{0, 0, 0};
    scale: Vector3 = Vector3.{1, 1, 1};
    rotation: Quaternion = Vector4.{0, 0, 0, 1};
}

Entity :: struct {
    Flags :: enum_flags u16 {
        None               :: (0 << 0);
        Has_Component_Rect :: (1 << 0);
    }

    using transform: Transform;
    _world: *World;
    flags: Flags;
    name: string; @owned

    Component_Entry :: struct {
        component_handle: Handle_Type;
        type_name: string; // TODO. maybe a bit?
    }

    components: [..]Component_Entry; // TODO: Small_Array
}

get_components :: ($component_type: Type) -> []*component_type {
    all: [..]*component_type;
    all.allocator = __temporary_allocator;

    bucket: *Array_With_Holes(component_type);
    #insert #run bucket_chooser();
    for * bucket array_add(*all, it);

    return all;
}

get_component :: (component: *Component, $component_type: Type) -> *component_type {
    ok, entity := get_entity(component.entity);
    assert(ok);
    return get_component(entity, component_type);
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

get_component :: (entity: *Entity, component_ti: *Type_Info_Struct) -> *Component {
    assert(entity != null);

    for * entity.components {
        if it.type_name == component_ti.name {
            sibling_handle := it.component_handle;
            #insert #run runtime_bucket_chooser(#string END
                return get_item_ptr(bucket, sibling_handle);
            END);
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

operator + :: inline (rect: Rectangle, pos: Vector2) -> Rectangle {
    return make_Rectangle(rect.x + pos.x, rect.y + pos.y, rect.width, rect.height);
}


entity_rect :: (entity: *Entity, verbose := false) -> Rectangle {
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
            r := editor_selectable_rect.rect + entity.transform.position.xy;
            //logprint("editor", "entity rect % for %\n", r, entity);
            return r;
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
            print_to_builder(sb, "    ptr.entity = entity_handle;\n");
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
    #if GAME_NAME == "beat_platformer"
        for * world._Player player_update(it);
    for * world._SpriteRenderer update(it);
    #if GAME_NAME == "beat_platformer"
        enemy_update_all();
    #if GAME_NAME == "pong" {
        for * world._Pong_Paddle {
            update(it, get_transform(it), get_component(it, SpriteRenderer));
        }
    }
}

world_draw :: (world: *World = null) {
    if world == null
        world = *context.state.world;

    #if GAME_NAME == "beat_platformer"
        for * world._Player player_draw(it);

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

    #if GAME_NAME == "beat_platformer"
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

    e.name = copy_string_z(name);

    //print("create_entity -> %\n", e);
    return e, handle;
}

get_entity_handle :: (entity: *Entity) -> Entity_Handle {
    return get_handle_for_value_ptr(*context.state.world.entities, entity);
}

destroy_entity :: (entity_ptr: *Entity) {
    destroy_entity(get_entity_handle(entity_ptr));
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
    // c.entity = entity_handle; // this is seet in _return_component_array_add
    return c;
}

add_component :: (entity_handle: Entity_Handle, $component_type: Type) -> *component_type {
    ok, entity := get_entity(entity_handle);
    assert(ok);

    bucket: *Array_With_Holes(component_type);
    #insert #run bucket_chooser();

    component_handle, component_ptr := allocate_slot(bucket);
    c := cast(*component_type)component_ptr;

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

spawn_prefab :: (name: string, world_pos: Vector3 = Vector3.{0, 0, 0}) -> (*Entity, Entity_Handle) {
    VERBOSE :: true;
    filename := tprint("prefabs/%.wbml", name);
    prefab_cache_entry := get_prefab_cache_entry(filename);

    // make the entitty
    // TODO: need to actually use the entity_id paramenter here, or get rid of it.
    entity, entity_handle := create_entity(*context.state.world, prefab_cache_entry.entity_name, prefab_cache_entry.entity_id);

    if prefab_cache_entry.transform_node
        wbml.write_value(prefab_cache_entry.transform_node, *entity.transform);

    entity.transform.position = world_pos;

    for prefab_cache_entry.components {
        component_type_name := it.component_type_name;
        component_ti := get_component_ti_from_name(component_type_name);
        comp := add_or_get_component(entity_handle, component_ti);
        assert(comp != null);

        // here we use the runtime type info to dynamically poke bits into the
        // struct, which we don't know the layout of at compile time.
        // TODO: (or do we??? in a non-development build???)
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

        wbml.write_value(it.object_node, comp, component_ti, component_type_name);
    }

    return entity, entity_handle;
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
