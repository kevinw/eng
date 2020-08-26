#import "Basic";
#import "Compiler";

Metaprogram :: struct {
    updater_func_headers: [..]*Code_Procedure_Header;
}

collect_updaters :: (using metaprogram: *Metaprogram, message: *Compiler_Message) {
    if message.kind == .CODE_TYPECHECKED {
        tc := cast(*Compiler_Message_Code_Typechecked)message;

        for decl: tc.declarations {
            if !decl.root_expression continue;

            if decl.root_expression.kind == {
                case .PROCEDURE_HEADER;
                    header := cast(*Code_Procedure_Header)decl.root_expression;
                    if header.procedure_flags & .POLYMORPHIC continue;
                    if !is_updater(decl) continue;

                    print("found updater: %\n", <<header);
                    array_add(*updater_func_headers, header);
            }
        }
    }

}

is_updater :: (decl: *Code_Declaration) -> bool {
    for decl.notes
        if it.text == "Updater"
            return true;
    
    return false;
}

build_host :: () {
    set_working_directory(#filepath);

    opts := get_build_options();
    opts.output_type = .NO_OUTPUT;
    set_build_options(opts);

    w := compiler_create_workspace("build");
    {
        compiler_begin_intercept(w);
        defer compiler_end_intercept(w);

        opts.output_type = .EXECUTABLE;
        set_build_options(opts, w);
        add_build_file("ecs.jai", w);

        total_messages := 0;
        metaprogram: Metaprogram;
        while true {
            message := compiler_wait_for_message();
            if !message || message.workspace != w continue;
            collect_updaters(*metaprogram, message);
            if message.kind == .COMPLETE break;
        }
    }
};

#run build_host();