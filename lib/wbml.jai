// originally ported from the MIT licensed "workbench" project by @JoshuaManton
// https://github.com/JoshuaManton/workbench

// TODO:
// use initializer_of to skip writing struct field values if they are
// still set to their defaults

#scope_file

BUILD_DEBUG_NAMES :: false; // causes a lot of tprint-ing to track a debug string showing the context of the serialization

#scope_module

node_to_string :: (node: *Node, indent := "") -> string {
    sb: String_Builder;
    defer free_buffers(*sb);

    if node == null
        print_to_builder(*sb, "<null>");
    else {
        if node.type == {
            case .Enum_Value; print_to_builder(*sb, node._enum);
            case .Number;     print_to_builder(*sb, node._number.value_str);
            case .String;     print_to_builder(*sb, "\"%\"", node._string);
            case .Object;     print_to_builder(*sb, node_object_to_string(*node._object, indent));
            case;             print_to_builder(*sb, "%", <<node);
        }
    }

    return builder_to_string(*sb);

}

node_object_to_string :: (node_object: *Node_Object, indent := "") -> string {
    sb: String_Builder;
    defer free_buffers(*sb);

    if node_object == null
        print_to_builder(*sb, "%<null>", indent);
    else {
        print_to_builder(*sb, "%Node_Object {\n", indent);
        print_to_builder(*sb, "%  fields [\n", indent);
        for * node_object.fields {
            if it.value.type == .Object
                print_to_builder(*sb, "%    %:\n%\n", indent, it.name, node_object_to_string(*it.value._object, tprint("%      ", indent)));
            else
                print_to_builder(*sb, "%    %: %\n", indent, it.name, node_to_string(it.value, tprint("%      ", indent)));
        }
        print_to_builder(*sb, "%  ]\n", indent);
        print_to_builder(*sb, "%  prototype: %\n", indent, node_object_to_string(node_object.prototype), tprint("%      ", indent));
        print_to_builder(*sb, "%}\n", indent);
    }

    return builder_to_string(*sb);
}

Node :: struct {
    Type :: enum {
        Number;
        Bool;
        String;
        Nil;
        Enum_Value;
        Object;
        Array;
        Union;
        Quat;
    }
    type: Type;
	union {
		_number: Node_Number;
		_bool: Node_Bool;
		_string: string;
		_nil: struct {};
		_enum: string;
		_object: Node_Object;
		_array: Node_Array;
		_union: Node_Union;
		_quat: Node_Quat;
	};
}

Node_Number :: struct {
	int_value: s64;
	uint_value: u64;
	float_value: float64;

    value_str: string;
}

Node_Bool :: struct {
	value: bool;
}

Node_Object :: struct {
	fields: []Object_Field;
    prototype: *Node_Object;
}

Object_Field :: struct {
	name: string;
	value: *Node;
}

Node_Array :: struct {
	elements: []*Node;
}

Node_Union :: struct {
	variant_name: string;
	value: *Node;
}

Node_Quat :: struct {
	w, x, y, z: *Node;
}

get_obj :: (node: *Node, field_name: string) -> *Node {
    return get(node, field_name, .Object);
}

get_string :: (node: *Node, field_name: string) -> string {
    assert(node.type == .Object);
    s := _get_from_object(*node._object, field_name);
    if s == null return "";
    assert(s.type == .String);
    return s._string;
}

get :: (node: *Node, field_name: string) -> *Node {
    assert(node.type == .Object, "You must pass a wbml.Node with type .Object to 'get'");
    return _get_from_object(*node._object, field_name);
}

get :: (node: *Node, field_name: string, node_type: Node.Type, do_remove := true) -> *Node {
    assert(node.type == .Object, "You must pass a wbml.Node with type .Object to 'get'");
    return _get_from_object(*node._object, field_name, node_type, do_remove);
}

_get_from_object :: (node_object: *Node_Object, field_name: string) -> *Node {
    for node_object.fields
        if it.name == field_name
            return it.value;

    if node_object.prototype != null
        return _get_from_object(node_object.prototype, field_name);

    return null;
}

_get_from_object :: (node_object: *Node_Object, field_name: string, node_type: Node.Type, do_remove := true) -> *Node {
    for node_object.fields {
        if it.name == field_name {
            assert(it.value.type == node_type);
            val := it.value;
            if do_remove {
                //print("warning: removing field % from object node\n", field_name); // TODO - get rid of do_remove
                remove it; // @Leak
            }
            return val;
        }
    }

    if node_object.prototype != null {
        // if do_remove print("warning: ignoring do_remove on prototype for field_name %\n", field_name); // TODO - get rid of do_remove
        return _get_from_object(node_object.prototype, field_name, node_type);
    }

    return null;
}

Added_Field_Entry :: struct {
    name: string;
    any: Any;
}

On_Serialize_Func :: #type (any: *Any, added_fields: *[..]Added_Field_Entry);

default_on_serialize: On_Serialize_Func : (any: *Any, added_fields: *[..]Added_Field_Entry) {
    // do nothing
};

On_Deserialize_Func :: #type (any: *Any, node: *Node, userdata: *void) -> (handled: bool);

default_on_deserialize: On_Deserialize_Func : (any: *Any, node: *Node, userdata: *void) -> (handled: bool) {
    // do nothing and return false, meaning "we didn't handle it"
    return false;
}

