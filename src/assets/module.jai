#module_parameters(STATE_IN_CONTEXT := false);

#if STATE_IN_CONTEXT {
    state :: inline () -> *State { return *context.state.assets_db; }
} else {
    _module_state: State;
    state :: inline () -> *State { return *_module_state; }
}

State :: struct {
    did_init := false;
    thread_group: Thread_Group;
}

Asset_Task :: struct {
    input_filename: string;
    output_filename: string;
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

init :: () { using state();
    if did_init return;
    did_init = true;

    File.make_directory_if_it_does_not_exist(".library");
    File.make_directory_if_it_does_not_exist(".library/content");

    test();

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
    thread_group.name = "Assets Thread Group";
    thread_group.logging = true;
    for * thread_group.worker_info
        it.thread.data = state();

    start(*thread_group);
    context.logger = old_logger;
}

tick :: () {
    using state();

    results := get_completed_work(*thread_group);
    for results {
        print("completed result: %\n", it);
    }
}
shutdown :: () {
    using state();
    shutdown(*thread_group);
}

reimport_all :: () {
    using state();
    assert(did_init);

    work := New(Asset_Task);
    work.input_filename = "assets/textures/pg/Ground/Ground037_1K_AmbientOcclusion.jpg";
    add_work(*thread_group, work, logging_name="test work item");
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


#scope_file

get_temporary_filename :: () -> string {
    #import "Windows";
    #import "Windows_Utf8";
    kernel32 :: #foreign_system_library "kernel32";
    GetTempPathW     :: (buffer_length_in_tchars: u32, buffer: *u16) -> u32 #foreign kernel32;
    GetTempFileNameW :: (path_name: *u16, prefix_string: *u16, unique: u32, temp_filename: *u16) -> u32 #foreign kernel32;

    path_name: [MAX_PATH + 1]u16;
    num_tchars := GetTempPathW(MAX_PATH + 1, path_name.data);
    assert(num_tchars > 0);

    temp_filename: [MAX_PATH + 1]u16;
    res := GetTempFileNameW(path_name.data, utf8_to_wide("shd"), 0, temp_filename.data);
    assert(res != 0);

    return wide_to_utf8(temp_filename.data);
}

Asset_Hash :: struct {
    hi: u64;
    lo: u64;
}

operator == :: (a: Asset_Hash, b: Asset_Hash) -> bool {
    return a.hi == b.hi && a.lo == b.lo;
}

tstring :: (asset_hash: Asset_Hash) -> string {
    return tprint("%1%2", hex16(asset_hash.hi), hex16(asset_hash.lo));
}

from_string :: (asset_hash_string: string) -> bool, Asset_Hash {
    Crt      :: #foreign_system_library "msvcrt";
    strtoull :: (src: *u8, end_part: **u8, base: s32) -> u64 #foreign Crt "_strtoui64";

    asset_hash: Asset_Hash;

    if asset_hash_string.count == 32 {
        hi_s := tprint("%\0", slice(asset_hash_string, 0, 16));
        lo_s := tprint("%\0", slice(asset_hash_string, 16, 16));

        hi_s.count -= 1;
        lo_s.count -= 1;

        asset_hash.hi = strtoull(hi_s.data, null, 16);
        asset_hash.lo = strtoull(lo_s.data, null, 16);

        return true, asset_hash;
    }

    return false, asset_hash;
}

test :: () {
    v := hash_string_contents("test");
    //print("test hashed to value: %\n", v);
    v_str := tstring(v);
    //print("test hashed to %\n", v_str);
    ok, v2 := from_string(v_str);
    //print("parsed % from %\n", v2, v_str);
    assert(ok);
    assert(v == v2);
}

path_for_content_hash :: (hash_val: Asset_Hash) -> string {

    hash_str := tstring(hash_val);
    assert(hash_str.count == 32);

    dir_part := tprint(".library/content/%", slice(hash_str, 0, 2));
    File.make_directory_if_it_does_not_exist(dir_part);

    return tprint("%/%", dir_part, hash_str);
}

asset_thread_group_proc :: (group: *Thread_Group, thread: *Thread, work: *void) -> Thread_Continue_Status {
    task := cast(*Asset_Task)work;
    print("thread %: has task %\n", thread, task.input_filename);

    temp_file := get_temporary_filename();
    ok := create_basis_file(task.input_filename, temp_file);
    // TODO check file_length > 0
    assert(ok, "error creating basis texture file for '%'", task.input_filename);
    hash_val := hash_file_contents(temp_file);
    print("got hash % (%) for file %\n", hash_val, tstring(hash_val), temp_file);

    content_path := path_for_content_hash(hash_val);
    File.file_delete(content_path);
    if !File.file_move(temp_file, content_path) {
        log_error("ERROR: could not move generated asset content into path: %", content_path);
        return .CONTINUE;
    }

    return .CONTINUE;
}

#import "Thread";
#import "Basic";

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

create_basis_file :: (input_filename: string, output_filename: string) -> bool {
    path_to_basisu := "lib/basis_universal/bin/basisu.exe";
    args: [..]string;
    args.allocator = __temporary_allocator;
    array_add(*args, path_to_basisu, input_filename, "-output_file", output_filename);
    launched, exit_code, stdout, stderr := os_run_command(..args, capture_and_return_output=true);
    if stdout
        print("output: %\n", stdout);
    if stderr
        print("stderr: %\n", stderr);

    return exit_code == 0;
}

hash_file_contents :: (filename: string) -> Asset_Hash {
    // TODO: mmap? stream?
    bytes, ok := File.read_entire_file(filename);
    assert(ok, "could not read file '%'", filename);
    return hash_string_contents(bytes);
}

hash_string_contents :: (bytes: string) -> Asset_Hash {
    hash_val:[2]u64 = xxhash.xxh3(bytes);

    asset_hash: Asset_Hash;
    asset_hash.hi = hash_val[0];
    asset_hash.lo = hash_val[1];
    return asset_hash;
}

hex16 :: #bake_arguments formatInt(base=16, minimum_digits=16);

File :: #import "File";
#import "File_Utilities";
#import "String";
#import "Hash";
#import "Process";
#import "System";
#import "Thread";

xxhash :: #import "xxhash_8";
wbml :: #import "wbml";
#import "guid";

