// Ported from the MIT licensed "workbench" project by @JoshuaManton
// https://github.com/JoshuaManton/workbench

#import "Basic";
#import "Hash_Table";
#import "Any";
#import "Compiler";
Reflection :: #import "Reflection";

#scope_file

laas :: #import "laas";

_type_info_table: Table(string, Type_Info);

panic :: (msg: string, args: ..Any) { // TODO
    assert(false, tprint(msg, ..args));
}

#scope_module

serialize :: (value: *$Type) -> string {
    return serialize_ti(value, type_info(Type));
}

serialize_ti :: (ptr: *void, ti: *Type_Info) -> string {
    sb: String_Builder;
    serialize_string_builder_ti(ptr, ti, *sb);
    return builder_to_string(*sb);
}

serialize_string_builder_ti :: (value: *void, ti: *Type_Info, sb: *String_Builder) {
    serialize_with_type_info("", value, ti, sb, 0);
}

serialize_with_type_info :: (name: string, value: *void, ti: *Type_Info, sb: *String_Builder, indent_level: int) {
    assert(ti != null);

    print_indents :: inline (indent_level: int, sb: *String_Builder) {
        for i: 0..indent_level-1
            append(sb, "\t");
    }

    if name != ""
        print_to_builder(sb, tprint("% ", name));

    do_newline := true;

    t := ti.type;
    if t == {
        case .INTEGER; #through;
        case .FLOAT; #through;
        case .BOOL; #through;
        case .STRING;
            item: Any;
            item.type = ti;
            item.value_pointer = value;
            print_item_to_builder(sb, item);
        case .STRUCT;
            print_to_builder(sb, "{\n"); indent_level += 1;
            for * (cast(*Type_Info_Struct)ti).members {
                print_indents(indent_level, sb);
                serialize_with_type_info(it.name, value + it.offset_in_bytes, it.type, sb, indent_level);
            }
            indent_level -= 1; print_indents(indent_level, sb); print_to_builder(sb, "}");
        case;
            panic(tprint(name, ti.type));

    }

    if do_newline
        print_to_builder(sb, "\n");

}

deserialize_to_value :: inline ($T: Type, data: string) -> T {
    t: T;
    deserialize_into_pointer(data, *t);
    return t;
}

deserialize_into_pointer :: (data: string, ptr: *$Type) {
    ti := type_info(Type);
    lexer := laas.make_lexer(data);
    root := parse_value(*lexer, false);
    defer delete_node(root);
    write_value(root, ptr, ti);

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
						assert(var_name_token.kind == .Identifier);

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

                    node: Node;
                    node.type = .Array;
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
            node._string.value = str;
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
                    node._enum.value = root_token.text;
                    return new_clone(node);
			}

		case .Number;
			sign: s64 = ifx is_negative_number then -1 else 1;
			s64_value, ok1 := string_to_int(root_token.text); assert(ok1);
			u64_value, ok2 := string_to_int(root_token.text); assert(ok2); // TODO: string_to_uint function
			float64_value, ok3 := string_to_float64(root_token.text); assert(ok3);

            node := Node.{type = .Number};
            node._number.source_str = root_token.text;
            node._number.int_value = s64_value * sign;
            node._number.uint_value = cast(u64)(cast(s64)u64_value * sign);
            node._number.float_value = float64_value * cast(float64)sign;
			return new_clone(node);
		case;
			panic(tprint("%", root_token));
	}
	unreachable();
    return null;
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
		_string: Node_String;
		_nil: Node_Nil;
		_enum: Node_Enum_Value;
		_object: Node_Object;
		_array: Node_Array;
		_union: Node_Union;
		_quat: Node_Quat;
	};
}

Node_Number :: struct {
    source_str: string;
	int_value: s64;
	uint_value: u64;
	float_value: float64;
}

Node_String :: struct {
	value: string;
}

Node_Bool :: struct {
	value: bool;
}

Node_Enum_Value :: struct {
	value: string;
}

Node_Nil :: struct {
}

Node_Object :: struct {
	fields: []Object_Field;
}

Object_Field :: struct {
	name: string;
	value: *Node;
}

make_Object_Field :: (name: string, value: *Node) -> Object_Field {
    field: Object_Field;
    field.name = name;
    field.value = value;
    return field;
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

new_clone :: inline (data: $T) -> *T {
	ptr := cast(*T)alloc(size_of(T));
	if ptr != null {
        (<< ptr) = data;
    }
	return ptr;
}


delete_node :: (node: *Node) {
	if node.type == {
		case .Number;     // do nothing
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

write_value :: (node: *Node, ptr: *$T) {
    ti := type_info(T);
    write_value(node, ptr, ti);
}

write_value :: (node: *Node, ptr: *void, ti: *Type_Info) {
    any: Any;
    any.type = ti;
    any.value_pointer = ptr;

    t := ti.type;
    if t == {
        case .STRUCT;
            object := *node._object;
            for field: object.fields {
                for member: (cast(*Type_Info_Struct)ti).members {
                    if member.name == field.name {
                        field_ptr := ptr + member.offset_in_bytes;
                        field_ti := member.type;
                        write_value(field.value, field_ptr, field_ti);
                    }
                }
            }
        case .INTEGER;
            Reflection.set_value_from_string(any, node._number.source_str);
        case .FLOAT;
            Reflection.set_value_from_string(any, node._number.source_str);
        case .STRING;
            temp := tprint("\"%\"", node._string.value);
            Reflection.set_value_from_string(any, temp); // TODO: XXX nono no
        case .BOOL;
            Reflection.set_value_from_string(any, ifx node._bool.value then "true" else "false"); // TODO XXX Nononono
            


        case;
            print("unhandled: %\n", ti.type);
    }
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
                case; print_to_builder(*sb, "%", c);
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
