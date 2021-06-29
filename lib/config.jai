#import "Basic";
#import "Text_File_Handler";
#import "Reflection";


for_expansion :: (handler: *Text_File_Handler, body: Code, flags: For_Flags) #expand {
    #assert !(flags & .POINTER) && !(flags & .REVERSE);

    index := 0;
    while true {
        line, found := consume_next_line(handler);
        if !found break;

        `it := line;
        `it_index := index;

        #insert body;

        index += 1;
    }
}

save_config_file_to_builder :: (sb: *String_Builder, target: *$T, version := 1) {
    print_to_builder(sb, "[%]\n\n", version);
    for type_info(T).members {
        any: Any;
        any.value_pointer = target + it.offset_in_bytes;
        any.type = it.type;

        print_to_builder(sb, "% %\n", it.name, any);
    }
}

parse      :: parse_config_file;
to_builder :: save_config_file_to_builder;

//
// parse a config file and write values from it into the `target` struct
//
parse_config_file :: (target: $T, config_filename: string) {
    handler: Text_File_Handler;
    defer deinit(*handler);

    start_file(*handler, "config", config_filename, optional=false);
    if handler.failed {
        log("Could not find '%'", config_filename, flags=.ERROR);
        return;
    }

    target_tinfo := type_info(type_of(<< target));

    for line: *handler {
        key_name, rhs := break_by_spaces(line);
        if !rhs {
            error(handler, "Expected a space after the key\n");
            continue;
        }

        //member := get_struct_field_info(target_tinfo, key_name);
        member := get_field(target_tinfo, key_name);
        if member == null {
            log("invalid config field '%'", key_name, flags=.ERROR);
            continue;
        }

        any: Any;
        any.value_pointer = (cast(*u8)target) + member.offset_in_bytes;
        any.type = member.type;
        set_value_from_string(any, rhs);
    }
}
