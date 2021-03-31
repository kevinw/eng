#placeholder USE_GENERATED_CLANG_BINDINGS;

STOP_ON_ERRORS :: true;

#if USE_GENERATED_CLANG_BINDINGS {
    #load "generated_clang.jai";
} else {
    // @Warning the original hand-written bindings no longer have enough of the libclang API in order to compile!
    #assert false "Can't compile with the hand-written binding because it doesn't declare enough of the libclang API!";
    #load "clang.jai";
}
Debug :: #import "Debug";
#import "Basic";
#import "Hash_Table";
#import "File";
#import "File_Utilities";
#import "String";

#if OS == .MACOS || OS == .LINUX {
    #import "POSIX";
}

Hash :: #import "Hash_Table";

#if OS == .WINDOWS {
    time_t :: s64;
    size_t :: s64;
    #import "Windows";
    #import "Windows_Utf8";
}

copy_and_dispose :: (str: CXString) -> string {
    temp := to_string(clang_getCString(str));
    copy := copy_string(temp);
    clang_disposeString(str);
    return copy;
}

get_children :: (cur: CXCursor) -> [..] CXCursor {
    child_visitor :: (cur: CXCursor, parent: CXCursor, client_data: CXClientData) -> CXChildVisitResult #c_call {
        new_context: Context;
        push_context new_context {
            arr := cast(*[..] CXCursor) client_data;
            array_add(arr, cur);
            return CXChildVisit_Continue;
        }
    }

    arr: [..] CXCursor;
    // set the alloctor so that we don't need a context for array_add
    arr.allocator = context.allocator;
    clang_visitChildren(cur, child_visitor, *arr);
    return arr;
}

get_hash_cxcursor :: (cur: CXCursor) -> u32 {
    return clang_hashCursor(cur);
}

compare_cxcursors :: (cur0: CXCursor, cur1: CXCursor) -> bool {
    return clang_equalCursors(cur0, cur1) != 0;
}

Number_Flags :: enum_flags {
    None;
    _8BIT;
    _16BIT;
    _32BIT;
    _64BIT;

    SIGNED;
    FLOAT;
}

CType :: struct {
    pointer_to: *CType;
    type_of_enum: *Enum;
    type_of_typedef: *Typedef;
    type_of_struct: *Struct;
    array_element_type: *CType;
    array_element_count := -1;

    function_argument_types: [..] *CType;
    function_return_type: *CType = null;

    number_flags: Number_Flags;
    size: s64 = -1;
}

C_Kind :: enum {
    None;
    DECLARATION;
    FUNCTION;
    ENUM;
    TYPEDEF;
    STRUCT;
    NAMESPACE;

    LITERAL;
}

Expression :: struct {
    kind: C_Kind;
}

Literal :: struct {
    using _expression: Expression;
    kind = .LITERAL;

    literal_kind: enum int {
        NULL    :: 0;
        INTEGER :: 1;
        FLOAT   :: 2;
        STRING  :: 3;
    };

    union {
        int_value:    s64;
        float_value:  float64;
        string_value: string;
    }
}

Declaration :: struct {
    using _expression: Expression;
    kind = .DECLARATION;
    name: string;
    type: *CType;
    expression: *Expression;

    qualifer_using := false;
    bitfield_width := -1;
}

Function :: struct {
    using declaration: Declaration;
    kind = .FUNCTION;

    arguments: [..] *Declaration;
    return_type: *CType;
    is_variadic := false;
    is_virtual := false;

    body: *Block;
    library: *Library_Info;

    foreign_function_name: string; // read: mangled name for linkage

    is_objc_binding := false;
    is_objc_class_method := false;
    objc_class_method_struct: *Struct;

    is_cpp_method := false;
    is_constructor := false;
}


// @Note Typedef.type is the type that this typedef binds to
Typedef :: struct {
    using declaration: Declaration;
    kind = .TYPEDEF;
}


// @Note Enum.type is the internal integer type of the enum
Enum :: struct {
    using declaration: Declaration;
    kind = .ENUM;

    Enumerate :: struct {
        name: string;
        value: u64;
    }
    enumerates: [..] Enumerate;
}

Type_Parameter :: struct {
    name: string;
    type: *CType;
}

Struct :: struct {
    using declaration: Declaration;
    kind = .STRUCT;

    vtable: [..] *Declaration;
    declarations: [..] *Declaration;
    template_type_params: [..] Type_Parameter;
    template_instantiation_params: [..] Type_Parameter; // TODO: can these be one list?
    do_not_print_anon: bool; // set when a declaration is typed an unnamed struct/union, so we don't try to emit the unnamed struct/union as an anonymous struct/union 
    flags: enum_flags {
        None;
        IS_ANON;
        IS_UNION;
    };
}

Namespace :: struct {
    using declaration: Declaration;
    kind = .NAMESPACE;

    declarations: [..] *Declaration;
}

Block :: struct {
    parent: *Block;
    members: [..] *Declaration;
    // statements: [] *Expression;
}

Library_Info :: struct {
    name: string;
    path: string; // This should be just what the user has passed to us via -l, I think
    is_system: bool;

    #if OS == .WINDOWS {
        handle: HMODULE;
    } else #if OS == .LINUX || OS == .MACOS {
        handle: *void;
    }
}

TAB_STRING :: "    ";

#add_context using compiler: struct {
    global_scope: Block;

    pointer_size: s64; // this should probably be queried from target info?
    anon_counter := 0;

    type_def_void: *CType;
    type_def_bool: *CType;

    type_def_u8: *CType;
    type_def_u16: *CType;
    type_def_u32: *CType;
    type_def_u64: *CType;

    type_def_s8: *CType;
    type_def_s16: *CType;
    type_def_s32: *CType;
    type_def_s64: *CType;

    type_def_float32: *CType;
    type_def_float64: *CType;

    type_def_ptr_void: *CType;

    type_def_objc_class: *CType;
    type_def_objc_selector: *CType;

    // cxtype_to_type_table: Table(CXType, *CType);
    cursor_to_decl_table: Table(CXCursor, *Declaration, get_hash_cxcursor, compare_cxcursors);

    unique_objc_selectors: [..] string;

    libraries: [..] *Library_Info;

    // settings
    c_enum_emulation := false; // use 'using' on each enum declaration to bring all its members into scope
    rename_functions_that_conflict_with_struct_names := true;
    generate_static_struct_size_checks := true;

    strip_prefix: string;
    strip_enum_prefixes := true;
    strip_enum_values_with_suffix: string;
    strip_enum_value_prefixes: [..]Pair(string);
    strip_hungarian_member_prefix := true;
    extra_file_scope_imports: [..]string;
    type_replacements: [..]Pair(string);
    strip_flags: Strip_Flags = Strip_Flags.Constructors | .Destructors | .Functions_With_Bodies | .Functions_With_valist | .Functions_With_Unknown_Foreign_Libs;

    // for printing functions
    tab_depth := 0;

    counts: struct {
        functions: u32;
        structs: u32;
    };
};

Strip_Flags :: enum_flags {
    Constructors;
    Destructors;
    Functions_With_Bodies;
    Functions_With_valist;
    Functions_With_Unknown_Foreign_Libs;
}

create_pointer_to :: (pointee: *CType) -> *CType {
    out := New(CType);
    out.size = context.pointer_size;
    out.pointer_to = pointee;
    return out;
}

