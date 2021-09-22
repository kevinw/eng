#import "Basic";
#import "Compiler";

build :: () {
    set_build_options_dc(.{do_output=false});

    w := compiler_create_workspace("build");
    compiler_begin_intercept(w);
    defer compiler_end_intercept(w);
    array_add(*opts.modules_search_path_array,
        "../../../../jai-imgui",
        "../..",
    );
    opts.output_type = .EXECUTABLE;

    opts.output_executable_name = "d3d11_example";

    set_build_options(opts, w);
    add_build_file("d3d11_example.jai", w);
    while true {
        message := compiler_wait_for_message();
        if !message || message.workspace != w continue;
            if message.kind == .COMPLETE
                break;
    }
}

#run build();
