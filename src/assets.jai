State :: struct {
    did_init := false;
    thread_group: Thread_Group;
}

Asset_Task :: struct {
    input_filename: string;
    output_filename: string;
}

init :: () { using state();
    if did_init return;
    did_init = true;

    num_cpus := get_number_of_processors();
    assert(num_cpus >= 1);
    if num_cpus > 200  num_cpus = 200;  // Clamp to a value that is reasonable as of 2021, in case we get weird data.
    #if (OS == .WINDOWS) || (OS == .LINUX) {
        // This routine reports hyperthreads, so, divide by two, because of Intel marketing.
        num_cpus /= 2;
    }
    num_threads := max(num_cpus - 1, 1);
    my_logger :: (message: string, data: *void, info: Log_Info) {
        print("[thread_group] %", message);
    }
    old_logger := context.logger;
    context.logger = my_logger;
    log("This machine reports % CPUs; starting % threads.\n", num_cpus, num_threads);

    init(*thread_group, num_threads, asset_thread_group_proc);
    context.logger = old_logger;
    thread_group.name = "Assets Thread Group";
    thread_group.logging = true;
    for * thread_group.worker_info
        it.thread.data = state();

    start(*thread_group);
}

shutdown :: () {
    using state();
    shutdown(*thread_group);
}

reimport_all :: () { using state();
    assert(did_init);

    work := New(Asset_Task);
    work.input_filename = "assets/textures/pg/Ground/Ground037_1K_AmbientOcclusion.jpg";
    add_work(*thread_group, work, logging_name="test work item");
}

#scope_file

asset_thread_group_proc :: (group: *Thread_Group, thread: *Thread, work: *void) -> Thread_Continue_Status {
    task := cast(*Asset_Task)work;
    print("thread %: has task %\n", thread, task.input_filename);

    return .CONTINUE;
}

state :: inline () -> *State { return *context.state.assets_db; }

#import "Thread";
#import "Basic";

#scope_module

longest_common_prefix :: (strings: []string) -> string {
    max_count := 0;
    idx := -1;

    for strings {
        if it.count > max_count {
            max_count = it.count;
            idx = it_index;
        }
    }

    if idx == -1 return "neg one";

    max_s := strings[idx];
    end := false;
    for i: 0..max_count - 1 {
        for strings {
            if it_index == idx
                continue;
            if i >= it.count || max_s[i] != it[i] {
                end = true;
                break;
            }
        }

        if end {
            return slice(max_s, 0, i);
        }
    }

    return "";
}

Texture_Type :: enum_flags {
    Ambient_Occlusion;
    Color;
    Displacement;
    Normal;
    Flags;
    Roughness;
}

Material_Texture :: struct {
    type: Texture_Type;
    filename: string;
}

Material_Asset :: struct {
    name: string;
    textures: [..]Material_Texture;
}

classify :: (detail: string, full_path: string) -> Texture_Type {
    type: Texture_Type;

    Push_Temporary();
    lower_detail := copy_string(detail);
    to_lower(lower_detail);

    S :: struct { str: string; texture_type: Texture_Type; }
    entries := S.[
        .{"normal", .Normal},
        .{"color", .Color},
        .{"roughness", .Roughness},
        .{"displacement", .Displacement},
        .{"ambientocclusion", .Ambient_Occlusion},
    ];

    for entries if contains(lower_detail, it.str)
        type |= it.texture_type;

    if type == 0
        print("warning: could not infer a texture type for '%'\n", detail);

    return type;
}

auto_materials :: () -> []Material_Asset {
    Visit_Ctx :: struct {
        materials: [..]Material_Asset;
    }

    dir_visitor :: (info: *File_Visit_Info, ctx: *Visit_Ctx) {
        visit_files(info.full_name, recursive=false, ctx, dir_visitor, visit_directories=true, visit_files=false);

        lcp: string;
        proposed_name: string;

        filenames: [..]string;  filenames.allocator = __temporary_allocator;
        full_paths: [..]string; full_paths.allocator = __temporary_allocator;

        for file_list(info.full_name) {
            //print("%: %\n", it_index, it);
            path := parse_path(it);
            if path.words.count == 0 continue;

            array_add(*filenames, path.words[path.words.count - 1]);
            array_add(*full_paths, it);
        }

        lcp = longest_common_prefix(filenames);
        if lcp.count == 0
            return;

        proposed_name = lcp;
        while ends_with(proposed_name, "_")
            proposed_name = slice(proposed_name, 0, proposed_name.count - 1);

        material := array_add(*ctx.materials);
        material.name = copy_string(proposed_name);

        for filenames {
            detail_part := slice(it, lcp.count, 99999);
            tex_type := classify(detail_part, it);
            //print("%: %\n", detail_part, tex_type);
            if tex_type != 0 {
                tex := array_add(*material.textures);
                tex.type = tex_type;
                tex.filename = copy_string(full_paths[it_index]);
            }
        }
    }

    visit_ctx: Visit_Ctx;
    visit_files(".\\assets\\textures\\pg", recursive=false, *visit_ctx, dir_visitor, visit_directories=true, visit_files=false);

    return visit_ctx.materials;
}

check_meta_files :: (path: string) {
    visit_func :: (info: *File_Visit_Info, ctx: *Visit_Ctx) {
        if info.is_directory return;
        if ends_with(info.full_name, ".meta") {
            return;
        }
        meta_path := tprint("%.meta", info.full_name);
        if !file_exists(meta_path) {
            print("neesds meta file: %\n", info.full_name);

            {
                Asset_Desc :: struct {
                    version: int;
                    guid: string;
                }

                asset_desc: Asset_Desc;
                asset_desc.guid = gen_guid();
                asset_desc.version = 1;

                s := wbml.serialize(*asset_desc);
                File.write_entire_file(meta_path, s);
            }
        }
    }

    Visit_Ctx :: struct {
    }
    ctx: Visit_Ctx;

    visit_files(path, recursive=true, user_data=*ctx, proc=visit_func, visit_directories=true);
}

create_basis_file :: (input_filename: string, output_filename: string) {
    path_to_basisu := "lib/basis_universal/bin/basisu.exe";
    launched, exit_code, stdout, stderr := os_run_command(path_to_basisu, capture_and_return_output=true);
    if stdout
        print("output: %\n", stdout);
    if stderr
        print("stderr: %\n", stderr);

}


tick :: () {
    results := get_completed_work(*thread_group);
    for results {
    }
}


#scope_file

main :: () {
    {
        using context.print_style.default_format_struct;
        use_long_form_if_more_than_this_many_members = -1;
        draw_type_name = true;
        use_newlines_if_long_form = true;
    }

    check_meta_files(".\\assets\\");

    materials := auto_materials();

    for materials {
        print("material % ------------\n", it_index);
        print("%\n", it);
    }

    print("guids:\n%\n%\n%\n", gen_guid(), gen_guid(), gen_guid());
}


#import "guid";

#import "File_Utilities";
File :: #import "File";
#import "String";
wbml :: #import "wbml";
#import "System";
#import "Thread";