create_type :: (ty: CXType, cur: CXCursor, loc := #caller_location) -> *CType {
    //print("create_type(ty=%, cur=%)\n", ty, cur);

    kind := ty.kind;

    if kind == {
        case CXType_ObjCObjectPointer; #through;
        case CXType_Pointer;
            pointee := create_type(clang_getPointeeType(ty), cur, loc=loc);
            if !pointee return null;

            return create_pointer_to(pointee);
        case CXType_LValueReference;
            pointee := create_type(clang_getPointeeType(ty), cur, loc=loc);
            if !pointee return null;
            
            out := New(CType);
            out.size = context.pointer_size;
            out.pointer_to = pointee;
            return out;
        case CXType_Void;
            return context.type_def_void;
        case CXType_Bool;
            return context.type_def_bool;

        case CXType_Char_U; #through;
        case CXType_UChar; #through;
        case CXType_Char16; #through;
        case CXType_Char32; #through;
        case CXType_UShort; #through;
        case CXType_UInt; #through;
        case CXType_ULong; #through;
        case CXType_ULongLong; #through;
        case CXType_UInt128;
            size := clang_Type_getSizeOf(ty);
            if size == 1 return context.type_def_u8;
            else if size == 2 return context.type_def_u16;
            else if size == 4 return context.type_def_u32;
            else if size == 8 return context.type_def_u64;

            error("Unhandled int size: %\n", size);
        case CXType_Char_S; #through;
        case CXType_SChar; #through;
        case CXType_WChar; #through;
        case CXType_Short; #through;
        case CXType_Int; #through;
        case CXType_Long; #through;
        case CXType_LongLong; #through;
        case CXType_Int128;
            size := clang_Type_getSizeOf(ty);
            if      size == 1 return context.type_def_s8;
            else if size == 2 return context.type_def_s16;
            else if size == 4 return context.type_def_s32;
            else if size == 8 return context.type_def_s64;

            error("Unhandled uint size: %\n", size);
        case CXType_Float; #through;
        case CXType_Double; #through;
        case CXType_LongDouble;
            size := clang_Type_getSizeOf(ty);
            if size == 4 return context.type_def_float32;
            else if size == 8 return context.type_def_float64;
            error("Unhandled float size: %\n", size);

            return null;
        case CXType_Elaborated;
            return create_type(clang_Type_getNamedType(ty), cur, loc=loc);
        case CXType_Enum;
            decl_cur := clang_getTypeDeclaration(ty);
            en := create_enum(decl_cur, true);

            out := New(CType);
            out.type_of_enum = en;
            out.size = clang_Type_getSizeOf(ty);
            return out;
        case CXType_Typedef;
            decl_cur := clang_getTypeDeclaration(ty);
            en := create_typedef(decl_cur, true);

            if en {
                out := New(CType);
                out.type_of_typedef = en;
                out.size = clang_Type_getSizeOf(clang_getCanonicalType(ty));
                return out;
            }

            return null;
        case CXType_ObjCObject; #through;
        case CXType_Record;
            decl_cur := clang_getTypeDeclaration(ty);
            en := create_struct(decl_cur, true);

            out := New(CType);
            out.type_of_struct = en;
            out.size = clang_Type_getSizeOf(ty);
            if out.size == -2 out.size = 0;
            return out;
        case CXType_ObjCInterface;
            decl_cur := clang_getTypeDeclaration(ty);
            en := create_objc_interface(decl_cur, true);

            out := New(CType);
            out.type_of_struct = en;
            out.size = clang_Type_getSizeOf(ty);
            if out.size == -2 out.size = 0;
            return out;
        case CXType_ConstantArray;
            ele := create_type(clang_getArrayElementType(ty), cur, loc=loc);
            if !ele return null;

            num_ele := clang_getNumElements(ty);

            out := New(CType);
            out.array_element_type = ele;
            out.array_element_count = num_ele;
            out.size = clang_Type_getSizeOf(ty);
            return out;
        case CXType_IncompleteArray;
            ele := create_type(clang_getArrayElementType(ty), cur, loc=loc);
            if !ele return null;
            // num_ele := clang_getNumElements(ty);

            out := New(CType);
            out.array_element_type = ele;
            out.size = clang_Type_getSizeOf(ty);
            return out;
        case CXType_FunctionProto;
            arg_count := clang_getNumArgTypes(ty);

            out := New(CType);
            for 0..arg_count-1 {
                mem := create_type(clang_getArgType(ty, cast(u32) it), cur, loc=loc);
                if !mem {
                    array_reset(*out.function_argument_types);
                    free(out);
                    return null;
                }

                array_add(*out.function_argument_types, mem);
            }
            out.function_return_type = create_type(clang_getResultType(ty), cur, loc=loc);

            if !out.function_return_type {
                array_reset(*out.function_argument_types);
                free(out);
                return null;
            }
            return out;

        case CXType_ObjCId;
            return context.type_def_ptr_void;

        case CXType_ObjCClass;
            return context.type_def_objc_class;

        case CXType_ObjCSel;
            return context.type_def_objc_selector;

        case CXType_Unexposed;
            // here we need to handle structs with template parameters, i.e. "template<typename T> struct Foo"
            // and also fields with template instantiation parameters, i.e., "Foo<int> myFoo;"


            Name_Context :: struct { name: string; jai_ctx: *Context; }
            template_type_spelling_context: Name_Context;
            my_visitor :: (cur: CXCursor, parent: CXCursor, client_data: CXClientData) -> CXChildVisitResult #c_call {
                name_context := cast(*Name_Context)client_data;
                push_context (<<name_context.jai_ctx) {
                    name_context.name = as_str(cur);
                }
                return .CXChildVisit_Recurse;
            }

            name_context: Name_Context;
            ctx := context;
            name_context.jai_ctx = *ctx;
            clang_visitChildren(cur, my_visitor, *name_context);

            if name_context.name.count == 0
                return null;

            //print("got template type name: %\n", name_context.name);

            out := New(CType);
            out.type_of_struct = New(Struct);
            out.type_of_struct.name = name_context.name; // TODO: dedupe?

            // get template instantiation parameters
            {
                type_decl := clang_getCursorType(cur);
                type_decl_cur := clang_getTypeDeclaration(type_decl);
                num_template_args := clang_Type_getNumTemplateArguments(type_decl);
                //print("       num template args for '%': %\n", name_context.name, num_template_args);
                for i: 0..num_template_args - 1 {
                    template_arg_type := clang_Type_getTemplateArgumentAsType(type_decl, cast(u32)i);
                    entry := array_add(*out.type_of_struct.template_instantiation_params);
                    entry.name = as_str(template_arg_type);
                    entry.type = create_type(template_arg_type, cur);
                }
            }

            return out;

        case CXType_Invalid;
            assert(false);
    }

    error("Unhandled CXTypeKind from %: %\n", loc, kind);
    return null;
}

print_indentation :: (builder: *String_Builder) {
    for 1..context.tab_depth append(builder, TAB_STRING);
}

type_tstring :: (ty: *CType) -> string {
    sb: String_Builder;
    sb.allocator = __temporary_allocator;
    print_type_to_builder(*sb, ty);
    return tprint("CType(ptr=%, size=%, %)", ty, ty.size, builder_to_string(*sb, __temporary_allocator));
}

print_type_to_builder :: (builder: *String_Builder, ty: *CType) {

    if ty.number_flags {
        using Number_Flags;
        flags := ty.number_flags;

        if flags & FLOAT {
            append(builder, "float");
            if flags & _32BIT append(builder, "32");
            else if flags & _64BIT append(builder, "64");
        } else {
            if flags & SIGNED append(builder, "s");
            else append(builder, "u");

            if flags & _8BIT append(builder, "8");
            else if flags & _16BIT append(builder, "16");
            else if flags & _32BIT append(builder, "32");
            else if flags & _64BIT append(builder, "64");
        }

        return;
    }

    if ty == context.type_def_bool {
        append(builder, "bool");
        return;
    }

    if ty == context.type_def_void {
        append(builder, "void");
        return;
    }

    if ty.pointer_to {
        // reduce a level of indirection and use the #type keyword!
        if ty.pointer_to.function_return_type {
            append(builder, "#type ");
        } else {
            append(builder, "*");
        }
        print_type_to_builder(builder, ty.pointer_to);
        return;
    }

    if ty.type_of_enum {
        if ty.type_of_enum.name {
            append(builder, stripped_name(ty.type_of_enum.name));
        } else {
            en := ty.type_of_enum;
            is_signed := (en.type.number_flags & Number_Flags.SIGNED);
            type_str := type_to_string(en.type);
            defer free(type_str);
            print_to_builder(builder, "enum % {\n", type_str);
            context.tab_depth += 1;
            for en.enumerates {
                print_indentation(builder);
                if is_signed print_to_builder(builder, "% :: %;\n", stripped_name(it.name), cast(s64) it.value);
                else print_to_builder(builder, "% :: %;\n", stripped_name(it.name), cast(u64) it.value);
            }
            context.tab_depth -= 1;

            print_indentation(builder);
            append(builder, "}");
        }

        return;
    }

    if ty.type_of_struct {
        if ty.type_of_struct.name && !(ty.type_of_struct.flags & ty.type_of_struct.flags.IS_ANON) {
            name := replace_typename(ty.type_of_struct.name);
            name = stripped_name(name);


            num_template_args := ty.type_of_struct.template_instantiation_params.count;


            append(builder, name);

            // print any template instantiation parameters in parens
            if num_template_args > 0 {
                append(builder, "(");
                defer append(builder, ")");

                for templ_arg: ty.type_of_struct.template_instantiation_params {
                    append(builder, type_to_string(templ_arg.type));
                    if it_index < ty.type_of_struct.template_instantiation_params.count - 1
                        append(builder, ", ");
                }
            }
        } else {
            str := ty.type_of_struct;

            type_name := "struct";
            if (str.flags & str.flags.IS_UNION) type_name = "union";

            print_to_builder(builder, "% {\n", type_name);
            context.tab_depth += 1;
            for str.declarations {
                print_declaration_to_builder(builder, it, in_struct=true);
            }
            context.tab_depth -= 1;

            append(builder, "\n");
            print_indentation(builder);
            append(builder, "}");
        }

        return;
    }

    if ty.array_element_type {
        if ty.array_element_count == - 1 {
            // incomplete array (in a function paramter <type>[]) so we transform this into *<type>
            append(builder, "*");
            print_type_to_builder(builder, ty.array_element_type);
        } else {
            append(builder, "[");
            if ty.array_element_count != -1 {
                print_to_builder(builder, "%", ty.array_element_count);
            } else {
                assert(false, "Handle -1 array_element_count");
            }
            append(builder, "] ");

            print_type_to_builder(builder, ty.array_element_type);
        }
        return;
    }

    if ty.function_return_type {
        append(builder, "(");
        
        for ty.function_argument_types {
            type_str := type_to_string(it);
            defer free(type_str);

            print_to_builder(builder, "a%: %", it_index, type_str);
            if it_index < ty.function_argument_types.count-1 append(builder, ", ");
        }

        return_str := type_to_string(ty.function_return_type);
        defer free(return_str);
        print_to_builder(builder, ") -> % #c_call", return_str);
        return;
    }

    if ty.type_of_typedef {
        append(builder, stripped_name(ty.type_of_typedef.name));
        return;
    }

    assert(false);
}

