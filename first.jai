#import "Basic";
#import "Compiler";

module_search_paths := string.[
    "../jai-raylib",
    "../raygui/src",
    "../jai-soloud",
    "lib",
    "src"
];

build_plugin :: (check := false) {
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
        if check opts.output_path = CHECK_PATH;
        opts.output_executable_name = "game";
        set_build_options(opts, w);
        add_build_file("src/game.jai", w);

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
    args := compiler_get_command_line_arguments();
    if args.count > 0 {
        if args[0] == {
            case "all";
                build_host();
                build_plugin();
            case "host";
                build_host();
            case "check";
                build_host(check=true);
                build_plugin(check=true);
            case;
                print("error: unknown argument '%'", args[0]);
                exit(1);
        }

        return; // done.
    }

    // else...just build game.dll
    build_plugin();
}

#run build();