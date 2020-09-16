#import "Basic";
#import "Compiler";

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

build_plugin :: (build_flags: Build_Flags, source_files: ..string) {
    set_working_directory(#filepath);

    opts := get_build_options();
    opts.output_type = .NO_OUTPUT;
    set_build_options(opts);

    w := compiler_create_workspace("build");
    {
        compiler_begin_intercept(w);
        defer compiler_end_intercept(w);

        array_add(*opts.modules_search_path_array, ..module_search_paths);
        opts.output_type = .DYNAMIC_LIBRARY;

        if build_flags & .Check_Only
            opts.output_path = CHECK_PATH;

        opts.output_executable_name = "game";
        set_build_options(opts, w);

        for source_files
            add_build_file(it, w);

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
    DEFAULT_SRC_PLUGIN :: "src/game.jai";

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
                print("building:\n");
                for args print("  %\n", it);
                build_plugin(.None, ..args);
                //print("error: unknown argument '%'", args[0]);
                exit(1);
        }

        return; // done.
    }

    // else...just build game.dll
    build_plugin(.None, DEFAULT_SRC_PLUGIN);
}

#run build();