type_to_string :: (ty: *CType) -> string {
    builder: String_Builder;
    print_type_to_builder(*builder, ty);
    return builder_to_string(*builder);
}

as_str :: (cur: CXCursor) -> string { return copy_and_dispose(clang_getCursorSpelling(cur)); }
as_str :: (ty: CXType)    -> string { return copy_and_dispose(clang_getTypeSpelling(ty)); }

// variable or parameters
create_variable_declaration :: (cur: CXCursor, parent: CXCursor) -> *Declaration {
    kind := clang_getCursorKind(cur);
    assert(kind == CXCursor_ParmDecl || kind == CXCursor_VarDecl || kind == CXCursor_FieldDecl || kind == CXCursor_ObjCIvarDecl);

    bitfield_width := -1;
    if clang_Cursor_isBitField(cur) {
        bitfield_width = clang_getFieldDeclBitWidth(cur);
        //print("Warning: bitfields aren't supported in jai: (bitfield width: %)\n", bitfield_width);
    }

    print("create_variable_declaration % %\n", as_str(cur), cur);

    decl_type := create_type(clang_getCursorType(cur), cur);
    decl := _create_declaration(copy_and_dispose(clang_getCursorSpelling(cur)), decl_type);
    decl.bitfield_width = bitfield_width;

    children := get_children(cur);

    // It seems sometimes children can contain many elements. I dont yet know what the case is that causes this
    // assert(children.count <= 1);

    if children.count == 1 {
        value := create_literal(children[0]);
        if value decl.expression = value;
    }

    if !decl.type {
        error(cur, "could not create type for declaration. Discarding '%'.\n", copy_and_dispose(clang_getCursorSpelling(cur)));
        free(decl);
        return null;
    }

    type_of_struct := decl.type.type_of_struct;
    if type_of_struct && (type_of_struct.flags & type_of_struct.flags.IS_ANON) {
        type_of_struct.do_not_print_anon = true;
    }

    //print("Type: %\n", type_to_string(decl.type));
    return decl;
}

_create_declaration :: (name: string, type: *CType) -> *Declaration {
    decl := New(Declaration);
    decl.name = name;
    decl.type = type;
    return decl;
}

create_literal :: (cur: CXCursor) -> *Literal {
    lit := New(Literal);

    cursor_kind := clang_getCursorKind(cur);

    eval := clang_Cursor_Evaluate(cur);
    defer clang_EvalResult_dispose(eval);

    eval_kind := clang_EvalResult_getKind(eval);
    // print("KIND: %\n", eval_kind);

    if eval_kind == {
        case CXEval_Int;
            lit.literal_kind = .INTEGER;
            lit.int_value = clang_EvalResult_getAsLongLong(eval);

        case CXEval_Float;
            lit.literal_kind = .FLOAT;
            lit.float_value = clang_EvalResult_getAsDouble(eval);

        case CXEval_StrLiteral;
            lit.literal_kind = .STRING;
            c_str := clang_EvalResult_getAsStr(eval);
            lit.string_value = copy_string(to_string(c_str));

        case;
            // sigh, for whatever reason, nullptr is reported as Unexposed and the CXCursor kind is reported as
            // CXCursor_UnexposedExpr. I believe this is due to Clang using an internal cast to convert the nullptr type
            // to the type of whatever pointer you're assigning it to. Something similar seems to happen with float literals
            // where float a = 1.0; is reported as CXCursor_UnexposedExpr but float a = 1.0f; is reported as CXCursor_FloatLiteral; perhaps
            // there's an implicit cast that isnt exposed via libclang. -josh 5 February 2019

            free(lit);
            return null;
    }

    return lit;
}


// operates in-place
convert_objc_selector_name_to_function_identifier :: (s: *string) {
    for 0..s.count-1 {
        if s.data[it] == #char ":" {
            s.data[it] = #char "_";
        }
    }

    if s.count && (s.data[s.count-1] == #char "_") {
        s.count -= 1;
    }
}

create_function :: (cur: CXCursor, parent: CXCursor) -> *Function {
    kind := clang_getCursorKind(cur);
    assert(kind == CXCursor_FunctionDecl || kind == CXCursor_CXXMethod
            || kind == CXCursor_Constructor || kind == CXCursor_Destructor
            || kind == CXCursor_ObjCInstanceMethodDecl
            || kind == CXCursor_ObjCClassMethodDecl);

    /*if clang_CXXMethod_isVirtual(cur) {
        // @TODO basically hide this for now because we need to figure out vtable generation
        //return null;
    }*/

    func := New(Function);
    if kind == CXCursor_Constructor {
        func.name = copy_string("Constructor");
        func.is_constructor = true;
    } else if kind == CXCursor_Destructor {
        func.name = copy_string("Destructor");
    } else {
        func.name = copy_and_dispose(clang_getCursorSpelling(cur));
    }

    func.is_cpp_method = (kind == CXCursor_CXXMethod || kind == CXCursor_Constructor || kind == CXCursor_Destructor);

    if kind == CXCursor_ObjCInstanceMethodDecl || kind == CXCursor_ObjCClassMethodDecl {
        func.foreign_function_name = copy_string(func.name);
        convert_objc_selector_name_to_function_identifier(*func.name);
        func.is_objc_binding = true;
        array_add_if_unique(*context.unique_objc_selectors, func.foreign_function_name);

        if kind == CXCursor_ObjCClassMethodDecl func.is_objc_class_method = true;
    } else {
        func.foreign_function_name = copy_and_dispose(clang_Cursor_getMangling(cur));
        assert(func.foreign_function_name != "");
    }

    #if OS == .MACOS {
        // On OSX and maybe Linux too, dlsym needs the first underscore to be omitted
        // this affects dynload/jai as well, which is why we're advancing here intead of in find_lib_for_function_name()

        if starts_with(func.foreign_function_name, "_") advance(*func.foreign_function_name);
    }
    func.library = find_lib_for_function_name(func.foreign_function_name);
    // print("Func: %\n", func.foreign_function_name);

    // @TODO this vs clang_Cursor_getArgument ?
    children := get_children(cur);
    defer array_reset(*children);

    if kind == CXCursor_CXXMethod || kind == CXCursor_Constructor || kind == CXCursor_Destructor {
        // add 'this' parameter
        var := New(Declaration);

        // @TODO if parent is the translation unit then this doesn't work and we need to find the struct
        // that this CXXMethod belongs to and replace the function's member declaration with this definition
        /*
            struct Struct {
                void member(float a);
            };

            void Struct::member(float a) {
    
            }
        */

        var.type = create_pointer_to(create_type(clang_getCursorType(parent), cur));
        var.name = copy_string("this");
        array_add(*func.arguments, var);
    }

    unk_count := 0;
    for children {
        if clang_getCursorKind(it) == CXCursor_ParmDecl {
            var := create_variable_declaration(it, cur);
            if !var {
                error(it, "Could not create function parameter declaration. Discarding.\n");
                return null; // @Leak func
            }
            if !var.name {
                var.name = sprint("unk%", unk_count);
                unk_count += 1;
            }
            array_add(*func.arguments, var);
        } else if clang_isStatement(clang_getCursorKind(it)) {
            func.body = New(Block);
            // do statement stuff
        }
    }

    if clang_Cursor_isVariadic(cur) != 0 {
        func.is_variadic = true;
    }
    if clang_CXXMethod_isVirtual(cur) {
        func.is_virtual = true;
    }

    func.return_type = create_type(clang_getCursorResultType(cur), cur);
    // print("Return type: %\n", type_to_string(func.return_type));

    return func;
}