Default_Node_Entry :: struct {
    type: *Type_Info;
    node: *Node;
}

_default_nodes: [..]Default_Node_Entry;

get_defaults_node :: (value: *$Type, on_serialize := default_on_serialize) -> *Node {
    s := serialize(value, on_serialize, do_automatic_defaults = false);
    assert(s.count > 0);
    lexer := laas.make_lexer(s);
    node := parse_value(*lexer);
    assert(node != null);
    return deep_copy(node);
}

serialize :: (value: *$Type, on_serialize := default_on_serialize, do_automatic_defaults := true) -> string {
    ti := type_info(Type);
    default_node: *Node;

    for _default_nodes
        if it.type == ti
            default_node = it.node;

    if default_node == null && do_automatic_defaults {
        default_value: Type;

        wbml_string := serialize_ti(*default_value, ti, on_serialize);
        lexer := laas.make_lexer(wbml_string);
        root := parse_value(*lexer, false);
        assert(root != null, tprint("error parsing: %", wbml_string));

        new_entry := array_add(*_default_nodes);
        new_entry.type = type_info(Type);
        new_entry.node = root;

        default_node = root;
    }

    return serialize_ti(value, type_info(Type), on_serialize, default=default_node);
}

serialize_ti :: (ptr: *void, ti: *Type_Info, on_serialize := default_on_serialize, debug_name := "", default: *Node = null) -> string {
    sb: String_Builder;
    serialize_string_builder_ti(ptr, ti, *sb, on_serialize, debug_name, default=default);
    return builder_to_string(*sb);
}

serialize_string_builder_ti :: (value: *void, ti: *Type_Info, sb: *String_Builder, on_serialize := default_on_serialize, debug_name := "", default: *Node = null) {
    serialize_with_type_info("", value, ti, sb, 0, on_serialize, default=default);
}

