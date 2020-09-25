// originally ported from the MIT licensed "workbench" project by @JoshuaManton
// https://github.com/JoshuaManton/workbench

// TODO:
// use initializer_of to skip writing struct field values if they are
// still set to their defaults

#import "Basic";
#import "Hash_Table";

#scope_module

serialize :: (value: *$Type) -> string {
    return serialize_ti(value, type_info(Type));
}

serialize_ti :: (ptr: *void, ti: *Type_Info, debug_name := "") -> string {
    sb: String_Builder;
    serialize_string_builder_ti(ptr, ti, *sb, debug_name);
    return builder_to_string(*sb);
}

serialize_string_builder_ti :: (value: *void, ti: *Type_Info, sb: *String_Builder, debug_name := "") {
    serialize_with_type_info("", value, ti, sb, 0);
}

serialize_with_type_info :: (name: string, value: *void, ti: *Type_Info, sb: *String_Builder, indent_level: int, debug_name_ := "") {
    assert(ti != null);

    debug_name := debug_name_;
    if debug_name.count == 0 {
        if ti.type == .STRUCT
            debug_name = (cast(*Type_Info_Struct)ti).name;
        else
            debug_name = tprint("%", <<ti);
    }

    print_indents :: inline (indent_level: int, sb: *String_Builder) {
        for i: 0..indent_level-1
            append(sb, "\t");
    }

    name_and_space: string;
    if name != ""
        name_and_space = tprint("% ", name);

    do_newline := true;

	item: Any;
	item.type = ti;
	item.value_pointer = value;

    t := ti.type;
    if t == {
        case .BOOL;
            print_item_to_builder(sb, name_and_space);
			print_to_builder(sb, ifx (<< (cast(*bool)value)) then "true" else "false");
        case .INTEGER; #through;
        case .FLOAT; #through;
        case .ENUM;
            print_item_to_builder(sb, name_and_space);
            print_item_to_builder(sb, tprint("%", item));
        case .STRING;
            print_item_to_builder(sb, name_and_space);
            print_item_to_builder(sb, tprint("\"%\"", item)); // TODO: actually escape quotes in the string
		case .ARRAY;
            print_item_to_builder(sb, name_and_space);
			print_to_builder(sb, "[\n"); indent_level += 1;
			{
				ti_array := cast(*Type_Info_Array)ti;
				count, data := Reflection.get_array_count_and_data(value, ti_array);
				for i: 0..count-1 {
					elem_data := data + ti_array.element_type.runtime_size * i;
					print_indents(indent_level, sb);
					serialize_with_type_info("", elem_data, ti_array.element_type, sb, indent_level, tprint("%[%]", debug_name, i));
				}
			}
			indent_level -= 1; print_indents(indent_level, sb); print_to_builder(sb, "]");
        case .STRUCT;
            print_item_to_builder(sb, name_and_space);
            print_to_builder(sb, "{\n"); indent_level += 1;
            seen_offsets: [..]int;
            seen_offsets.allocator = __temporary_allocator;
            for * (cast(*Type_Info_Struct)ti).members {
                if !should_serialize_struct_member(it, *seen_offsets)
                    continue;
                print_indents(indent_level, sb);
                serialize_with_type_info(it.name, value + it.offset_in_bytes, it.type, sb, indent_level, tprint("%.%", debug_name, it.name));
            }
            indent_level -= 1; print_indents(indent_level, sb); print_to_builder(sb, "}");
        case .POINTER;
            print("TODO: skipping wbml serialize POINTER for %\n", debug_name);
        case;
            panic(tprint("%: % (%)", name, ti.type, debug_name));
    }

    if do_newline
        print_to_builder(sb, "\n");
}

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

deserialize :: inline ($T: Type, data: string) -> T {
    t: T;
    deserialize(data, *t);
    return t;
}

deserialize :: (data: string, ptr: *$Type) {
    ti := type_info(Type);
    lexer := laas.make_lexer(data);
    root := parse_value(*lexer, false);
    defer delete_node(root);
    write_value(root, ptr, ti, "<root>");
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
						assert(var_name_token.kind == .Identifier,
							tprint("expected an Identifier but got %\n%", var_name_token, <<lexer));

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
		_nil: Node_Nil;
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

Node_String :: struct {
	value: string;
}

Node_Bool :: struct {
	value: bool;
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

write_value :: inline (node: *Node, ptr: *$T, debug_string: string = "") {
    write_value(node, ptr, type_info(T), debug_string);
}

write_value :: (node: *Node, ptr: *void, ti: *Type_Info, debug_name: string = "") {
    any: Any = ---;
    any.type = ti;
    any.value_pointer = ptr;

    t := ti.type;
    if t == {
        case .STRUCT;
            if node.type == .Object {
                for field: node._object.fields
                    for (cast(*Type_Info_Struct)ti).members
                        if it.name == field.name {
                            field_debug_name := tprint("%.%", debug_name, it.name);
                            write_value(field.value, ptr + it.offset_in_bytes, it.type, field_debug_name);
                        }
            }
		case .ARRAY;
            if node.type == .Array {
                ti_array := cast(*Type_Info_Array)ti;
                elem_size := ti_array.element_type.runtime_size;
                assert(ti_array.relative_pointer_size == 0, "TODO: implement relative pointers");
                if ti_array.array_type == {
                    case .FIXED;
                        assert(ti_array.array_count != -1);
                        assert(node._array.elements.count == ti_array.array_count, "expected array count to match: % vs %",
                            node._array.elements.count, ti_array.array_count);
                        for node._array.elements
                            write_value(it, ptr + it_index * elem_size, ti_array.element_type, tprint("%[%]", debug_name, it_index));
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
                                    for node._array.elements
                                        write_value(it, array.data + it_index * elem_size, ti_array.element_type, tprint("%[%]", debug_name, it_index));
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
                            for node._array.elements
                                write_value(it, array.data + it_index * elem_size, ti_array.element_type, tprint("%[%]", debug_name, it_index));
                }
            }
        case .STRING;
			// how to manage allocation? overwriting?
            if node.type == .String {
                <<cast(*string)ptr = copy_string(node._string);
            }
        case .BOOL;
            if node.type == .Bool {
                <<cast(*bool)ptr = node._bool.value;
            }
        case .INTEGER;
            if node.type == .Number {
                did_set := Reflection.set_value_from_string(any, node._number.value_str);
                if !did_set print("WARNING: set_value_from_string failed for setting integer % from %\n", debug_name, node._number.value_str);
            }
        case .FLOAT;
            if node.type == .Number {
                did_set := Reflection.set_value_from_string(any, node._number.value_str);
                if !did_set print("WARNING: set_value_from_string failed for setting float %\n", debug_name);
            }
		case .ENUM;
            if node.type == .Enum_Value {
                did_set := Reflection.set_value_from_string(any, node._enum);
                if !did_set print("WARNING: set_value_from_string failed for % % (node enum was %)\n", debug_name, (<<any.type), node._enum);
            }
        case;
            print("unhandled: '%' %\n", debug_name, ti.type);
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

run_tests :: run_tests;

#scope_file

#import "Any";
#import "Compiler";
String :: #import "String";
Reflection :: #import "Reflection";

new_clone :: inline (data: $T) -> *T {
	ptr := cast(*T)alloc(size_of(T));
	if ptr != null {
        (<< ptr) = data;
    }
	return ptr;
}

laas :: #import "laas";

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

	print("wbml tests done!\n");
}