create_typedef :: (cur: CXCursor, resolving_type_only := false) -> *Typedef {
    assert(clang_getCursorKind(cur) == CXCursor_TypedefDecl);

    def: *Typedef;
    decl, success := table_find(context.cursor_to_decl_table, clang_getCanonicalCursor(cur));
    if !success {
        def = New(Typedef);
        table_add(*context.cursor_to_decl_table, clang_getCanonicalCursor(cur), def);
    } else {
        assert(decl.kind == .TYPEDEF);
        def = cast(*Typedef) decl;
    }

    if !def.name def.name = copy_and_dispose(clang_getCursorSpelling(cur));
    def.type = create_type(clang_getTypedefDeclUnderlyingType(cur), cur);
    if !def.type {
        error(cur, "typedef aliases a non-representable type in jai. Discarding.\n");
        return null;
    }
    if resolving_type_only return def;

    // print("typedef: %: %\n", def.name, type_to_string(def.type));

    return def;
}

_create_typedef_type :: (name: string, old_type: *CType) -> *CType {
    def := New(Typedef);
    def.name = copy_string(name);
    def.type = old_type;

    type := New(CType);
    type.type_of_typedef = def;
    type.size = def.type.size;
    return type;
}

debug_print_cursor :: (cur: CXCursor) {
    depth := 0;

    child_visitor :: (c: CXCursor, parent: CXCursor, client_data: CXClientData) -> CXChildVisitResult #c_call {
        my_depth    := <<cast(*int)client_data;
        child_depth := my_depth + 1;
        ctx: Context;
        push_context ctx {
            for 1..my_depth print("  ");
            print("Cursor '%' of kind '%'\n", clang_getCursorSpelling(c), copy_and_dispose(clang_getCursorKindSpelling(clang_getCursorKind(c))));
        }
        clang_visitChildren(c, child_visitor, *child_depth);
        return CXChildVisit_Continue;
    }

    clang_visitChildren(cur, child_visitor, *depth);
}

create_struct :: (cur: CXCursor, resolving_type_only := false) -> *Struct {
    str: *Struct;
    decl, success := table_find(context.cursor_to_decl_table, clang_getCanonicalCursor(cur));
    if !success {
        str = New(Struct);
        table_add(*context.cursor_to_decl_table, clang_getCanonicalCursor(cur), str);
    } else {
        assert(decl.kind == .STRUCT);
        str = cast(*Struct) decl;
    }

    if !str.name {
        str.name = copy_and_dispose(clang_getCursorSpelling(cur));
        if !str.name {
            str.name = sprint("anon_struct_%", context.anon_counter);
            context.anon_counter += 1;
        }
    }
    
    is_template_class := false;
    cursor_kind := clang_getCursorKind(cur);
    if cursor_kind == {
        case CXCursor_UnionDecl; str.flags |= str.flags.IS_UNION;
        case CXCursor_ClassTemplate; is_template_class = true;
    }

    if resolving_type_only return str;

    //print("name:  %\n", str.name);

    children := get_children(cur);
    defer array_reset(*children);

    {
        cursor_type := clang_getCursorType(cur);
        if is_template_class {
            out := New(CType);
            out.type_of_struct = str;
            out.size = 0;

            str.type = out;
        } else {
            str.type = create_type(clang_getCursorType(cur), cur);
        }
    }

    // if this is not the definition then return null (wait for the definition to come through the pipeline)
    // but if the definition for this struct doesn't exist (only a forward declaration does) then process it
    // so we generate a definition for it in print_struct.
    if clang_isCursorDefinition(cur) == 0 && clang_Cursor_isNull(clang_getCursorDefinition(cur)) == 0 return null;

    for it, it_index: children {
        if is_template_class && clang_getCursorKind(it) == CXCursor_TemplateTypeParameter {
            entry := array_add(*str.template_type_params);
            entry.name = copy_and_dispose(clang_getCursorSpelling(it));
            entry.type = create_type(clang_getCursorType(it), it);
            continue;
        }

        decl := create_declaration(it, cur);
        if decl {
            if clang_CXXMethod_isVirtual(it) {
                array_add(*str.vtable, decl);
            }
            else {
                array_add(*str.declarations, decl);
            }
        }

        // sigh this only works for anonymous struct declarations within parent structs.
        // this doesn't solve the fact that there doesn't seem to be a way to tell if say an unnamed struct in
        // global scope has varibales instantiated by it (i.e., struct { int x; } my_variable; vs struct { int x; };) 
        if clang_Cursor_isAnonymous(it) {
            assert(decl.kind == .STRUCT);
            str := cast(*Struct) decl;
            str.flags |= str.flags.IS_ANON;
        }
    }

    return str;
}

create_namespace :: (cur: CXCursor) -> *Namespace {
    ns: *Namespace;
    decl, success := table_find(context.cursor_to_decl_table, clang_getCanonicalCursor(cur));
    if !success {
        ns = New(Namespace);
        table_add(*context.cursor_to_decl_table, clang_getCanonicalCursor(cur), ns);
    } else {
        assert(decl.kind == .NAMESPACE);
        ns = cast(*Namespace) decl;
    }

    if !ns.name {
        ns.name = copy_and_dispose(clang_getCursorSpelling(cur));
    }

    children := get_children(cur);
    defer array_reset(*children);

    //space.type = create_type(clang_getCursorType(cur));

    for children {
        decl := create_declaration(it, cur);
        if decl array_add(*ns.declarations, decl);
    }

    return ns;
}

create_enum :: (cur: CXCursor, resolving_type_only := false) -> *Enum {
    assert(clang_getCursorKind(cur) == CXCursor_EnumDecl);

    en: *Enum;
    decl, success := table_find(context.cursor_to_decl_table, clang_getCanonicalCursor(cur));
    if !success {
        en = New(Enum);
        table_add(*context.cursor_to_decl_table, clang_getCanonicalCursor(cur), en);
    } else {
        assert(decl.kind == .ENUM);
        en = cast(*Enum) decl;
    }

    if !en.name {
        en.name = copy_and_dispose(clang_getCursorSpelling(cur));
        if !en.name {
            en.name = sprint("anon_enum_%", context.anon_counter);
            context.anon_counter += 1;
        }
    }
    
    en.type = create_type(clang_getEnumDeclIntegerType(cur), cur);
    if resolving_type_only return en;

    // print("ENUM NAME: %\n", en.name);


    children := get_children(cur);
    defer array_reset(*children);

    for children {
        kind := clang_getCursorKind(it);
        if kind != CXCursor_EnumConstantDecl {
            // error(it, "Skipping unexposed attribute cursor in enum declaration: %\n", kind);


            continue;
        }
        // assert(kind == CXCursor_EnumConstantDecl);

        e: Enum.Enumerate;
        if en.type.number_flags & en.type.number_flags.SIGNED {
            e.value = cast(u64) clang_getEnumConstantDeclValue(it);
        } else {
            e.value = clang_getEnumConstantDeclUnsignedValue(it);
        }
        e.name = copy_and_dispose(clang_getCursorSpelling(it));
        array_add(*en.enumerates, e);
    }

    return en;
}