serialize_with_type_info :: (
    name: string, value: *void, ti: *Type_Info, sb: *String_Builder, indent_level: int = 0,
    on_serialize := default_on_serialize, debug_name := "", default: *Node = null
) -> (did_skip: bool)
{
    assert(ti != null);

    dbgname := debug_name;
    #if BUILD_DEBUG_NAMES {
        if dbgname.count == 0 {
            if ti.type == .STRUCT
                dbgname = (cast(*Type_Info_Struct)ti).name;
            else
                dbgname = tprint("%", <<ti);
        }
    }

    name_and_space: string;
    if name != "" name_and_space = tprint("% ", name);

    skip := false;
    any_child_worked := false;

	item: Any;
	item.type = ti;
	item.value_pointer = value;

    t := ti.type;
    if t == {
        case .BOOL;
            if default != null {
                assert(default.type == .Bool);
                default_val := default._bool.value;
                data_val    := <<cast(*bool)value;
                if default_val == data_val
                    skip = true;
            }
            if !skip {
                print_indents(indent_level, sb);
                append(sb, name_and_space);
                print_to_builder(sb, ifx (<< (cast(*bool)value)) then "true" else "false");
            }
        case .INTEGER; #through;
        case .FLOAT; #through;
        case .ENUM;
            if default != null {
                if t == {
                case .FLOAT;
                    Math :: #import "Math";
                    epsilon :: 0.0001;
                    if ti.runtime_size == 4 {
                        f32: float = <<cast(*float)value;
                        default_val := default._number.float_value;
                        if Math.abs(f32 - default_val) < epsilon
                            skip = true;
                    } else if ti.runtime_size == 8 {
                        f64: float64 = <<cast(*float64)value;
                        default_val := cast(float64)default._number.float_value; // TODO: this could be a loss of precision? we should probably just store 64 bit floats in the wbml node always...
                        if Math.abs(f64 - default_val) < epsilon
                            skip = true;
                    } else {
                        assert(false, tprint(
                            "Type_Info_Float had unexpected runtime size %", ti.runtime_size));
                    }
                case .INTEGER;
                    ti_integer := cast(*Type_Info_Integer)ti;
                    if ti_integer.signed {
                        if default._number.int_value == get_s64_from_void_pointer(value, ti.runtime_size) {
                            skip = true;
                        }
                    } else {
                        if default._number.int_value == cast,trunc(s64) get_u64_from_void_pointer(value, ti.runtime_size) {
                            skip = true;
                        }
                    }
                case .ENUM;
                    temp_val: s64;
                    default_item: Any;
                    default_item.type = ti;
                    default_item.value_pointer = *temp_val;
                    did_set := Reflection.set_value_from_string(default_item, default._enum);
                    default_str := tprint("%", default_item); 
                    item_str := tprint("%", item);
                    if default_str == item_str // @Speed it's dumb to stringify the enums here to check their effective equality
                        skip = true;
                }
            }

            if !skip {
                number_as_str := tprint("%", item);
                if t == .FLOAT
                    strip_trailing_decimal_zeros(*number_as_str);

                print_indents(indent_level, sb);
                append(sb, name_and_space);
                append(sb, number_as_str);
            }
        case .STRING;
            if default != null {
                assert(default.type == .String);
                default_str := default._string;
                this_val := <<cast(*string)value;
                if default_str == this_val {
                    skip = true;
                }
            }
            if !skip {
                print_indents(indent_level, sb);
                append(sb, name_and_space);
                print_item_to_builder(sb, item); // will quote for us
            }
		case .ARRAY;
            ti_array := cast(*Type_Info_Array)ti;

            sub_sb: String_Builder;
            defer free_buffers(*sub_sb);

			{
                indent_level += 1;
                defer indent_level -= 1;

				count, data := Reflection.get_array_count_and_data(value, ti_array);

                if default != null {
                    default_count, default_data := Reflection.get_array_count_and_data(default, ti_array);
                    if default_count == 0 && count == 0
                        skip = true;
                }

                if !skip
                    for i: 0..count-1 {
                        elem_data := data + ti_array.element_type.runtime_size * i;

                        //
                        // TODO: how to handle defaults with arrays? the problem here is that we can't simply
                        // skip elements if they're equal, because then things will be in the wrong order.
                        //

                        //item_default: *void;
                        //if default != null
                            //item_default = item_default + ti_array.element_type.runtime_size * i;

                        child_debug_name := debug_name;
                        #if BUILD_DEBUG_NAMES
                            child_debug_name = tprint("%[%]", dbgname, i);
                        any_child_worked |= serialize_with_type_info("", elem_data, ti_array.element_type, *sub_sb, indent_level,
                            on_serialize, child_debug_name, default=null);
                    }
			}

            if !skip {
                print_indents(indent_level, sb);
                append(sb, name_and_space);
                append(sb, "[\n"); 

                append(sb, builder_to_string(*sub_sb));

                print_indents(indent_level, sb);
                append(sb, "]");
            }

        case .STRUCT;
            ti_struct := cast(*Type_Info_Struct)ti;
            seen_offsets: [..]int;
            seen_offsets.allocator = __temporary_allocator;

            // Allow callers to add additional fields to any struct as they wish.
            added_struct_fields: [..]Added_Field_Entry;
            added_struct_fields.allocator = __temporary_allocator;
            res := on_serialize(*item, *added_struct_fields);

            sub_sb: String_Builder;
            defer free_buffers(*sub_sb);

            indent_level += 1;
            for added_struct_fields {
                child_debug_name := dbgname;
                #if BUILD_DEBUG_NAMES
                    child_debug_name = tprint("%.%", dbgname, it.name);
                any_child_worked |= serialize_with_type_info(it.name, it.any.value_pointer, it.any.type, *sub_sb, indent_level,
                    on_serialize, child_debug_name, default=default);
            }

            for * ti_struct.members {
                if !should_serialize_struct_member(it, *seen_offsets)
                    continue;

                member_any := make_Any(it.type, value + it.offset_in_bytes);
                on_serialize(*member_any, null);
                field_default: *Node;
                if default != null
                    field_default = _get_from_object(*default._object, it.name);

                child_debug_name := dbgname;
                #if BUILD_DEBUG_NAMES
                    child_debug_names = tprint("%.%", dbgname, it.name);
                any_child_worked |= serialize_with_type_info(it.name, member_any.value_pointer, member_any.type, *sub_sb, indent_level,
                    on_serialize, child_debug_name, default=field_default);
            }

            indent_level -= 1;
            sub_str := builder_to_string(*sub_sb);
            defer free(sub_str);

            // When serializing things, we omit things entirely if they are the default.
            // The exception here is when indent_level is 1, when we'll still emit an 
            // empty {} brace pair.
            if indent_level == 0 || any_child_worked {
                print_indents(indent_level, sb);
                append(sb, name_and_space);
                append(sb, "{\n");
                append(sb, sub_str);
            } else {
                skip = true;
            }
            if !skip {
                print_indents(indent_level, sb);
                print_to_builder(sb, "}");
            }
        case .POINTER;
            print("TODO: skipping wbml serialize POINTER for %\n", dbgname);
        case;
            panic(tprint("%: % (%)", name, ti.type, dbgname));
    }

    if !skip
        print_to_builder(sb, "\n");

    return !skip || any_child_worked;
}

deserialize :: inline ($T: Type, data: string) -> T {
    t: T;
    deserialize(data, *t);
    return t;
}

deserialize :: (data: string, ptr: *$Type, on_deserialize: On_Deserialize_Func = default_on_deserialize, userdata: *void = null) {
    ti := type_info(Type);
    lexer := laas.make_lexer(data);
    root := parse_value(*lexer, false);
    if root == null {
        assert(root != null, tprint("error parsing: %", data));
    }

    defer delete_node(root);
    write_value(root, ptr, ti, "<root>", on_deserialize=on_deserialize, userdata=userdata);
}

