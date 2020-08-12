#import "Basic";
#import "Program_Print";
#import "Compiler";

Code_Node_Visit_Func :: #type (node: *Code_Node, parent: *Code_Node);

visit_auto :: (node: *Code_Node, func: Code_Node_Visit_Func) {
    for code_node_types {
        if node.kind == it.kind {
            ti := type_info(it.type);

        }
    }
}

visit :: (node: *Code_Node, func: Code_Node_Visit_Func) {
    if node.kind == {
        case .BLOCK;
            block := cast(*Code_Block)node;
            for block.members func(it, node);
            for block.statements func(it, node);
        case .PROCEDURE_CALL;
            call := cast(*Code_Procedure_Call)node;
            func(call.procedure_expression, node);
            for call.arguments_sorted func(it, node);
            for call.arguments_unsorted {
                func(it.name, node);
                func(it.expression, node);
            }
        case .IF;
            code_if := cast(*Code_If)node;
            func(code_if.condition, node);
            func(code_if.then_block, node);
            func(code_if.else_block, node);
        case .CASE;
            code_case := cast(*Code_Case)node;
            func(code_case.condition, node);
            func(code_case.then_block, node);
        case;
            print("unhandled: %\n", node);
    }
}

array_view_copy_without :: (arr: []$T, item: T) -> []T {
    new_arr: [..]T;
    for arr {
        if it != item
            array_add(*new_arr, it);
    }
    return new_arr;
}

Kind_Type :: struct {
    kind: Code_Node.Kind;
    type: Type;
};

code_node_types :: Kind_Type.[
    Kind_Type.{.BLOCK, Code_Block},
    Kind_Type.{.IF, Code_If},
    Kind_Type.{.LITERAL, Code_Literal},
    Kind_Type.{.IDENT, Code_Ident},
    Kind_Type.{.UNARY_OPERATOR, Code_Unary_Operator},
    Kind_Type.{.BINARY_OPERATOR, Code_Binary_Operator},
];

debug_visitor :: (node: *Code_Node, parent: *Code_Node) {
    print("%\n", <<node);
}

debug_code :: (code: Code) #expand {
    #run modify_generator_code(code, debug_visitor);
}

modify_generator_code :: (code: Code, visitor: Code_Node_Visit_Func) -> Code {
    root, expressions := compiler_get_nodes(code);
    visit(root, visitor);
    return compiler_get_code(root);
}

generator :: (code: Code) #expand {
    modified :: #run modify_generator_code(code, generator_visitor);
    #insert_internal modified;

    generator_visitor :: (node: *Code_Node, parent: *Code_Node) {
        if node.kind == .PROCEDURE_CALL {
            proc_call := cast(*Code_Procedure_Call)node;
            if proc_call.procedure_expression.kind == .IDENT {
                ident := cast(*Code_Ident)proc_call.procedure_expression;
                if ident.name == "yield" {
                    print("IDENT: %\n", ident.name);
                    print("parent: %\n", <<parent);

                    assert(parent.kind == .BLOCK);
                    code_block_parent := cast(*Code_Block)parent;
                    code_block_parent.statements = array_view_copy_without(code_block_parent.statements, node);
                }
            }
        }
    }
}

yield :: () { print("yield\n"); }

main :: () {

    debug_code(#code {
        if 42 == {
            case 42;
                yes();
            case 50;
                no();
        }

    });

    /*
    generator(#code {
        print("one\n");
        yield();
        print("two\n");
    });
    */
}