create_objc_interface :: (cur: CXCursor, resolving_type_only := false) -> *Struct {
    // this is going to just setup a struct with the correct things that we want
    str: *Struct;
    decl, success := table_find(context.cursor_to_decl_table, clang_getCanonicalCursor(cur));
    if !success {
        str = New(Struct);
        table_add(*context.cursor_to_decl_table, clang_getCanonicalCursor(cur), str);
    } else {
        assert(decl.kind == .STRUCT);
        str = cast(*Struct) decl;
    }

    if !str.name {
        str.name = copy_and_dispose(clang_getCursorSpelling(cur));
        if !str.name {
            str.name = sprint("anon_struct_%", context.anon_counter);
            context.anon_counter += 1;
        }
    }

    if clang_getCursorKind(cur) == CXCursor_UnionDecl {
        str.flags |= str.flags.IS_UNION;
    }

    if resolving_type_only return str;

    // print("name:  %\n", str.name);

    children := get_children(cur);
    defer array_reset(*children);

    if clang_getCursorKind(cur) == CXCursor_ObjCProtocolDecl {
        // set the type here since technically protocol's are not types in ObjC
        // and thus clang_getCursorType() returns CXType_Invalid.
        out := New(CType);
        out.type_of_struct = str;
        out.size = 0;

        str.type = out;
    } else {
        str.type = create_type(clang_getCursorType(cur), cur);
    }

    // if this is not the definition then return null (wait for the definition to come through the pipeline)
    // but if the definition for this struct doesn't exist (only a forward declaration does) then process it
    // so we generate a definition for it in print_struct.
    if clang_isCursorDefinition(cur) == 0 && clang_Cursor_isNull(clang_getCursorDefinition(cur)) == 0 return null;

    for children {
        kind := clang_getCursorKind(it);
        if kind == CXCursor_ObjCClassRef {
            // this is a reference to our parent class, so we drop
            // a struct member in this slot.
            ty := create_type(clang_getCursorType(it), it);
            name := copy_string(ty.type_of_struct.name);
            to_lower(name);

            decl := _create_declaration(name, ty);
            decl.qualifer_using = true;
            array_add(*str.declarations, decl);
            continue;
        } else if kind == CXCursor_ObjCProtocolRef {
            // skip these for now since they dont contribute to the struct.
            // we may want to, at some point, do 'using ProcolName;' in order to
            // bring in any objc functions that lie within the protocol.

            // actually do the same thing here that we do with ObjCClassRef
            // since we do want to import these things. We have to construct the protocol type 
            prot := create_objc_interface(clang_getCursorReferenced(it), false);
            name := copy_string(prot.type.type_of_struct.name);
            to_lower(name);

            decl := _create_declaration(name, prot.type);
            decl.qualifer_using = true;
            array_add(*str.declarations, decl);
            continue;
        } else if kind == CXCursor_ObjCPropertyDecl {
            // We actually dont need to do anything here since clang generates a CXCursor_ObjCInstanceMethodDecl
            // cursor for both the getter and setter (if exists) of each property.

            /*
            attrs := cast(CXObjCPropertyAttrKind) clang_Cursor_getObjCPropertyAttributes(it, 0);
            {
                getter := New(Function);
                getter.foreign_function_name = copy_and_dispose(clang_Cursor_getObjCPropertyGetterName(it));
                getter.name = copy_string(getter.foreign_function_name);
                getter.is_objc_binding = true;

                getter.return_type = create_type(clang_getCursorType(it), it);
                assert(getter.return_type != null);
                array_add(*getter.arguments, _create_declaration(copy_string("self"), create_pointer_to(str.type))); // add self parameter
                array_add(*str.declarations, getter);
                // print("Added getter: %\n", getter.name);

                array_add_if_unique(*context.unique_objc_selectors, getter.foreign_function_name);
            }

            if !(attrs & CXObjCPropertyAttr_readonly) {
                setter := New(Function);
                setter.foreign_function_name = copy_and_dispose(clang_Cursor_getObjCPropertySetterName(it));
                setter.name = copy_string(setter.foreign_function_name);
                assert(setter.name.count >= 1);
                setter.name.count -= 1; // remove colon

                setter.is_objc_binding = true;
                setter.return_type = context.type_def_void;
                array_add(*setter.arguments, _create_declaration(copy_string("self"), create_pointer_to(str.type))); // add self parameter
                array_add(*setter.arguments, _create_declaration(copy_string("value"), create_type(clang_getCursorType(it), it)));

                array_add(*str.declarations, setter);
                // print("Added setter: %\n", setter.name);
                array_add_if_unique(*context.unique_objc_selectors, setter.foreign_function_name);
            }
            */
            continue;
        } else if kind == CXCursor_ObjCInstanceMethodDecl {
            func := create_function(it, cur);
            if !func continue;

            array_insert_at(*func.arguments, _create_declaration(copy_string("self"), create_pointer_to(str.type)), 0);

            array_add(*str.declarations, func);
            continue;
        } else if kind == CXCursor_ObjCClassMethodDecl {
            func := create_function(it, cur);
            if !func continue;

            func.objc_class_method_struct = str;

            array_add(*str.declarations, func);
            continue;
        }

        decl := create_declaration(it, cur);
        if decl {
            if clang_CXXMethod_isVirtual(it) {
                array_add(*str.vtable, decl);
            }
            else {
                array_add(*str.declarations, decl);
            }
        }

        // sigh this only works for anonymous struct declarations within parent structs.
        // this doesn't solve the fact that there doesn't seem to be a way to tell if say an unnamed struct in
        // global scope has varibales instantiated by it (i.e., struct { int x; } my_variable; vs struct { int x; };) 
        if clang_Cursor_isAnonymous(it) {
            assert(decl.kind == .STRUCT);
            str := cast(*Struct) decl;
            str.flags |= str.flags.IS_ANON;
        }
    }

    return str;
}

create_declaration :: (cur: CXCursor, parent: CXCursor) -> *Declaration {
    kind := clang_getCursorKind(cur);

    if kind == CXCursor_FunctionDecl {
        return cast(*Declaration) create_function(cur, parent);
    } else if kind == CXCursor_CXXMethod {
        func := create_function(cur, parent);
        return cast(*Declaration) func;
    } else if kind == CXCursor_Constructor {
        return cast(*Declaration) create_function(cur, parent);
    } else if kind == CXCursor_Destructor {
        return cast(*Declaration) create_function(cur, parent);
    } else if kind == CXCursor_ObjCInstanceMethodDecl {
        return cast(*Declaration) create_function(cur, parent);
    } else if kind == CXCursor_EnumDecl {
        return cast(*Declaration) create_enum(cur);
    } else if kind == CXCursor_TypedefDecl {
        return cast(*Declaration) create_typedef(cur);
    } else if kind == CXCursor_VarDecl || kind == CXCursor_FieldDecl || kind == CXCursor_ObjCIvarDecl {
        return create_variable_declaration(cur, parent);
    } else if kind == CXCursor_StructDecl || kind == CXCursor_UnionDecl || kind == CXCursor_ClassTemplate {
        return create_struct(cur);
    } else if kind == CXCursor_Namespace {
        return cast(*Declaration) create_namespace(cur);
    } else if kind == CXCursor_ObjCInterfaceDecl {
        return cast(*Declaration) create_objc_interface(cur);
    } else if kind == CXCursor_ObjCProtocolDecl {
        return cast(*Declaration) create_objc_interface(cur);
    } else if kind == CXCursor_FunctionTemplate {
        // @TODO
        error(cur, "Function templates are unsupported right now. Discarding.\n");
        return null;
    } else if kind == CXCursor_ConversionFunction {
        // @TODO
        error(cur, "Conversion functions are unsupported right now. Discarding.\n");
        return null;
    } else if kind == CXCursor_UnexposedDecl {
        name := copy_and_dispose(clang_getCursorSpelling(cur));
        print("name: %\n", name);
    }

    error(cur, "Unhandled cursor kind: %\n", kind);
    return null;
}

handle_toplevel_cursors :: (cur: CXCursor, parent: CXCursor, client_data: CXClientData) -> CXChildVisitResult #c_call {
    // I think it makes sense that we only handle input from files the user passes on the commandline
    // if clang_Location_isFromMainFile(clang_getCursorLocation(cur)) == 0
    //     return CXChildVisit_Continue;

    _ctx := cast(*Context) client_data;
    push_context <<_ctx {

        if clang_Location_isInSystemHeader(clang_getCursorLocation(cur)) != 0 return CXChildVisit_Continue;

        // extern "C"
        // just dop the cursor on the floor and evaluate its children because
        // clang_Cursor_getMangling will do the right thing for us anyways
        if clang_getCursorKind(cur) == CXCursor_LinkageSpec {
            return CXChildVisit_Recurse;
        }

        // if clang_Cursor_isAnonymous(cur) {
        //     print("skipping anon cursor: %\n", clang_getCursorKind(cur));
        //     return CXChildVisit_Continue;
        // }

        decl := create_declaration(cur, parent);
        if decl array_add_if_unique(*context.global_scope.members, decl);

        return CXChildVisit_Continue; // go to the next child in the list! we don't want to recurse here!
    }
}

size_from_number_flags :: (flags: Number_Flags) -> u32 {
    if flags & ._8BIT return 1;
    if flags & ._16BIT return 2;
    if flags & ._32BIT return 4;
    if flags & ._64BIT return 8;

    return 0;
}