parse_value :: (lexer: *laas.Lexer, is_negative_number := false, loc := #caller_location) -> *Node {
	eat_newlines(lexer);
	root_token: laas.Token;
	ok := laas.get_next_token(lexer, *root_token);
	if !ok return null;

	if root_token.kind == .Symbol
		if root_token.text == "-"
			return parse_value(lexer, !is_negative_number);

    knd := root_token.kind;
	if knd == {
		case .Symbol;
            txt := root_token.text;
			if txt == {
				case "{";
					fields: [..]Object_Field;
					while true {
						eat_newlines(lexer);

						// check for end
						{
							next_token: laas.Token;
							ok := laas.peek(lexer, *next_token);
							assert(ok, "end of text from within object");
							if next_token.text == "}" {
								laas.eat(lexer);
								break;
							}
						}

						var_name_token: laas.Token;
						ok := laas.get_next_token(lexer, *var_name_token);
						assert(ok, "end of text from within object");
						assert(lexer.lex_idx < lexer.lexer_text.count);
                        if var_name_token.kind != .Identifier {
                            assert(var_name_token.kind == .Identifier,
                                tprint("expected an Identifier but got %\n%", var_name_token, <<lexer));
                        }

						value := parse_value(lexer);

                        field: Object_Field;
						array_add(*fields, make_Object_Field(var_name_token.text, value));
					}

                    node := Node.{type = .Object};
                    node._object.fields = fields;
					return new_clone(node);

				case "[";
					elements: [..]*Node;
					while true {
						eat_newlines(lexer);

						// check for end
						{
							next_token: laas.Token;
							ok := laas.peek(lexer, *next_token);
							assert(ok, "end of text from within array");
							if next_token.text == "]" {
								laas.eat(lexer);
								break;
							}
						}

						element := parse_value(lexer);
						array_add(*elements, element);
					}

                    node := Node.{type = .Array};
                    node._array.elements = elements;
					return new_clone(node);

				case ".";
					type_token: laas.Token;
					ok := laas.get_next_token(lexer, *type_token);
					assert(ok);
					assert(type_token.kind == .Identifier);

					value := parse_value(lexer);

                    node := Node.{type = .Union};
                    node._union.variant_name = type_token.text;
                    node._union.value = value;
					return new_clone(node);

				case;
					panic(tprint("Unhandled case: '%'", root_token.text));
			}

		// primitives
		case .String;
			str, length := unescape_string(root_token.text);
            node := Node.{type = .String};
            node._string = str;
			return new_clone(node);

		case .Identifier;
			if root_token.text == {
				case "true"; #through;
                case "True"; #through;
                case "TRUE";
                    node := Node.{type = .Bool};
                    node._bool.value = true;
                    return new_clone(node);
				case "false"; #through;
                case "False"; #through;
                case "FALSE";
                    node := Node.{type = .Bool};
                    node._bool.value = false;
                    return new_clone(node);
				case "nil";
                    return new_clone(Node.{type = .Nil});
				case "quat"; // :HashDirectives
					w := parse_value(lexer); assert(w.type == .Number);
					x := parse_value(lexer); assert(x.type == .Number);
					y := parse_value(lexer); assert(y.type == .Number);
					z := parse_value(lexer); assert(z.type == .Number);
                    node := Node.{type = .Quat};
                    node._quat.w = w;
                    node._quat.x = x;
                    node._quat.y = y;
                    node._quat.z = z;
					return new_clone(node);
				case;
                    node := Node.{type = .Enum_Value};
                    node._enum = root_token.text;
                    return new_clone(node);
			}

		case .Number;
			sign: s64 = ifx is_negative_number then -1 else 1;
			s64_value, ok1 := string_to_int(root_token.text); assert(ok1);
			u64_value, ok2 := string_to_int(root_token.text); assert(ok2); // TODO: string_to_uint function
			float64_value, ok3 := string_to_float64(root_token.text); assert(ok3);

            node := Node.{type = .Number};
            node._number.int_value = s64_value * sign;
            node._number.uint_value = cast(u64)(cast(s64)u64_value * sign);
            node._number.float_value = float64_value * cast(float64)sign;
            node._number.value_str = sprint((ifx is_negative_number then "-%" else "%"), root_token.text);
			return new_clone(node);
		case;
			panic(tprint("%", root_token));
	}

	unreachable();
    return null;
}


deep_copy :: (node: *Node) -> *Node {
    dest := New(Node);
    _deep_copy_internal(dest, node);
    return dest;
}

_deep_copy_internal :: (dest: *Node, source: *Node) {
    t := source.type;
    dest.type = t;
    if t == {
		case .Number;
            dest._number = source._number;
            dest._number.value_str = copy_string(source._number.value_str);
		case .Bool;
            dest._bool = source._bool;
		case .Nil;
		case .String;
            dest._string = copy_string(source._string);
		case .Enum_Value;
            dest._enum = copy_string(source._enum);
		case .Object;
            fields: [..]Object_Field;
            for * source._object.fields {
                new_field_entry: Object_Field;
                new_field_entry.name = copy_string(it.name);
                new_field_entry.value = deep_copy(it.value);
                array_add(*fields, new_field_entry);
            }
            dest._object.fields = fields;
		case .Array;
            elems: [..]*Node;
            for source._array.elements
                array_add(*elems, deep_copy(it));
            dest._array.elements = elems;
		case .Union;
            unreachable();
		case .Quat;
            unreachable();
		case;
			assert(false, tprint("%", dest.type));
    }
}

fields_with_prototype :: (object_node: *Node_Object) -> [..]Object_Field {
    fields: [..]Object_Field;
    fields.allocator = __temporary_allocator;

    field_names: [..]string;
    field_names.allocator = __temporary_allocator;

    for object_node.fields {
        array_add(*fields, it);
        array_add(*field_names, it.name);
    }
    if object_node.prototype != null {
        for object_node.prototype.fields {
            if array_add_if_unique(*field_names, it.name)
                array_add(*fields, it);
        }
    }
    return fields;
}

