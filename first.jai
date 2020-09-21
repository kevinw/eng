#scope_file

ENTITY_COMPONENT_SYSTEMS :: true;

#import "Basic";
#import "Compiler";
#import "Random";
String :: #import "String";
Reflection :: #import "Reflection";

module_search_paths := string.[
    "../jai-imgui",
    "../jai-raylib",
    "../jai-soloud",
    "lib",
    "src"
];

Build_Flags :: enum_flags {
    None       :: 0;
    Check_Only :: (1 << 0);
    Reload     :: (1 << 1);
}

#load "src/compiler_util.jai";
#load "src/metaprogram_common.jai";

build_plugin :: (build_flags: Build_Flags, game_dll_source_name: string, loc := #caller_location) {
    set_working_directory(#filepath);

    opts := get_build_options();
    opts.output_type = .NO_OUTPUT;
    set_build_options(opts);

    if String.count(game_dll_source_name, ".") > 0 {
        compiler_error(tprint("Error: no dots in source name please: '%'", game_dll_source_name), loc);
        return;
    }

    w := compiler_create_workspace("build");
    {
        compiler_begin_intercept(w);
        defer compiler_end_intercept(w);

        array_add(*opts.modules_search_path_array, ..module_search_paths);
        opts.output_type = .DYNAMIC_LIBRARY;

        if build_flags & .Check_Only
            opts.output_path = CHECK_PATH;

        if build_flags & .Reload {
            output_exe := tprint("%_reloaded_%", game_dll_source_name, random_get());
            print("reloading...changing DLL output to %\n", output_exe);
            opts.output_executable_name = output_exe;
        } else {
            opts.output_executable_name = game_dll_source_name;
        }
        set_build_options(opts, w);

        source_file := tprint("src/%.jai", game_dll_source_name);
        add_build_file(source_file, w);

        metaprogram: Metaprogram;
        metaprogram.workspace = w;

        while true {
            message := compiler_wait_for_message();
            if !message || message.workspace != w continue;

            #if ENTITY_COMPONENT_SYSTEMS {
                if message.kind == {
                    case .CODE_TYPECHECKED;
                        collect_component_functions(cast(*Compiler_Message_Code_Typechecked)message, *metaprogram);

                    case .COMPILATION_PHASE;
                        msg := cast(*Compiler_Message_Compilation_Phase)message;
                        if msg.phase == .ALL_SOURCE_CODE_THAT_CAN_CURRENTLY_BE_INFERRED_IS_INFERRED
                            generate_systems(*metaprogram);
                }
            }

            if message.kind == .COMPLETE {
                break;
            }
        }
    }
};

Metaprogram :: struct {
    workspace: s64;
    system_funcs: [..]*Code_Procedure_Header;
    component_type_names: [..]string; // TODO: should these be *Type_Infos?
}