init_compiler_context :: (con: *Context) {
    con.pointer_size = 8; // @PointerSize
    con.type_def_void = New(CType);
    con.type_def_ptr_void = create_pointer_to(con.type_def_void);

    con.type_def_bool = New(CType);
    con.type_def_bool.size = 1;

    make_number_type :: (flags: Number_Flags) -> *CType {
        size := size_from_number_flags(flags);
        ty := New(CType);
        ty.size = size;
        ty.number_flags = flags;
        return ty;
    }

    con.type_def_u8  = make_number_type(._8BIT);
    con.type_def_u16 = make_number_type(._16BIT);
    con.type_def_u32 = make_number_type(._32BIT);
    con.type_def_u64 = make_number_type(._64BIT);

    con.type_def_s8 = make_number_type(Number_Flags._8BIT | .SIGNED);
    con.type_def_s16 = make_number_type(Number_Flags._16BIT | .SIGNED);
    con.type_def_s32 = make_number_type(Number_Flags._32BIT | .SIGNED);
    con.type_def_s64 = make_number_type(Number_Flags._64BIT | .SIGNED);

    con.type_def_float32 = make_number_type(Number_Flags._32BIT | .FLOAT);
    con.type_def_float64 = make_number_type(Number_Flags._64BIT | .FLOAT);

    con.type_def_objc_class = _create_typedef_type("Class", con.type_def_ptr_void);
    con.type_def_objc_selector = _create_typedef_type("Selector", con.type_def_ptr_void);
}

print_literal_to_builder :: (builder: *String_Builder, lit: *Literal, for_argument_type: *CType = null) {
    if lit.literal_kind == {
        case .NULL;    append(builder, "null");
        case .INTEGER;
            if for_argument_type == context.type_def_bool {
                if lit.int_value == 0
                    print_to_builder(builder, "false");
                else
                    print_to_builder(builder, "true");
            } else {
                print_to_builder(builder, "%", lit.int_value);
            }
        case .FLOAT;   print_to_builder(builder, "%", formatFloat(lit.float_value, zero_removal=.ONE_ZERO_AFTER_DECIMAL));
        case .STRING;  print_to_builder(builder, "\"%\"", lit.string_value);
    }
}

function_has_a_valist_arg :: (func: *Function) -> bool {
    for func.arguments {
        if it.type && it.type.type_of_typedef && it.type.type_of_typedef.name == "va_list" {
            return true;
        }
    }
    return false;
}

print_declaration_to_builder :: (builder: *String_Builder, decl: *Declaration, no_semicolon := false, no_indent := false, in_struct := false, bitfield_context: *Bitfield_Info = null) {
    if !no_indent print_indentation(builder);

    if decl.kind == .FUNCTION {
        func := cast(*Function)decl;
        if context.rename_functions_that_conflict_with_struct_names {
            for context.global_scope.members {
                if it.kind == .STRUCT {
                    // print("str: %, decl: ^%\n", it.name, decl.name);
                    if it.name == decl.name {
                        print("renaming: %\n", decl.name);
                        decl.name = sprint("_%", decl.name); // @HACK
                        break;
                    }
                }
            }
        }

        // Comment out "stripped" functions in the output
        close_comment := false;
        if context.strip_flags & .Functions_With_Bodies && func.body {
            append(builder, "/* ");
            close_comment = true;
        }
        if context.strip_flags & .Functions_With_valist && function_has_a_valist_arg(func)
            append(builder, "// ");
        if context.strip_flags & .Functions_With_Unknown_Foreign_Libs && function_is_missing_foreign_library(func)
            append(builder, "// ");
        print_function(builder, func);
        if close_comment {
            append(builder, "*/ // TODO: inline function\n");
        }
        context.counts.functions += 1;

    }
    else if decl.kind == .ENUM print_enum(builder, cast(*Enum) decl);
    else if decl.kind == .TYPEDEF print_typedef(builder, cast(*Typedef) decl);
    else if decl.kind == .STRUCT {
        print_struct(builder, cast(*Struct) decl);
        context.counts.structs += 1;
    }
    else if decl.kind == .NAMESPACE print_namespace(builder, cast(*Namespace) decl);
    else if decl.kind == .DECLARATION {
        type_str := type_to_string(decl.type);
        defer free(type_str);

        // @Hack we may need a higher level contruct to handle translating names that conflict with non-overridable keywords
        if      decl.name == "context"         decl.name = "_context";
        else if decl.name == "null"            decl.name = "_null";
        else if decl.name == "type_info"       decl.name = "_type_info";
        else if decl.name == "cast"            decl.name = "_cast";

        if decl.qualifer_using append(builder, "using ");

        decl_name := decl.name;

        // Fields cannot have the same name as their type, so here we
        // append a _ character to the field name if we find that case.
        //
        // TODO: there should probably be some kind of place for the user
        // to resolve this conflict here instead?
        for context.global_scope.members {
            if stripped_name(it.name) == decl_name {
                decl_name = tprint("%_", decl_name);
                break;
            }
        }

        // Handle bitfields by emitting "#place" before declarations. This will at least preserve
        // the correct size of structs.
        place := "";
        if bitfield_context != null {
            using bitfield_context;
            if decl.bitfield_width != -1 {
                assert(decl.bitfield_width != 0, "TODO: implement zero-width bitfields");

                if watermark != -1 && first_decl && first_decl.type == decl.type && decl.bitfield_width + watermark <= first_decl.type.size * 8 {
                    place = tprint("#place %; /* bitfield % */\n", bitfield_context.first_decl.name, bitfield_context.watermark);
                    watermark += decl.bitfield_width;
                } else {
                    watermark = decl.bitfield_width;
                    first_decl = decl;
                }
            } else {
                bitfield_context.watermark = -1;
                bitfield_context.first_decl = null;
            }
        }

        if place.count > 0 {
            append(builder, place);
            print_indentation(builder);
        }

        print_to_builder(builder, "%: %", decl_name, type_str);

        if decl.expression {
            append(builder, " = ");
            print_literal_to_builder(builder, cast(*Literal) decl.expression, decl.type);
        }
        if !no_semicolon append(builder, ";");
    } else {
        print("Unhandled type in print_declaration_to_builder: %\n", decl.kind);
    }
}

print_objc_selector_identifier :: (builder: *String_Builder, ident: string) {
    arr: [] u8;
    arr.data = ident.data;
    arr.count = ident.count;
    for arr {
        if it == #char ":" {
            append(builder, "_");
        } else {
            s: string;
            s.data = *it;
            s.count = 1;
            append(builder, s);
        }
    }
}

function_is_missing_foreign_library :: (func: *Function) -> bool {
    return !func.is_virtual && !func.body && !func.is_objc_binding && func.library == null;
}

