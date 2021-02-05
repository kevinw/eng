// goals

// be able to sketch an entity real fast without making a new file; so ideally it could just start
// as a struct with optional methods
// then move it to a module when you want to "solidify" it

// some inspiration maybe: https://github.com/skypjack/entt/wiki/Crash-Course:-entity-component-system

#placeholder all_component_types;
#placeholder Component_Bit;

get_all_component_types :: () -> []Type {
    return all_component_types;
}

get_sorted_component_type_infos :: () -> []*Type_Info_Struct {
    all_components: [..]*Type_Info_Struct;
    for Compiler.get_type_table() {
        if Compiler.is_subclass_of(it, "Component") { // TODO: don't do this lookup by name
            ti_struct := cast(*Type_Info_Struct)it;
            array_add(*all_components, ti_struct);
        }
    }

    Sort :: #import "Sort";

    // We need to sort the component names, since the compiler does not find them
    // in a determinate order.
    Sort.quick_sort(all_components, (a, b) => Sort.compare_strings(a.name, b.name));

    return all_components;
}

// declare a list of all component type infos
#insert #run (() -> string {
    Compiler :: #import "Compiler";
    all_components := get_sorted_component_type_infos();

    sb: String_Builder;
    defer free_buffers(*sb);
    p :: print_to_builder;
    p(*sb, "#scope_export; all_component_types :: Type.[\n");
    for all_components
        p(*sb, "    %,\n", it.name);
    p(*sb, "];\n");

    // each component gets a bit.
    p(*sb, "Component_Bit :: enum_flags {\n");
    for all_components
        p(*sb, "    % :: (1 << %);\n", it.name, it_index);
    p(*sb, "}\n");


    return builder_to_string(*sb, __temporary_allocator);
}());

component_ti_to_bit :: (component_ti: *Type_Info_Struct) -> Component_Bit {
    #insert #run (() -> string {
        all_components := get_sorted_component_type_infos();

        sb: String_Builder;
        print_to_builder(*sb, "    if component_ti.name == {\n");
        for all_components
            print_to_builder(*sb, "        case \"%\"; return Component_Bit.%;\n", it.name, it.name);
        print_to_builder(*sb, "    }\n");
        return builder_to_string(*sb);
    }());
}

component_bit_to_ti :: (bit: Component_Bit) -> *Type_Info_Struct {
    #insert #run (() -> string {
        all_components := get_sorted_component_type_infos();

        sb: String_Builder;
        print_to_builder(*sb, "    if bit == {\n");
        for all_components
            print_to_builder(*sb, "        case .%; return type_info(%);\n", it.name, it.name);
        print_to_builder(*sb, "    }\n");
        return builder_to_string(*sb);
    }());

    assert(false, "unknown component bit % given to component_bit_to_ti (had %)", bit);
    return null;
}

get_component_ti_from_name :: (name: string) -> *Type_Info_Struct {
    #insert #run (() -> string {
        cases := foreach_component_type(#string END
            case "<type>"; return type_info(<type>);
        END);
        name_switch_code_str := tprint("if name == {\n%}\n", cases);
        return name_switch_code_str;
    }());

    assert(false, "no component named %", name);
    return null;
}

bucket_chooser :: () -> string {
    sb: String_Builder;
    sb.allocator = __temporary_allocator;
    for get_all_component_types()
        print_to_builder(*sb, "#if component_type == % bucket = *context.state.world._%;\n", it, it);
    return builder_to_string(*sb, __temporary_allocator);
}

foreach_component_type :: (inner_code_string: string) -> string {
    sb: String_Builder;
    defer free_buffers(*sb);
    for get_all_component_types() {
        replaced := String.replace(inner_code_string, "<type>", tprint("%", it)); // @Leak compile-time
        defer free(replaced);

        print_to_builder(*sb, "%\n", replaced);
    }
    return builder_to_string(*sb, __temporary_allocator);
}

runtime_bit_bucket_chooser :: (inner_code_string: string) -> string {
    sb: String_Builder;
    defer free_buffers(*sb);

    print_to_builder(*sb, "if component_bit == {\n");
    for get_all_component_types() {
        print_to_builder(*sb, "    case .%;\n", it);
        print_to_builder(*sb, "        bucket := *context.state.world._%;\n", it);
        print_to_builder(*sb, "        Bucket_Value_Type :: %;\n", it);
        print_to_builder(*sb, "        %\n", inner_code_string);
    }

    print_to_builder(*sb, "    case; assert(false, \"unknown component bit\");\n");
    print_to_builder(*sb, "}\n");

    return builder_to_string(*sb);
}

runtime_bucket_chooser :: (inner_code_string: string) -> string {
    sb: String_Builder;
    defer free_buffers(*sb);

    for get_all_component_types() {
        print_to_builder(*sb, "if component_ti == type_info(%) {\n", it);
        print_to_builder(*sb, "    bucket := *context.state.world._%;\n", it);
        print_to_builder(*sb, "    %\n", inner_code_string);
        print_to_builder(*sb, "}\n");
    }

    return builder_to_string(*sb);
}

_return_component_array_add :: (insert_run_on_enable: bool) -> string {
    sb: String_Builder;
    defer free_buffers(*sb);

    for get_all_component_types() {
        maybe_else := ifx it_index > 0 then "else " else "";
        print_to_builder(*sb, "%if component_ti.name == \"%\" {\n", maybe_else, it);
        print_to_builder(*sb, "    ptr: *%;\n", it);
        print_to_builder(*sb, "    component_handle, ptr = allocate_slot(*context.state.world._%, undo=undo);\n", it);
        print_to_builder(*sb, "    component_type_info = type_info(%);\n", it);
        print_to_builder(*sb, "    ptr.entity = entity_handle;\n");
        if insert_run_on_enable
            print_to_builder(*sb, "    run_on_enable(ptr, entity);\n", it);
        print_to_builder(*sb, "    c = ptr;\n", it);
        print_to_builder(*sb, "}\n", it);
    }

    return builder_to_string(*sb);
}

#scope_file
String :: #import "String";
Compiler :: #import "Compiler";
