#import "Compiler";

Kind_Type :: struct {
    kind: Code_Node.Kind;
    type: Type;
};

code_node_types := Kind_Type.[
    Kind_Type.{.BLOCK, Code_Block},
    Kind_Type.{.IF, Code_If},
    Kind_Type.{.LITERAL, Code_Literal},
    Kind_Type.{.IDENT, Code_Ident},
    Kind_Type.{.UNARY_OPERATOR, Code_Unary_Operator},
    Kind_Type.{.BINARY_OPERATOR, Code_Binary_Operator},
];

main :: () {}