print_function :: (builder: *String_Builder, func: *Function) {
    name := stripped_name(func.name);
    replace_chars(name, " ", #char "_");

    if func.is_virtual {
        print_to_builder(builder, "% : (", name);
    }
    else {
        print_to_builder(builder, "% :: (", name);
    }
    

    for func.arguments {
        print_declaration_to_builder(builder, it, true, true);

        if (it_index < func.arguments.count-1) || func.is_variadic append(builder, ", ");
    }

    if func.is_variadic {
        append(builder, "__args: ..Any");
    }

    return_str := type_to_string(func.return_type);
    defer free(return_str);
    print_to_builder(builder, ") -> % ", return_str);

    if func.is_virtual {
        // This is a function pointer, so no need to specify the binding.
        append(builder, "#cpp_method;\n");
    } else if func.body {
        if   func.is_cpp_method append(builder, "#cpp_method");
        else                    append(builder, "#c_call");

        append(builder, " {\n");
        context.tab_depth += 1;
        // @TODO
        context.tab_depth -= 1;

        print_indentation(builder);
        append(builder, "}");
    } else if func.is_objc_binding {
        // this is an intrinsic to call objc_msgSend
        print_to_builder(builder, "{\n");
        context.tab_depth += 1;
        print_indentation(builder);
        print_to_builder(builder, "_func: (obj: *void, selector: *void");

        if !func.is_objc_class_method {
            if (func.arguments.count-1) > 0 append(builder, ", ");

            for func.arguments {
                if it_index == 0 continue; // skip the self parameter

                print_declaration_to_builder(builder, it, true, true);

                if (it_index < func.arguments.count-1) || func.is_variadic append(builder, ", ");
            }
        } else {
            if func.arguments.count > 0 append(builder, ", ");

            for func.arguments {
                print_declaration_to_builder(builder, it, true, true);

                if (it_index < func.arguments.count-1) || func.is_variadic append(builder, ", ");
            }
        }

        // @TODO figure out when to use objc_msgSend or objc_msgSend_fpret, or whatever, maybe libclang has facility for this?
        print_to_builder(builder, ") -> % #foreign;\n", return_str);
        print_indentation(builder); print_to_builder(builder, "_func = xx objc_msgSend;\n");

        print_indentation(builder);
        if func.return_type != context.type_def_void {
            print_to_builder(builder,  "return ");
        }

        if !func.is_objc_class_method {
            print_to_builder(builder, "_func(%, __selectors.", func.arguments[0].name);
        } else {
            print_to_builder(builder, "_func(objc_getClass(\"%\"), __selectors.", func.objc_class_method_struct.name);
        }
        print_objc_selector_identifier(builder, func.foreign_function_name);
        // forward function parameters
        if !func.is_objc_class_method {
            if (func.arguments.count-1) > 0 append(builder, ", ");

            for func.arguments {
                if it_index == 0 continue;

                print_to_builder(builder, it.name);
                if (it_index < func.arguments.count-1) || func.is_variadic append(builder, ", ");
            }
        } else {
            if func.arguments.count > 0 append(builder, ", ");
            for func.arguments {
                print_to_builder(builder, it.name);
                if (it_index < func.arguments.count-1) || func.is_variadic append(builder, ", ");
            }
        }
        print_to_builder(builder, ");\n");

        context.tab_depth -= 1;
        print_indentation(builder); print_to_builder(builder, "}\n");

    } else {
        lib_name := "__UnknownLib";
        if func.library {
            lib_name = func.library.name;
        } else {
            error("Could not find library for function % (%)\n", func.name, func.foreign_function_name);
        }

        calling_conv := "#foreign";
        if func.is_cpp_method calling_conv = "#cpp_method #foreign";

        print_to_builder(builder, "% %", calling_conv, lib_name);

        if func.foreign_function_name && name != func.foreign_function_name {
            print_to_builder(builder, " \"%\"", func.foreign_function_name);
        }
        append(builder, ";");
    }
}

print_enum :: (builder: *String_Builder, en: *Enum) {
    if context.c_enum_emulation {
        append(builder, "using ");
    }

    type_str := type_to_string(en.type);
    defer free(type_str);
    print_to_builder(builder, "% :: enum % {\n", stripped_name(en.name), type_str);
    is_signed := (en.type.number_flags & Number_Flags.SIGNED);
    context.tab_depth += 1;
    for en.enumerates {
        name := it.name;

        if context.strip_enum_values_with_suffix.count > 0
            if ends_with(name, context.strip_enum_values_with_suffix)
                continue;

        for context.strip_enum_value_prefixes if it.first == en.name
            if begins_with(name, it.second)
                advance(*name, it.second.count);

        if context.strip_enum_prefixes && begins_with(name, en.name) {
            advance(*name, en.name.count);
            if begins_with(name, "_")
                advance(*name, 1);
        }
        
        print_indentation(builder);
        if is_signed print_to_builder(builder, "% :: %;\n", name, cast(s64) it.value);
        else print_to_builder(builder, "% :: %;\n", name, cast(u64) it.value);
    }
    context.tab_depth -= 1;
    print_indentation(builder);
    append(builder, "}");
}

replace_typename :: (name: string) -> string {
    for context.type_replacements if it.first == name
        return it.second;

    return name;
}

stripped_name :: (name: string) -> string {
    if context.strip_prefix.count == 0 || name.count == 0 || name.count <= context.strip_prefix.count
        return name;

    stripped := name;
    if begins_with(name, context.strip_prefix) {
        advance(*stripped, context.strip_prefix.count);
        
        if stripped.count > 0 && stripped[0] == #char "_"
            advance(*stripped, 1);
    }

    return stripped;
}

print_struct :: (builder: *String_Builder, str: *Struct) {
    struct_type := "struct";
    if str.flags & str.flags.IS_UNION struct_type = "union";

    name := stripped_name(str.name);

    if str.template_type_params.count > 0 {
        template_type_names: [..]string;
        template_type_names.allocator = __temporary_allocator;
        for str.template_type_params array_add(*template_type_names, it.name);

        struct_type = tprint("%(%: Type)", struct_type, join(..template_type_names, separator=", "));
    }

    if name && !(str.flags & str.flags.IS_ANON) {
        print_to_builder(builder, "% :: % {\n", name, struct_type);
    } else {
        assert((str.flags & str.flags.IS_ANON) == str.flags.IS_ANON);
        if (str.do_not_print_anon) return;

        print_to_builder(builder, "% {\n", struct_type);
    }


    context.tab_depth += 1;

    if str.vtable {
        print_indentation(builder);
        print_to_builder(builder, "using vtable : * struct {\n");
        context.tab_depth += 1;
        for str.vtable {
            print_declaration_to_builder(builder, it, in_struct=true);
            append(builder, "\n");
        }
        context.tab_depth -= 1;
        print_indentation(builder);
        print_to_builder(builder, "};\n");
    }

    bitfield_info: Bitfield_Info;
    for str.declarations {
        if (context.strip_flags & .Constructors) && it.kind == .FUNCTION && (cast(*Function)it).is_constructor {
            continue;
        }
        print_declaration_to_builder(builder, it, in_struct=true, *bitfield_info);
        append(builder, "\n");
    }
    context.tab_depth -= 1;
    print_indentation(builder);
    append(builder, "}");

    if str.name && context.generate_static_struct_size_checks && str.template_type_params.count == 0 {
        print_to_builder(builder, "\n#assert size_of(%) == %;", stripped_name(str.name), str.type.size);
    }
}

Bitfield_Info :: struct {
    first_decl: *Declaration;
    watermark: int = -1;
}

print_namespace :: (builder: *String_Builder, ns: *Namespace) {

    print_to_builder(builder, "% :: struct {\n", ns.name);

    context.tab_depth += 1;
    for ns.declarations {
        print_declaration_to_builder(builder, it);
        append(builder, "\n");
    }
    context.tab_depth -= 1;

    print_indentation(builder);
    append(builder, "}");
}

print_typedef :: (builder: *String_Builder, def: *Typedef) {
    type_str := type_to_string(def.type);
    defer free(type_str);
    
    // filter out cases where the typedef is the same name as the struct/enum/etc:
    // typedef struct My_Struct {...} My_Struct;
    if stripped_name(def.name) == type_str return;

    print_to_builder(builder, "% :: %;", stripped_name(def.name), type_str);
}

error :: (msg: string, args: ..Any) {
    print(msg, ..args);
}

error :: (cur: CXCursor, msg: string, args: ..Any) {
    loc := clang_getCursorLocation(cur);
    file: CXFile;
    line: u32;
    column: u32;
    offset: u32; // byte offset into file ??
    clang_getSpellingLocation(loc, *file, *line, *column, *offset);

    filename := copy_and_dispose(clang_getFileName(file));
    defer free(filename);
    print("%:%:%: ", filename, line, column);
    error(msg, ..args);
}

#if OS == .WINDOWS {
    DLL_SUFFIX :: ".dll";
    PATH_SEPARATOR_STRING :: "\\";
} else #if OS == .LINUX {
    DLL_SUFFIX :: ".so";
    PATH_SEPARATOR_STRING :: "/";
} else #if OS == .MACOS {
    DLL_SUFFIX :: ".dylib";
    PATH_SEPARATOR_STRING :: "/";
}

os_load_library_helper :: (paths: [] string, name: string) -> type_of(Library_Info.handle) {
    handle: type_of(Library_Info.handle);

    for paths {
        tpath := concatenate(it, PATH_SEPARATOR_STRING, name, "\0");
        wide_path_data, success, w_len := utf8_to_wide(tpath);
        assert(success);

        #if OS == .WINDOWS {
            buffer: [MAX_PATH] u16;
            length := GetFullPathNameW(wide_path_data, buffer.count, xx buffer.data, null);
            free(tpath);
            handle = LoadLibraryExW(buffer.data, null, 0);
        } else #if OS == .LINUX || OS == .MACOS {
            rpath := realpath(tpath.data, null);
            defer free(rpath);
            if rpath handle = dlopen(rpath, RTLD_LAZY);
        }

        if handle break;
    }

    return handle;
}

