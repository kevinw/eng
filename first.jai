#scope_file

CHECK_PATH :: "check/";
PRINT_CONSTANTS :: false;

module_search_paths := string.["lib", "src", "c:/jai/Modules"];

build_plugin :: (build_flags: Build_Flags, game_dll_source_name: string, loc := #caller_location) {
    set_working_directory(#filepath);

    // Don't generate an executable for this build script.
    opts := stop_normal_build();

    if String.count(game_dll_source_name, ".") > 0 {
        compiler_report(tprint("Error: no dots in source name please: '%'", game_dll_source_name), loc, .ERROR);
        return;
    }

    w := compiler_create_workspace("build");
    //defer compiler_destroy_workspace(w);
    {
        compiler_begin_intercept(w);
        defer compiler_end_intercept(w);

        add_import_paths(*opts, module_search_paths);
        opts.output_type = .DYNAMIC_LIBRARY;

        if build_flags & .Check_Only
            opts.output_path = CHECK_PATH;

        if build_flags & .Reload {
            output_exe := tprint("%_reloaded_%", game_dll_source_name, Random.random_get());
            //print("reloading...changing DLL output to %\n", output_exe);
            opts.output_executable_name = output_exe;
        } else {
            opts.output_executable_name = game_dll_source_name;
        }

        set_optimization(*opts, build_flags);
        set_build_options(opts, w);

        define_constants(w, build_flags, is_host = false, print_constants_to_stdout = PRINT_CONSTANTS);
        add_build_file(tprint("src/%.jai", game_dll_source_name), w);

        run_compiler_loop(w, true);
    }
};

add_import_paths :: (opts: *Build_Options, paths: []string) {
    new_paths: [..]string;
    array_add(*new_paths, ..paths);
    array_add(*new_paths, ..opts.import_path);
    //print("import_path: ");
    //for paths print("% ", it);
    //print("\n");
    opts.import_path = paths;
}

build_host :: (build_flags: Build_Flags) {
    set_working_directory(#filepath);

    opts := stop_normal_build();

    w := compiler_create_workspace("build_host");
    {
        compiler_scoped_intercept(w);

        add_import_paths(*opts, module_search_paths);
        opts.output_type = .EXECUTABLE;
        opts.output_executable_name = tprint("game%.exe", ifx build_flags & .Release then "" else "_dev");
        if build_flags & .Check_Only {
            opts.output_path = CHECK_PATH;
        }
        set_optimization(*opts, build_flags);
        set_build_options(opts, w);
        define_constants(w, build_flags, is_host = true, print_constants_to_stdout = PRINT_CONSTANTS);
        if build_flags & .Release {
            add_build_file("src/d3d_game.jai", w);
        }
        add_build_file("src/host.jai", w);

        if build_flags & .Release != 0 {
            run_compiler_loop(w, true); // when building one exe instead of the host and the dll, we need to do the ECS metaprogramming on the "host"
        } else {
            run_compiler_loop(w, false);
        }
    }
};

build_tests :: (build_flags: Build_Flags) {
    opts := stop_normal_build();
    w := compiler_create_workspace("test-build");
    {
        compiler_scoped_intercept(w);
        add_import_paths(*opts, module_search_paths);
        opts.output_type = .EXECUTABLE;
        set_build_options(opts, w);
        define_constants(w, build_flags, is_host = false, print_constants_to_stdout = PRINT_CONSTANTS);
        add_build_file("tests/test_transform_link.jai", w);
        run_compiler_loop(w, do_ecs_metaprogram=true);
    }

    exit(1);
}

set_optimization :: (build_opts: *Build_Options, build_flags: Build_Flags) {
    if build_flags & .Release {
        print("RELEASE MODE\n");
        build_opts.backend = .LLVM;
        set_optimization_level(build_opts, opt_level=3, size_level=1);
    } else {
        build_opts.backend = .LLVM;
        //build_opts.backend = .X64;
        set_optimization_level(build_opts, opt_level=0, size_level=0);
    }
}

build :: () {
    args := compiler_get_command_line_arguments();
    flags := Build_Flags.None;

    //print("args:\n");
    //for args print("%: %\n", it_index, it);

    game_name := DEFAULT_SRC_PLUGIN;

    consume_arg :: (args: *[]string, s: *string = null) #expand {
        assert(args.count > 0);
        if s != null {
            <<s = (<<args)[0];
        }
        args.data = args.data + 1;
        args.count -= 1;
    }

    maybe_consume_arg :: (args: *[]string, name: string) -> bool {
        if args.count > 0 && (<<args)[0] == name {
            consume_arg(args);
            return true;
        }

        return false;
    }

    if maybe_consume_arg(*args, "test") {
        build_tests(flags);
        return;
    }

    if maybe_consume_arg(*args, "--release")
        flags |= .Release;

    if maybe_consume_arg(*args, "--game") {
        if args.count == 0 {
            print("error: must specify a game name after '--game' option\n");
            exit(1);
        }

        consume_arg(*args, *game_name);
    }

    if maybe_consume_arg(*args, "reload")
        flags |= .Reload;

    if args.count == 0 {
        build_plugin(flags, game_name);
        return;
    }

    if args[0] == {
        case "all";
            build_host(flags);
            if flags & .Release == 0
                build_plugin(flags, game_name);
        case "host";
            build_host(flags);
        case "check";
            flags |= .Check_Only;
            build_host(flags);
            build_plugin(flags, game_name);
        case;
            // we're specifying the game_name at the command line (like when we're reloading)
            game_name = args[0];
            build_plugin(flags, game_name);
    }
}

#run build();

#load "src/metaprogram_common.jai";

#import "Basic";
#import "Compiler";
Random :: #import "Random";
String :: #import "String";
