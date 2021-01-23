// jai c compiler/converter
// Converts C code into Jai code.
// Usage: jaicc [options] <inputs>
// [options] can be any of Clang's supported flags (see: jaicc -help for details)
// Will primarily be useful for generating bindings to pre-existing C libraries

#import "Basic";
#import "Compiler";
#import "File";
#import "Project_Generator";
#import "String";

build :: (use_generated := true, build_exe := true) -> Workspace {
    set_working_directory(#filepath);
    
    str := concatenate(#filepath, "/bin/");
    print("path: %\n", str);
    compiler_add_library_search_directory(str);

    make_directory_if_it_does_not_exist("build");
    opts := get_build_options();
    opts.output_type = .NO_OUTPUT;
    set_build_options(opts);
    
    if build_exe {
        opts.output_type = .EXECUTABLE;
        opts.output_executable_name = "jaicc";
        opts.output_path = "bin/";
    }
        
    
    w := compiler_create_workspace("Jai C Compiler by Josh Huelsman");
    set_build_options(opts, w);

    compiler_begin_intercept(w);

    add_source(w, use_generated);

    if !build_exe {
        add_build_string("#run main();", w);
    }
        
    Project_Generator.build_args = tprint("-msvc_msg_format -no_color first.jai");
    Project_Generator.intercept_messages(w);

    return w;
}

add_source :: (w: Workspace, use_generated: bool) {
    add_build_file("src/main.jai", w);
    
    // @TODO set version string via svn revision or something
    add_build_string(sprint("JAICC_VERSION_STRING :: \"Jai C Compiler v1\";"), w); // I think this @Leaks ?

    if use_generated then add_build_string("USE_GENERATED_CLANG_BINDINGS :: true;", w);
    else add_build_string("USE_GENERATED_CLANG_BINDINGS :: false;", w);
}

compile_and_run :: () {
    build(use_generated=false, build_exe=false);
}

#run { build(); };
// #run compile_and_run();