os_load_library :: (paths: [] string, name: string) -> type_of(Library_Info.handle), is_system: bool {
    suf := concatenate(name, DLL_SUFFIX);
    defer free(suf);

    handle := os_load_library_helper(paths, suf);
    if handle return handle, false;

    // if !handle {
    //     #if OS == .WINDOWS {
    //         handle = LoadLibraryW(utf8_to_wide(name));
    //     } else #if OS == .LINUX || OS_MACOSX {
    //         handle = dlopen(to_c_string(name), RTLD_LAZY); // @Leak ?
    //     }

    //     print("% is system\n", name);
    //     return handle, true;
    // }

    print("Could not load: %\n", name);
    #if STOP_ON_ERRORS exit(1);
    dummy: type_of(Library_Info.handle);
    return dummy, false;
}

os_symbol_exists_in_library :: (lib: *Library_Info, name: string) -> bool {
    str := to_c_string(name);
    defer free(str);
    #if OS == .WINDOWS {
        proc := GetProcAddress(lib.handle, str);
    } else #if OS == .LINUX || OS == .MACOS {
        proc := dlsym(lib.handle, str);
    }
    return proc != null;
}

find_lib_for_function_name :: (name: string) -> *Library_Info {
    for context.libraries {
        if os_symbol_exists_in_library(it, name) return it;
    }
    return null;
}

make_valid_identifer :: (str: string) -> string {
    s := copy_string(str);
    replace_chars(s, "-", #char "_");
    return s;
}

main :: () {
    Debug.init();

    libnames: [..] string;
    libpaths: [..] string;
    output_filename := "out.jai";
    has_error := false;

    string_pair_from_equals_expr :: (opt: string) -> bool, Pair(string) {
        idx, found := index_of_any_char(opt, "=");
        if !found return false, .{};

        parts := split(opt, "=");
        if parts.count != 2 return false, .{};

        string_pair: Pair(string);
        string_pair.first  = parts[0];
        string_pair.second = parts[1];
        return true, string_pair;
    }

    argv: [..] *u8;
    args := get_command_line_arguments();
    for 1..args.count-1 {
        ar := args[it];

        // @TODO what if the user passes in a path?
        if begins_with(ar, "-l") {
            if ar == "-l" {
                if it < args.count-1 {
                    array_add(*libnames, args[it+1]);
                    it += 1;
                } else error("option '-l' must be followed by a library name!\n");
            } else {
                name := ar;
                advance(*name, 2);
                array_add(*libnames, name);
            }
        } else if begins_with(ar, "-o") {
            if ar == "-o" {
                if it < args.count-1 {
                    output_filename = args[it+1];
                    it += 1;
                } else error("option '-o' must be followed by a file name!\n");
            } else { 
                name := ar;
                advance(*name, 2);
                output_filename = name;
            }
        } else if begins_with(ar, "-L") {
            if ar == "-L" {
                if it < args.count-1 {
                    array_add(*libpaths, args[it+1]);
                    it += 1;
                } else error("option '-L' must be followed by a path!\n");
            } else { 
                name := ar;
                advance(*name, 2);
                array_add(*libpaths, name);
            }
        } else if ar == "--strip-prefix" {
            if it < args.count - 1 {
                context.strip_prefix = args[it + 1];
                it += 1;
            } else error("option '--strip-prefix' must be followed by a prefix!\n");
        } else if ar == "--strip-enum-values-with-suffix" {
            if it < args.count - 1 {
                context.strip_enum_values_with_suffix = args[it + 1];
                it += 1;
            } else error("option '--strip-enum-values-with-suffix' must be followed by a suffix!\n");
        } else if ar == "--type-replacement" {
            MSG :: "option '--strip-enum-value-prefix' must be followed by a prefix like \"enumName=valuePrefix\"!\n";
            if it < args.count - 1 {
                ok, string_pair := string_pair_from_equals_expr(args[it + 1]);
                if !ok error(MSG);
                array_add(*context.type_replacements, string_pair);
                it += 1;
            } else error(MSG);
        } else if ar == "--extra-file-scope-import" {
            if it < args.count - 1 {
                opt := args[it + 1];
                array_add(*context.extra_file_scope_imports, opt);
                it += 1;
            } else error("option '--extra-file-scope-import' must be followed by an import name!\n");
        } else if ar == "--strip-enum-value-prefix" {
            MSG :: "option '--strip-enum-value-prefix' must be followed by a prefix like \"enumName=valuePrefix\"!\n";
            if it < args.count - 1 {
                opt := args[it + 1];
                ok, string_pair := string_pair_from_equals_expr(opt);
                if !ok error(MSG);
                array_add(*context.strip_enum_value_prefixes, string_pair);
                it += 1;
            } else error(MSG);
        } else {
            if !begins_with(ar, "-") {
                // assuming source file doesnt start with a dash for
                // short-term simplicity's sake.

                if !file_exists(ar) {
                    error("Error: file '%' could not be found.\n", ar);
                    has_error = true;
                }
            }

            // pass the option onto clang
            array_add(*argv, to_c_string(ar));
        }
    }

    init_compiler_context(*context);

    for libnames {
        lib := New(Library_Info);
        lib.name = make_valid_identifer(it);
        lib.path = it;
        lib.handle, lib.is_system = os_load_library(libpaths, lib.path);
        if !lib.handle {
            print("Could not load library: '%'\n", lib.name);
            continue;
        } else {
            print("Loaded library % at %\n", lib.name, lib.handle);
        }
        array_add(*context.libraries, lib);
    }

    index := clang_createIndex(0, 0);
 
    tu: CXTranslationUnit;
    err := clang_parseTranslationUnit2(index, null, argv.data, xx argv.count, null, 0, 0, *tu);
    if err != 0 {
        print("Clang returned errror code %\n", err);

        has_error = true;
    }

    for 1..clang_getNumDiagnostics(tu) {
        diag := clang_getDiagnostic(tu, it-1);

        severity := clang_getDiagnosticSeverity(diag);
        if severity == CXDiagnostic_Error || severity == CXDiagnostic_Fatal {
            has_error = true;
        }
        str := clang_formatDiagnostic(diag, clang_defaultDiagnosticDisplayOptions());
        msg := to_string(clang_getCString(str));
        print("%", msg);
        clang_disposeString(str);
    }

    if !has_error {
        cursor := clang_getTranslationUnitCursor(tu);
        clang_visitChildren(cursor, handle_toplevel_cursors, *context);

        builder: String_Builder;

        imps: [..]string;
        imps.allocator = __temporary_allocator;
        for context.extra_file_scope_imports
            array_add(*imps, tprint("#import \"%\";", it));

        extra_file_scope_imports_string := join(..imps, "\n");
        print_to_builder(*builder, #string END
#scope_file
#import "Basic";
%
// TODO: these manual types shouldn't be necessary
uint32_t :: u32;
int32_t  :: s32;
size_t   :: s64;
#scope_module


END, extra_file_scope_imports_string);

        for context.libraries {
            if it.is_system print_to_builder(*builder, "% :: #foreign_system_library \"%\";\n", it.name, it.path);
            else print_to_builder(*builder, "% :: #foreign_library \"%\";\n", it.name, it.path);
        }
        for context.global_scope.members {
            print_declaration_to_builder(*builder, it);
            append(*builder, "\n\n");
        }

        if context.unique_objc_selectors.count {
            append(*builder, "#scope_file\n\n");
            append(*builder, "_Generated_Selectors :: struct {\n");
            context.tab_depth += 1;
            for context.unique_objc_selectors {
                print_indentation(*builder);
                print_objc_selector_identifier(*builder, it);
                append(*builder, ": *void = ---;\n");
            }

            print_indentation(*builder);
            append(*builder, "#constructor (this: *_Generated_Selectors) {\n");
            context.tab_depth += 1;
            for context.unique_objc_selectors {
                print_indentation(*builder);
                append(*builder, "this.");
                print_objc_selector_identifier(*builder, it);
                print_to_builder(*builder, " = sel_registerName(\"%\");\n", it);
            }
            context.tab_depth -= 1;
            print_indentation(*builder); append(*builder, "};\n");

            context.tab_depth += -1;
            append(*builder, "}\n");
            append(*builder, "__selectors: _Generated_Selectors;\n");
        }

        // write_builder(*builder);

        file, success := file_open(output_filename, true);
        if !success {
            error("Error: Could not open file for output %\n", output_filename);
            has_error = true;
        } else {
            str := builder_to_string(*builder);
            file_write(*file, str);
            file_close(*file);
            free(str);
        }
    }

    clang_disposeTranslationUnit(tu);
    clang_disposeIndex(index);

    if has_error
        exit(1);

    print("\nOK! generated %\n", output_filename);
    print("    % functions\n", context.counts.functions);
    print("    % structs\n", context.counts.structs);
}

#scope_file
Pair :: struct(T: Type) { // TODO: should probably just go away and be [2]string
    first: T;
    second: T;
}
