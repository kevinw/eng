#scope_file

#import "Basic";
#import "Compiler";
#import "Random";
String :: #import "String";

module_search_paths := string.[
    "../jai-imgui",
    "../jai-raylib",
    "../jai-soloud",
    "lib",
    "src"
];

Build_Flags :: enum_flags {
    None       :: 0;
    Check_Only :: (1 << 0);
    Reload     :: (1 << 1);
}

build_plugin :: (build_flags: Build_Flags, game_dll_source_name: string, loc := #caller_location) {
    set_working_directory(#filepath);

    opts := get_build_options();
    opts.output_type = .NO_OUTPUT;
    set_build_options(opts);

    if String.count(game_dll_source_name, ".") > 0 {
        compiler_error(tprint("Error: no dots in source name please: '%'", game_dll_source_name), loc);
        return;
    }

    w := compiler_create_workspace("build");
    {
        compiler_begin_intercept(w);
        defer compiler_end_intercept(w);

        array_add(*opts.modules_search_path_array, ..module_search_paths);
        opts.output_type = .DYNAMIC_LIBRARY;

        if build_flags & .Check_Only
            opts.output_path = CHECK_PATH;

        if build_flags & .Reload {
            output_exe := tprint("%_reloaded_%", game_dll_source_name, random_get());
            print("reloading...changing DLL output to %\n", output_exe);
            opts.output_executable_name = output_exe;
        } else {
            opts.output_executable_name = game_dll_source_name;
        }
        set_build_options(opts, w);

        source_file := tprint("src/%.jai", game_dll_source_name);
        add_build_file(source_file, w);

        while true {
            message := compiler_wait_for_message();
            if !message || message.workspace != w continue;


            collect_component_functions(message);

            if message.kind == .COMPLETE break;
        }
    }
};

build_host :: (check := false) {
    set_working_directory(#filepath);

    opts := get_build_options();
    opts.output_type = .NO_OUTPUT;
    set_build_options(opts);

    w := compiler_create_workspace("build");
    {
        compiler_begin_intercept(w);
        defer compiler_end_intercept(w);

        array_add(*opts.modules_search_path_array, ..module_search_paths);
        opts.output_type = .EXECUTABLE;
        if check opts.output_path = CHECK_PATH;
        set_build_options(opts, w);
        add_build_file("src/host.jai", w);

        while true {
            message := compiler_wait_for_message();
            if !message || message.workspace != w continue;
            if message.kind == .COMPLETE break;
        }
    }
};

fatal_error := false;

collect_component_functions :: (message: *Compiler_Message) {
    if fatal_error return;
    
    if message.kind == .CODE_TYPECHECKED {
        tc := cast(*Compiler_Message_Code_Typechecked) message;

        for decl: tc.declarations {

            // Look for print-type stuff.
            if !decl.root_expression  continue;

            if decl.root_expression.kind == {
              case .PROCEDURE_HEADER;
                header := cast(*Code_Procedure_Header) decl.root_expression;
                if header.procedure_flags & .POLYMORPHIC continue;  // Do nothing with polymorphic procedures.

                if is_component_func(decl) {
                    //success := validate_printlike(decl);
                    //if !success {
                        //fatal_error = true;
                        //return;
                    //}
                }
                
                /*
              case .PROCEDURE_BODY;
                body := cast(*Code_Procedure_Body) decl.root_expression;
                if body.header.procedure_flags & .POLYMORPHIC continue;  // Do nothing with polymorphic procedures.

                check_print_calls(decl);
                */
            }
        }
    }
}

is_component_func :: (decl: *Code_Declaration) -> bool {
    for decl.notes {
        if it.text == "draw" {
            return true;
        }
    }

    return false;
}


CHECK_PATH :: "check/";

build :: () {
    DEFAULT_SRC_PLUGIN :: "game";

    args := compiler_get_command_line_arguments();
    is_reload := false;
    if args.count > 0 {
        flags := Build_Flags.None;
        if args[0] == "reload" {
            args.data = args.data + 1;
            args.count -= 1;
            flags |= .Reload;
        }
        if args.count > 0 if args[0] == {
            case "all";
                build_host();
                build_plugin(flags, DEFAULT_SRC_PLUGIN);
            case "host";
                build_host();
            case "check";
                build_host(check=true);
                flags |= .Check_Only;
                build_plugin(flags, DEFAULT_SRC_PLUGIN);
            case;
                build_plugin(flags, args[0]);
        }

        return; // done.
    }

    // With no command line arugments, just build the plugin specified by
    // DEFAULT_SRC_PLUGIN.
    build_plugin(.None, DEFAULT_SRC_PLUGIN);
}

#run build();
