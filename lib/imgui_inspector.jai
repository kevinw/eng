Reflection :: #import "Reflection";

#scope_file
ImVec2 :: ImGui.ImVec2;

show_inspector := true;    // Wish we could declare static variables inside functions.

#scope_export

inspect :: inline (name: *u8, t: *$T) {
    inspect(name, t, type_info(T));
}

Struct_Looks_Like :: enum {
    None      :: 0;
    Float2    :: 2;
    Float3    :: 3;
    Float4    :: 4;
    Matrix4x4 :: 16;

    Int2      :: 102; // TODO: return these from categorize_ti_struct
    Int3      :: 103;
    Int4      :: 104;
}

categorize_ti_struct :: (ti_struct: *Type_Info_Struct) -> Struct_Looks_Like {
    // @Speed @Memoize

    seen_offsets: [..]int;
    seen_offsets.allocator = __temporary_allocator;

    num_floats: int;

    for member:ti_struct.members {
        if !array_add_if_unique(*seen_offsets, member.offset_in_bytes) {
            // we skip #place directives by ignoring fields which are at byte
            // offsets we've already seen.
            continue;
        }

        if member.type.type == {
            case .FLOAT; num_floats += 1;
            // case .INTEGER;  // TODO: do integer sizes 32, 64???
            case; return .None;
        }
    }

    if num_floats == {
        case 2;  return .Float2;
        case 3;  return .Float3;
        case 4;  return .Float4;
        case 16; return .Matrix4x4;
    }
}

#assert(categorize_ti_struct(cast(*Type_Info_Struct)type_info(Vector3)) == .Float3);

inspect :: (name: *u8, data: *void, info:*Type_Info) {
    default_size:ImVec2;
    using ImGui;

    PushID(data);
    defer PopID();

    if #complete info.type == {
        case .INTEGER;
            info_int := cast(*Type_Info_Integer) info;
            InputInt(name, data); // @@ Add support for unsigned, and larger int types.
        case .FLOAT;
            if info.runtime_size == {
                case 4;
                    //DragFloat(name, data, display_format="%.3f");
                    InputFloat(name, data, 0.01, 1.0);
                case 8;
                    x : float = xx <<cast(*float64) data;
                    if InputFloat(name, *x, 0.01, 1.0) { <<cast(*float64) data = x; };
            }
        case .BOOL;
            //Checkbox(name, data);
            index: s32 = xx <<cast(*bool)data;
            if Combo(name, *index, "false\0true\0\0") { <<cast(*bool)data = xx index; }
        case .STRING;
            string_data := Reflection.get_string_data(data, xx info);
            string_count := Reflection.get_string_count(data, xx info);
            
            if string_data InputText(name, string_data, xx string_count, InputTextFlags.ReadOnly);    // @@ We could allow editing of strings too.
            else InputText(name, "(null)", 6, InputTextFlags.ReadOnly);

        case .POINTER;
            // @@ Open in new window?
            info_pointer := cast(*Type_Info_Pointer) info;
            assert(info_pointer.relative_pointer_size == 0, "TODO: implement relative pointers?");
            inspect("", <<(cast(**void)data), info_pointer.pointer_to);
        case .PROCEDURE;
            TextUnformatted("procedure");
        case .VOID;
            TextUnformatted("void");
        case .CODE;
            TextUnformatted("Code");
        case .STRUCT;
            ti_struct := cast(*Type_Info_Struct) info;
            if categorize_ti_struct(ti_struct) == {
                case .Float2;
                    DragFloat2(name, cast([2]float)data);
                case .Float3;
                    DragFloat3(name, cast([3]float)data);
                case .Float4;
                    DragFloat4(name, cast([4]float)data);
                case;
                    if TreeNode("%: %", to_string(name), ti_struct.name) {
                        defer TreePop();

                        for member:ti_struct.members {
                            skip := false;
                            for note: member.notes {
                                if note == "noui" {
                                    skip = true;
                                    break;
                                }
                            }
                            if !skip
                                inspect(temp_c_string(member.name), data + member.offset_in_bytes, member.type);
                        }
                    }
            }
        case .ARRAY;
            info_array := cast(*Type_Info_Array) info;
            array_count, array_data := Reflection.get_array_count_and_data(data, info_array);
            array_name := to_string(name);
            element_size := info_array.element_type.runtime_size;            
            if TreeNode("% (count = %) ->", array_name, array_count) {
                defer TreePop();
                for 0..array_count-1 {
                    item_name := temp_c_string(tprint("%[%]", array_name, it));
                    inspect(item_name, array_data + it * element_size, info_array.element_type);
                }
            }
        case .ANY;
            // @@ Display type and inspect value.
            Text("Any!");        
        case .ENUM;
            info_enum := cast(*Type_Info_Enum) info;

            if info_enum.enum_type_flags & .Is_Flags {
                // @@ How to handle flags?
            }
            else {
                value := Reflection.get_enum_value(data, info_enum);
                value_name := "";
                for info_enum.names {
                    if value == info_enum.values[it_index]  value_name = it;
                }

                if BeginCombo(name, temp_c_string(value_name)) {
                    for info_enum.names {
                        is_selected := value == info_enum.values[it_index];
                        if Selectable(temp_c_string(it), is_selected, size=default_size) {
                            Reflection.set_enum_value(data, info_enum, info_enum.values[it_index]);
                        }
                        if is_selected SetItemDefaultFocus();
                    }

                    EndCombo();
                }
            }

            
        case .POLYMORPHIC_VARIABLE;
            // @@ ??
        case .TYPE;
            // @@
        case .OVERLOAD_SET;
            // @@
    }

}

