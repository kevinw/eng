#scope_file

#import "Thread";
#import "Basic";


Asset_Pipeline :: struct {
}

asset_thread_proc :: (thread: *Thread) -> s64 {
    //print("in asset thread!\n");
    count := 0;
    while true {
        Windows :: #import "Windows"; // for Sleep
        Windows.Sleep(1000);
        print("asset tick %\n", count);
        count += 1;
        tick_single_threaded();
    }
    return 0;
}

#scope_module

asset_thread: *Thread;

tick_single_threaded :: () {
    // TODO: debug the asset pipeline with a cooperative-multitasking
    // mode that runs every tick on the main thread.
}

start_thread :: () {
    asset_thread = New(Thread);
    thread_init(asset_thread, asset_thread_proc);
    thread_start(asset_thread);
}

stop_thread :: () {

}

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
    visit_files(".\\resources\\textures\\pg", recursive=false, *visit_ctx, dir_visitor, visit_directories=true, visit_files=false);

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

main :: () {
    {
        using context.print_style.default_format_struct;
        use_long_form_if_more_than_this_many_members = -1;
        draw_type_name = true;
        use_newlines_if_long_form = true;
    }

    check_meta_files(".\\resources\\");

    materials := auto_materials();

    for materials {
        print("material % ------------\n", it_index);
        print("%\n", it);
    }

    print("guids:\n%\n%\n%\n", gen_guid(), gen_guid(), gen_guid());
}

#scope_file
#import "guid";

#import "File_Utilities";
File :: #import "File";
#import "String";
wbml :: #import "wbml";
