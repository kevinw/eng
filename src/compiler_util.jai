
code_node_as_string :: (node: *Code_Node) -> string {
    if node == null return "<null>";

    if node.kind == {
        case .PROCEDURE_HEADER;
            proc_header := cast(*Code_Procedure_Header)node;
            return tprint("Code_Procedure_Header { name=%, filename=%, line=% }",
                proc_header.name, proc_header.filename, proc_header.l0);
                
        case .IDENT;
            ident := cast(*Code_Ident)node;
            return tprint("Ident { name=%, type=%, resolved_decl=% }", ident.name, <<ident.type, code_node_as_string(ident.resolved_declaration));

        case .DECLARATION;
            decl := cast(*Code_Declaration)node;
            return tprint("Code_Declaration { name: %, root_expression: % }", decl.name, code_node_as_string(decl.root_expression));

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

