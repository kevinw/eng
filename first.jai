#import "Basic";
#import "Compiler";
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

        opts.output_executable_name = game_dll_source_name;
        set_build_options(opts, w);

        source_file := tprint("src/%.jai", game_dll_source_name);
        add_build_file(source_file, w);

        while true {
            message := compiler_wait_for_message();
            if !message || message.workspace != w continue;

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

CHECK_PATH :: "check/";

build :: () {
    DEFAULT_SRC_PLUGIN :: "game";

    args := compiler_get_command_line_arguments();
    if args.count > 0 {
        if args[0] == {
            case "all";
                build_host();
                build_plugin(.None, DEFAULT_SRC_PLUGIN);
            case "host";
                build_host();
            case "check";
                build_host(check=true);
                build_plugin(.Check_Only, DEFAULT_SRC_PLUGIN);
            case;
                build_plugin(.None, args[0]);
        }

        return; // done.
    }

    // With no command line arugments, just build the plugin specified by
    // DEFAULT_SRC_PLUGIN.
    build_plugin(.None, DEFAULT_SRC_PLUGIN);
}

#run build();
