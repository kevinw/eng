//DEFAULT_SRC_PLUGIN :: "jumper";
DEFAULT_SRC_PLUGIN :: "d3d_game";
//DEFAULT_SRC_PLUGIN :: "game";

RUN_METAPROGRAM_CHECK :: false;

is_name_a_System_Stage :: inline (name: string) -> bool    {
    #insert #run (() -> string {
        sb: String_Builder;
        defer free_buffers(*sb);

        print_to_builder(*sb, "return ");
        for type_info(System_Stage).names
            print_to_builder(*sb, "name == \"%\" || ", it);
        print_to_builder(*sb, "0;\n");

        return builder_to_string(*sb, __temporary_allocator);
    }());
}

System_Stage :: enum {
    on_enable;
    update;
    late_update;
    pre_draw;
    draw;
    on_disable;
}

is_event_func :: (stage: System_Stage) -> bool {
    // returns true if the System_Stage is an "event func" like on_enable
    if stage == {
        case .on_enable; #through;
        case .on_disable;
            return true;
        case;
            return false;
    }
}

stop_normal_build :: () -> Compiler.Build_Options {
    set_build_options_dc(.{do_output=false});
    return Compiler.get_build_options();
}

compiler_scoped_intercept :: (w: int) #expand {
    compiler_begin_intercept(w);
    `defer compiler_end_intercept(w);
}

run_compiler_loop :: (workspace: int, $do_ecs_metaprogram: bool) {
    #if do_ecs_metaprogram {
        metaprogram: Metaprogram;
        metaprogram.workspace = workspace;
    }

    did_generate_systems := false;

    while true {
        message := compiler_wait_for_message();
        if !message || message.workspace != workspace continue;

        #if RUN_METAPROGRAM_CHECK {
            Check.do_error_checking(message, check_bindings=true);
        }

        #if do_ecs_metaprogram {
            if message.kind == {
                case .TYPECHECKED;
                    collect_component_functions(cast(*Compiler.Message_Typechecked)message, *metaprogram);

                case .COMPILATION_PHASE;
                    msg := cast(*Compiler.Message_Phase)message;
                    if !did_generate_systems && msg.phase == .TYPECHECKED_ALL_WE_CAN {
                        did_generate_systems = true;
                        generate_systems(*metaprogram);
                        output_quick_search(*metaprogram);
                    }
            }
        }

        if message.kind == .COMPLETE {
            break;
        }
    }
}

Quick_Search_Metaprogram_Entry :: struct {
    label: string;
    proc_name: string;
}

Metaprogram :: struct {
    workspace: s64;
    system_funcs: [..]*Compiler.Code_Procedure_Header;
    quick_search_procs: [..]Quick_Search_Metaprogram_Entry;
    component_type_names: [..]string; // TODO: should these be *Type_Infos?
}

Temp_Resizable_Array :: inline ($T: Type) -> [..]T {
    arr: [..]T;
    arr.allocator = __temporary_allocator;
    return arr;
}


is_argument_a_pointer_to_a_component :: (arg_decl: *Compiler.Code_Declaration, metaprogram: *Metaprogram) -> (is_component: bool, component_name: string) {
    if arg_decl.type_inst == null return false, "";
    if arg_decl.type_inst.pointer_to == null return false, "";

    arg_type_ident := arg_decl.type_inst.pointer_to.type_valued_expression;
    if arg_type_ident == null return false, "";
    if arg_type_ident.kind != .IDENT return false, "";

    // TODO: should we compare pointers instead of type names here? yes. the answer is yes.
    name := (cast(*Compiler.Code_Ident)arg_type_ident).name;
    found, index := array_find(metaprogram.component_type_names, name);
    if found return true, metaprogram.component_type_names[index];
    
    else return false, name;
}

output_quick_search :: (metaprogram: *Metaprogram) {
    // Quick search entries
    args: [..]string;
    args.allocator = temp;
    for metaprogram.quick_search_procs
        array_add(*args, tprint("    .{\"%\", %},", it.label, it.proc_name));
    quick_search_code_text := tprint(#string END
quick_search_tasks := Quick_Search_Entry.[
    %
];
END, String.join(..args, separator="\n"));

    Compiler.add_build_string(quick_search_code_text, metaprogram.workspace);
}

generate_systems :: (metaprogram: *Metaprogram) {
    // this one's a doozy. it's an effort to make creating new Components in the ECS system easy.
    // functions with special names like 'update' get collected and called in a
    // sort of static event dispatch.
    system_count := 0;

    by_stage: [..]struct {
        stage: System_Stage;
        funcname: string;
        needs_entity_at_end: bool;
        component_names: []string;
    };
    by_stage.allocator = __temporary_allocator;

    for metaprogram.system_funcs {
        /*
        if it.body_or_null == null {
            print("WARNING: system function has null body_or_null: %\n", <<it);
            continue;
        }
        */
        if it.arguments.count == 0 {
            print("WARNING: system function has zero args: %\n", <<it);
            continue;
        }

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
                Compiler.add_build_string(builder_to_string(*sb, __temporary_allocator), metaprogram.workspace);
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

        p(*sb, "run_% :: (component_ptr: *Component, component_bit: Component_Bit) {\n", System_Stage_ti.names[enum_index]);
        p(*sb, "    ok, entity_ptr := get_entity(component_ptr);\n"); // TODO @Speed maybe we should pass this in.
        p(*sb, "    assert(ok);\n");
        p(*sb, "    if component_bit == {\n");
        for * entry: by_stage {
            if entry.stage == enum_stage {
                if entry.component_names.count != 1 continue;


                call_args := Temp_Resizable_Array(string);
                first_component_name: string;
                for entry.component_names {
                    first_component_name = it;
                    varname := tprint("cast(*%)component_ptr", it);
                    array_add(*call_args, varname);
                }

                if entry.needs_entity_at_end
                    array_add(*call_args, "entity_ptr");

                p(*sb, "        case .%; %(%);\n", first_component_name, entry.stage, String.join(..call_args, separator=", "));
            }
        }
        p(*sb, "        case; // do nothing, there is no % function for this component\n", System_Stage_ti.names[enum_index]);
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

    Compiler.add_build_string(builder_to_string(*sb, __temporary_allocator), metaprogram.workspace);

    //print("created ECS code for workspace %\n", metaprogram.workspace);
}


collect_component_functions :: (tc: *Compiler.Message_Typechecked, metaprogram: *Metaprogram) {
    for tc: tc.declarations {
        decl := tc.expression;
        if !decl.expression continue;

        if decl.expression.kind == {
          case .LITERAL;
            // here we catch the definition of the "all_component_types" array
            if decl.name == "all_component_types" || decl.name == "all_test_types" {
                literal := cast(*Compiler.Code_Literal)decl.expression;
                if literal.value_type == .ARRAY {
                    for literal.array_literal_info.array_members {
                        if it.kind == .IDENT {
                            ident := cast(*Compiler.Code_Ident)it;
                            array_add(*metaprogram.component_type_names, copy_string(ident.name));
                        }
                    }
                }
            }

          //case .STRUCT;
            // TODO: maybe we could collect component structs here, instead of
            // relying on the other compile time metaprogramming stuff in
            // entity.jai which walks the type table?

          case .PROCEDURE_HEADER;
            header := cast(*Compiler.Code_Procedure_Header) decl.expression;

            if header.procedure_flags & .POLYMORPHIC
                continue;  // Do nothing with polymorphic procedures.

            // Note procedures for later if they look like our special "system"
            // procs.
            if header.arguments.count > 0 && is_name_a_System_Stage(header.name)
                array_add_if_unique(*metaprogram.system_funcs, header);
            
            for header.notes {
                prefix :: "QuickSearch";
                if it.text == prefix {
                    label_copy := sprint("%", header.name);
                    capitalize_and_spacify_snake_case(label_copy);
                    entry := array_add(*metaprogram.quick_search_procs);
                    entry.label = label_copy;
                    entry.proc_name = header.name;
                }
            }
        }
    }
}

Build_Flags :: enum_flags {
    None       :: 0;
    Check_Only :: 1 << 0;
    Reload     :: 1 << 1;
    Release    :: 1 << 2;
}


define_constants :: (workspace: int, build_flags: Build_Flags, is_host: bool, print_constants_to_stdout := true) {
    release :=               build_flags & .Release != 0;

    debug_module :=             !release;
    guard_allocator :=          !release;
    building_dlls :=            !release;
    graphics_layer_debug :=     !release;
    link_externals_as_static := release;
    context_state_type :=       ifx is_host && !release then "*void" else "*State";

    add_build_string_constants := tprint(#string END
#add_context state   :  %;
END,
    context_state_type,
);
    
    constants := tprint(#string END
DEBUG_MODULE         :: %;
GUARD_ALLOCATOR      :: %;
BUILDING_DLLS        :: %;
GRAPHICS_LAYER_DEBUG :: %;
END,
    debug_module,
    guard_allocator,
    building_dlls,
    graphics_layer_debug,
);

    if print_constants_to_stdout {
        print("------\n%", constants);
        print("%------\n", add_build_string_constants);
    }

    Compiler.add_build_string(add_build_string_constants, workspace);

    // here we import some modules very early in the build process, being sure
    // to provide the module parameters we wish to use. this will result in
    // further imports later in the program using those parameters.
    //
    // the specific thing we use this for here is to link to static libraries
    // in a release build. this is slower compile-time-wise, but then we don't
    // have an extra DLL dependency.
    imports_with_module_params := tprint(#string END

__module_param_import_Chipmunk :: #import "Chipmunk"()(LINK_STATIC = %);
__module_param_import_ImGui    :: #import "imgui_docking"()(LINK_STATIC = %);
__module_param_import_lz4      :: #import "lz4-1.9.3"(LINK_STATIC = %);
#import "Thread"; // contains an #add_context--so we must import it here; see @ProgramParameters below

END, link_externals_as_static, link_externals_as_static, link_externals_as_static);


    Compiler.add_build_string(imports_with_module_params, workspace);

    fn :: "generated/Build_Constants.jai";
    File.write_entire_file(fn, constants);
    Compiler.add_build_file(fn, workspace);

    // @ProgramParameters
    // we will wait for the Compiler to actually process these strings, since
    // if any other code runs an #import with the modules above, we'll get an
    // error later when the build strings added here get processed--module
    // parameters are only allowed to be present in the "first" import.
    //
    // TODO: should we instead move the #imports into the code directly? I'm
    // not sure they need to be here as part of the metaprogram.
    wait_for_compiler_to_see_build_strings(workspace);
}

wait_for_compiler_to_see_build_strings :: (workspace: int) -> bool {
    while true {
        message := compiler_wait_for_message();
        if !message || message.workspace != workspace continue;

        if message.kind == {
            case .COMPILATION_PHASE;
                msg := cast(*Message_Phase)message;
                if msg.phase == .TYPECHECKED_ALL_WE_CAN {
                    return true;
                }
        }

        if message.kind == .COMPLETE {
            print("\n\nerror: got compiler message COMPLETE--this means there was an error in our generated code\n");
            exit(1);
        }
    }

    return false;
}



#scope_file
Compiler :: #import "Compiler";
String :: #import "String";
Reflection :: #import "Reflection";
File :: #import "File";

code_node_as_string :: (node: *Code_Node) -> string {
    using Compiler;
    if node == null return "<null>";

    if node.kind == {
        case .PROCEDURE_HEADER;
            proc_header := cast(*Code_Procedure_Header)node;
            return tprint("Code_Procedure_Header { name=%, filename=%, line=% }",
                proc_header.name, get_filename(proc_header), proc_header.l0);
                
        case .IDENT;
            ident := cast(*Code_Ident)node;
            return tprint("Ident { name=%, type=%, resolved_decl=% }", ident.name, <<ident.type, code_node_as_string(ident.resolved_declaration));

        case .DECLARATION;
            decl := cast(*Code_Declaration)node;
            return tprint("Code_Declaration { name: %, expression: % }", decl.name, code_node_as_string(decl.expression));

        case .LITERAL;
            literal := cast(*Code_Literal)node;
            return tprint("%", <<literal);

        case .TYPE_DEFINITION;
            type_def := cast(*Code_Type_Definition)node;
            return tprint("Type_Definition { info=%s }", <<type_def.info);

        case .TYPE_INSTANTIATION;
            type_inst := cast(*Code_Type_Instantiation)node;
            return tprint("Code_Type_Instantiation { type_valued_expression=%, pointer_to=%, <others> }",
                code_node_as_string(type_inst.type_valued_expression), ifx type_inst.pointer_to == null then "<null>" else code_node_as_string(type_inst.pointer_to));

        case;
            return tprint("unknown Code_Node.type %", node.kind);
    }
}


#scope_file
#import "Compiler";
#load "../lib/string_util.jai";
Check :: #import "Check";