build_host :: (check := false) {
    set_working_directory(#filepath);

    opts := get_build_options();
    opts.output_type = .NO_OUTPUT;
    set_build_options(opts);

    w := compiler_create_workspace("build");
    {
        compiler_begin_intercept(w);
        defer compiler_end_intercept(w);

        array_add(*opts.modules_search_path_array, ..module_search_paths);
        opts.output_type = .EXECUTABLE;
        if check opts.output_path = CHECK_PATH;
        set_build_options(opts, w);
        add_build_file("src/host.jai", w);

        while true {
            message := compiler_wait_for_message();
            if !message || message.workspace != w continue;
            if message.kind == .COMPLETE break;
        }
    }
};

is_argument_a_pointer_to_a_component :: (arg_decl: *Code_Declaration, metaprogram: *Metaprogram) -> (is_component: bool, component_name: string) {
    if arg_decl.type_inst == null return false, "";
    if arg_decl.type_inst.pointer_to == null return false, "";

    arg_type_ident := arg_decl.type_inst.pointer_to.type_valued_expression;
    if arg_type_ident == null return false, "";
    if arg_type_ident.kind != .IDENT return false, "";

    // TODO: should we compare pointers instead of type names here? yes. the answer is yes

    name := (cast(*Code_Ident)arg_type_ident).name;
    found, index := array_find(metaprogram.component_type_names, name);
    if found return true, metaprogram.component_type_names[index];
    
    else return false, name;
}

Temp_Resizable_Array :: inline ($T: Type) -> [..]T {
    arr: [..]T;
    arr.allocator = __temporary_allocator;
    return arr;
}

generate_systems :: (metaprogram: *Metaprogram) {
    system_count := 0;

    by_stage: [..]struct {
        stage: System_Stage;
        funcname: string;
        needs_entity_at_end: bool;
        component_names: []string;
    };
    by_stage.allocator = __temporary_allocator;

    for metaprogram.system_funcs {
        assert(it.body_or_null != null && it.arguments.count > 0);

        needs_entity_at_end := false; // TODO: this is a hack. maybe find a different way...
        component_names: [..]string;
        all_were_components := true;
        for it.arguments {
            is_component, component_name := is_argument_a_pointer_to_a_component(it, metaprogram);
            if !is_component {
                if component_name == "Entity" {
                    needs_entity_at_end = true;
                    continue;
                } else {
                    all_were_components = false;
                    break;
                }
            }
            array_add(*component_names, component_name);
        }

        if !all_were_components
            continue;

        arg_names := Temp_Resizable_Array(string);

        internal_system_func_name := tprint("_sys_%_%_%", system_count, it.name, String.join(..component_names, separator="_"));
        system_count += 1;

        for component_names
            array_add(*arg_names, tprint("component_%", it_index));
        if needs_entity_at_end
            array_add(*arg_names, "entity_ptr");

        stage, found := Reflection.get_enum_by_name(System_Stage, it.name);
        if found {
            if !is_event_func(stage) {
                push_builder :: () #expand { `sb: String_Builder; `defer free_buffers(*sb); }
                p :: (s: string, args: ..Any) #expand { `print_to_builder(*sb, tprint("%\n", s), ..args); }

                push_builder();
                p("% :: (world: *World) {", internal_system_func_name);
                p("    for * world.entities {");
                for component_names {
                p("        component_% := get_component(it, %);", it_index, it);
                p("        if !component_% continue;", it_index);
                }
                p("        // %", code_node_as_string(it));
                p("        // %", String.join(..component_names, separator=", "));
                p("        inline %(%);", it.name, String.join(..arg_names, separator=", "));
                p("    }");
                p("}");
                add_build_string(builder_to_string(*sb), metaprogram.workspace);
            }

            entry := array_add(*by_stage);
            entry.stage = stage;
            entry.funcname = internal_system_func_name;
            entry.needs_entity_at_end = needs_entity_at_end;
            entry.component_names = component_names;
            //print("YES: (stage=%) %\n", stage, code_node_as_string(it));
        }
    }

    System_Stage_ti := type_info(System_Stage);

    sb: String_Builder;
    defer free_buffers(*sb);
    p :: print_to_builder;

    p(*sb, "#load \"src/metaprogram_common.jai\";\n\n");

    p(*sb, "// event functions\n");

    did_find_function_for_this_stage: [..][..]bool;
    array_resize(*did_find_function_for_this_stage, System_Stage_ti.values.count);
    for * did_find_function_for_this_stage
        array_resize(it, metaprogram.component_type_names.count);

    for enum_value, enum_index: System_Stage_ti.values {
        enum_stage := cast(System_Stage)enum_value;
        if !is_event_func(enum_stage)
            continue;

        for * entry: by_stage {
            if entry.stage == enum_stage {
                func_args := Temp_Resizable_Array(string);
                call_args := Temp_Resizable_Array(string);

                first_component_name: string;
                for entry.component_names {
                    array_add(*func_args, tprint("c%: *%", it_index, it));
                    first_component_name = it;
                    array_add(*call_args, tprint("c%", it_index));
                }
                if entry.needs_entity_at_end {
                    array_add(*func_args, "entity: *Entity");
                    array_add(*call_args, "entity");
                }
                p(*sb, "run_% :: inline (%) { ", System_Stage_ti.names[enum_index],
                    String.join(..func_args, separator=", "));
                p(*sb, " %(%);", entry.stage, String.join(..call_args, separator=", "));
                p(*sb, " }\n");

                c_found, component_index := array_find(metaprogram.component_type_names, entry.component_names[0]);
                assert(c_found);
                did_find_function_for_this_stage[enum_stage][component_index] = true;
            }
        }

        p(*sb, "run_% :: (entities: []*Entity) {\n", System_Stage_ti.names[enum_index]);

        p(*sb, "    for entities {\n");
        for * entry: by_stage {
            if entry.stage == enum_stage {
                call_args := Temp_Resizable_Array(string);
                for entry.component_names {
                    varname := tprint("c_%", it);
                    p(*sb, "        % := get_component(it, %);\n", varname, it);
                    p(*sb, "        if % != null ", varname);
                    array_add(*call_args, varname);
                }

                if entry.needs_entity_at_end
                    array_add(*call_args, "it");

                p(*sb, "%(%);\n", entry.stage, String.join(..call_args, separator=", "));
            }
        }

        p(*sb, "    }\n");

        p(*sb, "}\n");
    }

    // Stubs for components that didn't implement events like on_enable.  This
    // lets us still invoke "run_on_enable(component, entity)" from the game,
    // but have it do nothing.
    for comp_name: metaprogram.component_type_names {
        for enum_value, enum_index: System_Stage_ti.values {
            enum_stage := cast(System_Stage)enum_value;
            if !is_event_func(enum_stage) continue;
            if !did_find_function_for_this_stage[enum_stage][it_index] {
                p(*sb, "run_% :: inline (_: *%, entity: *Entity) { /* nothing */ }\n", enum_stage, comp_name);
            }
        }
    }
    
    // Finally, write out a "run_all" function which, given a System_Stage,
    // will run all the system functions for that stage and the given *World.
    p(*sb, "run_all :: (world: *World, stage: System_Stage) {\n");
    for * enum_value: System_Stage_ti.values {
        enum_stage := cast(System_Stage)<<enum_value;
        if is_event_func(enum_stage) continue;
        p(*sb, "    if stage == .% {\n", System_Stage_ti.names[it_index]);
        for * entry: by_stage {
            if entry.stage == enum_stage {
                p(*sb, "        %(world);\n", entry.funcname);
            }
        }
        p(*sb, "    }\n");
    }
    p(*sb, "}\n");


    add_build_string(builder_to_string(*sb), metaprogram.workspace);

    //print("created ECS code for workspace %\n", metaprogram.workspace);
}

collect_component_functions :: (tc: *Compiler_Message_Code_Typechecked, metaprogram: *Metaprogram) {
    for decl: tc.declarations {
        if !decl.root_expression continue;

        if decl.root_expression.kind == {
          case .LITERAL;
            //
            // here we catch the definition of the "all_component_types" array
            //
            if decl.name == "all_component_types" || decl.name == "all_test_types" {
                literal := cast(*Code_Literal)decl.root_expression;
                if literal.value_type == .ARRAY {
                    //print("name: %\n", decl.name);
                    //print("literal array: %\n", <<literal.array_literal_info);
                    //print("  element_type: %\n", <<literal.array_literal_info.element_type);
                    for literal.array_literal_info.array_members {
                        if it.kind == .IDENT {
                            ident := cast(*Code_Ident)it;
                            array_add(*metaprogram.component_type_names, copy_string(ident.name));
                            //print("  %: %\n", it_index, code_node_as_string(it));
                        }
                    }
                }
            }

          //case .STRUCT;
            // TODO: maybe we could collect component structs here, instead of
            // relying on the other compile time metaprogramming stuff in
            // entity.jai which walks the type table?

          case .PROCEDURE_HEADER;
            header := cast(*Code_Procedure_Header) decl.root_expression;
            if header.procedure_flags & .POLYMORPHIC continue;  // Do nothing with polymorphic procedures.

            if header.arguments.count > 0 && (
                // This must match the System_Stage enum in src/metaprogram_common.jai.

                // TODO: metaprogram the metaprogram??!? maybe it'd be as easy
                // as an #insert #run here...

                header.name == "on_enable" ||
                header.name == "update" ||
                header.name == "late_update" ||
                header.name == "draw" ||
                header.name == "on_disable" ||
                0
            ) {
                    array_add_if_unique(*metaprogram.system_funcs, header);
                    //print("  %: %\n^^^ %\n\n", it_index, <<it, code_node_as_string(it.type_inst.pointer_to.type_valued_expression));
                }
                //exit(1);


            
            /*
          case .PROCEDURE_BODY;
            body := cast(*Code_Procedure_Body) decl.root_expression;
            if body.header.procedure_flags & .POLYMORPHIC continue;  // Do nothing with polymorphic procedures.

            check_print_calls(decl);
            */
        }
    }
}

is_component_func :: (decl: *Code_Declaration) -> bool {
    for decl.notes {
        if it.text == "draw" {
            return true;
        }
    }

    return false;
}


CHECK_PATH :: "check/";

build :: () {
    DEFAULT_SRC_PLUGIN :: "game";

    args := compiler_get_command_line_arguments();
    is_reload := false;
    if args.count > 0 {
        flags := Build_Flags.None;
        if args[0] == "reload" {
            args.data = args.data + 1;
            args.count -= 1;
            flags |= .Reload;
        }
        if args.count > 0 if args[0] == {
            case "all";
                build_host();
                build_plugin(flags, DEFAULT_SRC_PLUGIN);
            case "host";
                build_host();
            case "check";
                build_host(check=true);
                flags |= .Check_Only;
                build_plugin(flags, DEFAULT_SRC_PLUGIN);
            case;
                build_plugin(flags, args[0]);
        }

        return; // done.
    }

    // With no command line arugments, just build the plugin specified by
    // DEFAULT_SRC_PLUGIN.
    build_plugin(.None, DEFAULT_SRC_PLUGIN);
}

#run build();