delete_node :: (node: *Node) {
    // TODO: use a "I own my strings" flag to see whether we free things or not. or
    // add a "free_strings" argument to this function?
	if node.type == {
		case .Number;     // do nothing
            free(node._number.value_str); // @Leak
		case .Bool;       // do nothing
		case .Nil;        // do nothing
		case .String;     // do nothing, strings are slices from source text
		case .Enum_Value; // do nothing, strings are slices from source text
		case .Object;
			for * node._object.fields
				delete_node(it.value);
			free(node._object.fields.data);
		case .Array;
			for node._array.elements
				delete_node(it);
			free(node._array.elements.data);
		case .Union;
			delete_node(node._union.value);
		case .Quat;
			delete_node(node._quat.w);
			delete_node(node._quat.x);
			delete_node(node._quat.y);
			delete_node(node._quat.z);
		case;
			panic(tprint("%", node.type));
    }
	free(node);
}

write_value :: inline (node: *Node, ptr: *$T, debug_string: string = "", verbose := false, on_deserialize: On_Deserialize_Func = default_on_deserialize, userdata: *void = null) {
    write_value(node, ptr, type_info(T), debug_string, verbose, on_deserialize);
}

//
// Given a WBML node, write its values recursively into a thing in memory.
//
write_value :: (node_incoming: *Node, ptr: *void, ti: *Type_Info,
    debug_name: string = "",
    verbose := false,
    on_deserialize: On_Deserialize_Func = default_on_deserialize,
    userdata: *void = null
    // TODO: this argument list is getting too long and probably needs an Options
    // struct.
) {
    assert(node_incoming != null, "write_value: node must be non-null");

    // @Speed
    // Here we deep copy the node since on_deserialize may modify it. really
    // that seems like too much for what we're trying to allow to happen, which
    // is that on_deserialize may remove an object field name, since it already handled it.
    // maybe instead we can have on_deserialize tell us which fields to split?
    node := deep_copy(node_incoming);
    defer delete_node(node);

    any := make_Any(ti, ptr);
    if on_deserialize(*any, node, userdata) return;

    if (ti.type) == {
        case .STRUCT;
            if check_type(node, .Object, verbose, debug_name) {
                ti_struct := cast(*Type_Info_Struct)ti;
                for field: fields_with_prototype(*node._object)
                    for ti_struct.members
                        if it.name == field.name {
                            child_debug_name := debug_name;
                            #if BUILD_DEBUG_NAMES
                                child_debug_name = tprint("%.%", debug_name, it.name);
                            write_value(field.value, ptr + it.offset_in_bytes, it.type,
                                child_debug_name, verbose, on_deserialize, userdata);
                        }

		case .ARRAY;
            if check_type(node, .Array, verbose, debug_name) {
                ti_array := cast(*Type_Info_Array)ti;
                elem_size := ti_array.element_type.runtime_size;
                assert(ti_array.relative_pointer_size == 0, "TODO: implement relative pointers");
                if ti_array.array_type == {
                    case .FIXED;
                        assert(ti_array.array_count != -1);
                        assert(node._array.elements.count == ti_array.array_count, "expected array count to match: % vs %",
                            node._array.elements.count, ti_array.array_count);
                        for node._array.elements {
                            child_debug_name := debug_name;
                            #if BUILD_DEBUG_NAMES child_debug_name = tprint("%[%]", debug_name, it_index);
                            write_value(it, ptr + it_index * elem_size, ti_array.element_type, child_debug_name, verbose, on_deserialize, userdata);
                        }
                    case .VIEW;
                        if ti_array.relative_pointer_size == {
                            case 0;
                                array := cast(*Resizable_Array)ptr;
                                assert(array.data == null, "TODO: what to do with the old slice data?");
                                desired_items := node._array.elements.count;
                                if desired_items == 0 {
                                    array.data = null;
                                    array.count = 0;
                                } else {
                                    array.data = cast(*void) realloc(array.data, desired_items * elem_size, array.count * elem_size);
                                    assert(array.data != null);
                                    array.count = desired_items;
                                    for node._array.elements {
                                        child_debug_name := debug_name;
                                        #if BUILD_DEBUG_NAMES child_debug_name = tprint("%[%]", debug_name, it_index);
                                        write_value(it, array.data + it_index * elem_size, ti_array.element_type, child_debug_name, verbose, on_deserialize, userdata);
                                    }
                                }
                            case;
                                assert(false, "TODO: relative pointer sizes for slices");
                        }
                    case .RESIZABLE;
                        array := cast(*Resizable_Array)ptr;
                        desired_items := node._array.elements.count;
                        if desired_items > array.allocated {
                            if !array.allocator {
                                if context.allocator {
                                    array.allocator      = context.allocator;
                                    array.allocator_data = context.allocator_data;
                                } else {
                                    array.allocator      = context.default_allocator;
                                }
                            }
                            array.data = realloc(array.data, desired_items * elem_size, array.allocated * elem_size, array.allocator, array.allocator_data);
                            assert(array.data != null);
                            array.allocated = desired_items;
                        }
                        array.count = desired_items;
                        if desired_items > 0
                            for node._array.elements {
                                child_debug_name := debug_name;
                                #if BUILD_DEBUG_NAMES child_debug_name = tprint("%[%]", debug_name, it_index);
                                write_value(it, array.data + it_index * elem_size, ti_array.element_type, child_debug_name, verbose, on_deserialize, userdata);
                            }
                }
            }
        case .STRING;
			// how to manage allocation? overwriting?
            if check_type(node, .String, verbose, debug_name) {
                <<cast(*string)ptr = copy_string(node._string);
            }
        case .BOOL;
            if check_type(node, .Bool, verbose, debug_name) {
                <<cast(*bool)ptr = node._bool.value;
            }
        case .INTEGER;
            if check_type(node, .Number, verbose, debug_name) {
                did_set := Reflection.set_value_from_string(any, node._number.value_str);
                if !did_set print("WARNING: set_value_from_string failed for setting integer % from %\n", debug_name, node._number.value_str);
            }
        case .FLOAT;
            if check_type(node, .Number, verbose, debug_name) {
                did_set := Reflection.set_value_from_string(any, node._number.value_str);
                if !did_set print("WARNING: set_value_from_string failed for setting float %\n", debug_name);
            }
		case .ENUM;
            if node.type == .Number {
                // Jai printer serializes 0 valued enums as '0', even if there's a named None.
                // we account for that here...perhaps we should only do it for zero? not sure.
                if !Reflection.set_value_from_string(any, node._number.value_str) {
                    if verbose
                        logprint("wbml", "failed setting number '%' as enum %", node._number.value_str, any);
                }
            } else if check_type(node, .Enum_Value, verbose, debug_name) {
                did_set := Reflection.set_value_from_string(any, node._enum);
                if !did_set logprint("wbml", "WARNING: set_value_from_string failed for % % (node enum was %)\n", debug_name, (<<any.type), node._enum);
            }
        case;
            logprint("wbml", "unhandled: '%' %", debug_name, ti.type);
    }
}

run_tests :: run_tests;

// #run run_tests();

#scope_file

should_serialize_struct_member :: (it: *Type_Info_Struct_Member, seen_offsets: *[..]int) -> bool {
    if it.flags & .CONSTANT
        return false;

    for note: it.notes
        if note == "noserialize"
            return false;

    if !array_add_if_unique(seen_offsets, it.offset_in_bytes) {
        // we skip #place directives by ignoring fields which are at byte
        // offsets we've already seen.
        return false;
    }

    return true;
}


make_Object_Field :: (name: string, value: *Node) -> Object_Field {
    field: Object_Field;
    field.name = name;
    field.value = value;
    return field;
}


unescape_string :: (str: string, allocator := context.allocator) -> (string, int) {
    length := str.count;

    escape := false;

    sb: String_Builder;
    sb.allocator = allocator;

    for c: cast([]u8)str {
        if !escape {
            if c == {
                case #char "\\"; escape = true; length -= 1;

				case;

				// TODO: there has to be a better way to print a character
				s: string;
				s.data = *c;
				s.count = 1;
                print_to_builder(*sb, "%", s);
            }
        }
        else {
            escape = false;
            if c == {
                case #char "\"";  print_to_builder(*sb, "\\\"");
                case #char "\\";  print_to_builder(*sb, "\\\\");
                case #char "b";   print_to_builder(*sb, "\\b");
                case #char "f";   print_to_builder(*sb, "\\f");
                case #char "n";   print_to_builder(*sb, "\\n");
                case #char "r";   print_to_builder(*sb, "\\r");
                case #char "t";   print_to_builder(*sb, "\\t");
                case; panic(tprint("Unexpected escape character: %", c));
            }
        }
    }
    assert(escape == false, "end of string from within escape sequence");

    escaped := builder_to_string(*sb);
    return escaped, length;
}


#import "Any";
#import "Compiler";
Reflection :: #import "Reflection";
laas :: #import "laas";
String :: #import "String";
#import "Basic";
#import "Hash_Table";

print_indents :: inline (indent_level: int, sb: *String_Builder) {
    for i: 0..indent_level-1
        append(sb, "\t");
}

new_clone :: inline (data: $T) -> *T {
	ptr := cast(*T)alloc(size_of(T));
	if ptr != null {
        (<< ptr) = data;
    }
	return ptr;
}

panic :: (msg: string, args: ..Any, loc := #caller_location) { // TODO
	print("%\n", loc);
    assert(false, tprint(msg, ..args));
}

unreachable :: () {
    // TODO
    panic("unreachable");
}


eat_newlines :: (lexer: *laas.Lexer) {
    token: laas.Token;

    while true {
        ok := laas.peek(lexer, *token);
        if !ok return;

        if token.kind == .New_Line
            laas.eat(lexer);
        else
            return;
    }
}

check_type :: (node: *Node, type: Node.Type, verbose: bool, debug_name := "") -> bool {
    if node.type == type
        return true;
    
    if verbose
        logprint("wbml", "warning: node was %, expected .% for %", node.type, type, debug_name);
    return false;
}

make_Any :: (type: *Type_Info, value_pointer: *void) -> Any {
    any: Any;
    any.type = type;
    any.value_pointer = value_pointer;
    return any;
}

strip_trailing_decimal_zeros :: (s: *string) {
    // TODO: just format the damn float differently....
    // TODO: international decimal points may not be "."
    if String.last_index_of_char(<<s, #char ".") == -1 return;
    while String.ends_with(<<s, "0") s.count -= 1;
    if String.ends_with(<<s, ".") s.count -= 1;
}

run_tests :: () {
    len :: (a: []$A) -> int { return a.count; }

	Int_Enum :: enum int {
		Foo;
		Bar;
		Baz;
	};

	Byte_Enum :: enum u8 {
		Qwe;
		Asd;
		Zxc;
	};

	Foo :: struct {
		x: float;
        y: float;
        z: float;
	};

	Bar :: struct {
		str: string;
		big_bool: bool;
	};

	Nightmare :: struct {
		some_int: int;
		some_string: string;
		some_float: float64;
		some_bool: bool;
		some_unserialized_thing: int; @noserialize
		enum1: Int_Enum;
		enum2: Byte_Enum;
		some_nested_thing: struct {
			asd: float;
			super_nested: struct {
				blah: string;
			};
			some_array: [4]string;
			dyn_array: [..]bool;
			slice: []struct {
				x: float64;
                y: float64;
			};
		};
		empty_dynamic_array: [..]Foo;
		missing_dynamic_array: [..]Foo;
		empty_slice: []Foo;
		missing_slice: []Foo;
	};

	source := #string END
{
	some_int 123
	some_string "henlo lizer"
	some_float 123.400
	some_bool true
	enum1 Baz
	enum2 Asd
	some_nested_thing {
		asd 432.500
		super_nested {
			blah "super nested string"
		}
		some_array [
			"123"
			"qwe"
			"asd"
			"zxc"
		]
		dyn_array [
			true
			false
			false
			true
		]
		slice [
			{
				x 12.000
				y 34.000
			}
			{
				x 43.000
				y 21.000
			}
		]
	}

	empty_dynamic_array [

	]

	empty_slice [

	]
}
END;

	a := deserialize(Nightmare, source);

	assert(a.some_int == 123, tprint("%", a.some_int));
	assert(a.some_string == "henlo lizer", tprint("expected a string, got: '%'", a.some_string));
	assert(a.some_float == 123.4, tprint("%", a.some_float));
	assert(a.some_bool == true, tprint("%", a.some_bool));

	assert(a.enum1 == .Baz, tprint("%", a.enum1));
	assert(a.enum2 == .Asd, tprint("%", a.enum2));

/*
	if str, ok := a.some_union.(string); ok {
		assert(str == "foo", tprint(str));
	}
	else {
		assert(false, tprint("some_union wasn't a string: ", a.some_union));
	}

	if foo, ok := a.union_foo.(Foo); ok {
		assert(foo.x == 1, tprint(foo));
		assert(foo.y == 4, tprint(foo));
		assert(foo.z == 9, tprint(foo));
	}
	else {
		assert(false, tprint("union_foo wasn't a Foo: ", a.union_foo));
	}

	if bar, ok := a.union_bar.(Bar); ok {
		assert(bar.str == "bar string", tprint(bar));
		assert(bar.big_bool == true, tprint(bar));
	}
	else {
		assert(false, tprint("union_bar wasn't a Bar: ", a.union_bar));
	}
    */

	assert(a.some_unserialized_thing == 0);

	assert(a.some_nested_thing.asd == 432.500, tprint("%", a.some_nested_thing.asd));//tprintf("%.8f", a.some_nested_thing.asd));
	assert(a.some_nested_thing.super_nested.blah == "super nested string", tprint(a.some_nested_thing.super_nested.blah));

	assert(len(a.some_nested_thing.some_array) == 4, tprint("%", len(a.some_nested_thing.some_array)));
	assert(a.some_nested_thing.some_array[0] == "123", tprint("%", a.some_nested_thing.some_array[0]));
	assert(a.some_nested_thing.some_array[1] == "qwe", tprint("%", a.some_nested_thing.some_array[1]));
	assert(a.some_nested_thing.some_array[2] == "asd", tprint("%", a.some_nested_thing.some_array[2]));
	assert(a.some_nested_thing.some_array[3] == "zxc", tprint("%", a.some_nested_thing.some_array[3]));

	assert(len(a.some_nested_thing.dyn_array) == 4, tprint("expected count to be 4: %", len(a.some_nested_thing.dyn_array)));
	assert(a.some_nested_thing.dyn_array[0] == true, tprint("%", a.some_nested_thing.dyn_array[0]));
	assert(a.some_nested_thing.dyn_array[1] == false, tprint("%", a.some_nested_thing.dyn_array[1]));
	assert(a.some_nested_thing.dyn_array[2] == false, tprint("%", a.some_nested_thing.dyn_array[2]));
	assert(a.some_nested_thing.dyn_array[3] == true, tprint("%", a.some_nested_thing.dyn_array[3]));

	assert(len(a.some_nested_thing.slice) == 2, tprint("expected slice % to have 2 count: %", 
		a.some_nested_thing.slice.data, len(a.some_nested_thing.slice)));
	assert(a.some_nested_thing.slice[0].x == 12, tprint("%", a.some_nested_thing.slice[0].x));
	assert(a.some_nested_thing.slice[0].y == 34, tprint("%", a.some_nested_thing.slice[0].y));
	assert(a.some_nested_thing.slice[1].x == 43, tprint("%", a.some_nested_thing.slice[1].x));
	assert(a.some_nested_thing.slice[1].y == 21, tprint("%", a.some_nested_thing.slice[1].y));

	assert(a.empty_dynamic_array.data == null, tprint("%", a.empty_dynamic_array));
	assert(len(a.empty_dynamic_array) == 0, tprint("%", len(a.empty_dynamic_array)));
	assert(a.empty_slice.data == null, tprint("%", a.empty_slice));
	assert(len(a.empty_slice) == 0, tprint("%", len(a.empty_slice)));

	a_text := serialize(*a);
	defer free(a_text);
	b := deserialize(Nightmare, a_text);

	assert(a.some_int == b.some_int, tprint("expected equal: % %", a.some_int, b.some_int));
	assert(a.some_string == b.some_string);
	assert(a.some_float == b.some_float);
	assert(a.some_bool == b.some_bool);

	assert(a.enum1 == b.enum1);
	assert(a.enum2 == b.enum2);

/*
	if str, ok := b.some_union.(string); ok {
		assert(str == a.some_union.(string));
	}
	else {
		assert(false, tprint("some_union wasn't a string: ", b.some_union));
	}

	if foo, ok := b.union_foo.(Foo); ok {
		assert(foo.x == a.union_foo.(Foo).x);
		assert(foo.y == a.union_foo.(Foo).y);
		assert(foo.z == a.union_foo.(Foo).z);
	}
	else {
		assert(false, tprint("union_foo wasn't a Foo: ", b.union_foo));
	}

	if bar, ok := b.union_bar.(Bar); ok {
		assert(bar.str      == a.union_bar.(Bar).str);
		assert(bar.big_bool == a.union_bar.(Bar).big_bool);
	}
	else {
		assert(false, tprint("union_foo wasn't a Foo: ", b.union_foo));
	}
    */

	assert(a.some_nested_thing.asd == b.some_nested_thing.asd);
	assert(a.some_nested_thing.super_nested.blah == b.some_nested_thing.super_nested.blah);

	assert(len(a.some_nested_thing.some_array) == len(b.some_nested_thing.some_array));
	assert(len(a.some_nested_thing.some_array) == 4);
	assert(a.some_nested_thing.some_array[0] == b.some_nested_thing.some_array[0]);
	assert(a.some_nested_thing.some_array[1] == b.some_nested_thing.some_array[1]);
	assert(a.some_nested_thing.some_array[2] == b.some_nested_thing.some_array[2]);
	assert(a.some_nested_thing.some_array[3] == b.some_nested_thing.some_array[3]);

	assert(len(a.some_nested_thing.dyn_array) == len(b.some_nested_thing.dyn_array));
	assert(len(a.some_nested_thing.dyn_array) == 4);
	assert(a.some_nested_thing.dyn_array[0] == b.some_nested_thing.dyn_array[0]);
	assert(a.some_nested_thing.dyn_array[1] == b.some_nested_thing.dyn_array[1]);
	assert(a.some_nested_thing.dyn_array[2] == b.some_nested_thing.dyn_array[2]);
	assert(a.some_nested_thing.dyn_array[3] == b.some_nested_thing.dyn_array[3],
		tprint("expected dyn_array elems [3] to be equal: % vs %",
			a.some_nested_thing.dyn_array[3],
			b.some_nested_thing.dyn_array[3],

		));

	assert(len(a.some_nested_thing.slice) == len(b.some_nested_thing.slice));
	assert(len(a.some_nested_thing.slice) == 2);
	assert(a.some_nested_thing.slice[0].x == b.some_nested_thing.slice[0].x);
	assert(a.some_nested_thing.slice[0].y == b.some_nested_thing.slice[0].y);
	assert(a.some_nested_thing.slice[1].x == b.some_nested_thing.slice[1].x);
	assert(a.some_nested_thing.slice[1].y == b.some_nested_thing.slice[1].y);

	assert(a.empty_dynamic_array.data == null, tprint("%", a.empty_dynamic_array));
	assert(len(a.empty_dynamic_array) == 0, tprint("%", len(a.empty_dynamic_array)));
	assert(a.empty_slice.data == null, tprint("%", a.empty_slice));
	assert(len(a.empty_slice) == 0, tprint("%", len(a.empty_slice)));

	assert(b.empty_dynamic_array.data == null, tprint("%", b.empty_dynamic_array));
	assert(len(b.empty_dynamic_array) == 0, tprint("%", len(b.empty_dynamic_array)));
	assert(b.empty_slice.data == null, tprint("%", b.empty_slice));
	assert(len(b.empty_slice) == 0, tprint("%", len(b.empty_slice)));

    // check that @noserialize members are skipped
    {
        Meep :: struct {
            yes: int;
            no: int; @noserialize
        }
        m := Meep.{yes = 42, no = 99};
        meep_str := serialize(*m);
        m2 := deserialize(Meep, meep_str);
        assert(m2.yes == 42);
        assert(m2.no == 0, "the 'no' field should not have been serialized b/c of note @noserialized:\n\n%", meep_str);
    }

    // check that default values are skipped
    {
        Vec3 :: struct { x: float; y: float; z: float; }

        My_Enum :: enum { ItemA :: 5004; ItemB :: 5005; }

        Thing_With_Defaults :: struct {
            a := Vec3.{0, 1, 0};
            b := "bar";
            c := My_Enum.ItemA;
        }

        t: Thing_With_Defaults;
        t_str := serialize(*t);
        print("Thing_With_Defaults:\n%\n", t_str);
        if t_str != "{\n}\n" {
            print("ERROR: %\n", tprint("'%' vs '%'", t_str, "{\n}\n"));
            assert(false);
        }

        v: Vec3 = .{ 4, 5, 6};
        print("%\n%\n", v, serialize(*v));

        Blah :: struct {
            arr: [..]int;
        }

        b: Blah;
        print("Blah: %\n", serialize(*b));
    }

	print("wbml tests done!\n");
}
