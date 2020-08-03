#import "Basic";
#import "Compiler";

module_search_paths := string.["../jai-raylib", "lib"];

build_plugin :: () {
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

build_host :: () {
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
        set_build_options(opts, w);
        add_build_file("src/host.jai", w);

        while true {
            message := compiler_wait_for_message();
            if !message || message.workspace != w continue;
            if message.kind == .COMPLETE break;
        }
    }
};

build :: () {
    args := compiler_get_command_line_arguments();
    if args.count > 0 && args[0] == "all" {
        build_host();
        build_plugin();
    } else if args.count > 0 && args[0] == "host" {
        build_host();
    } else {
        build_plugin();
    }
}

//#run build_plugin();
//#run build_host();
#run build();